import Foundation
import ProxyWorldUtility
import KwiftExtension
import ProxySubscription
import ProxyUtility
import ClashSupport
import ProxyRule
import Yams
import ArgumentParser
import QuantumultSupport
import Precondition
import SystemPackage
import SystemUp
import SystemFileManager
import Command

private func _readConfig(configPath: FilePath) throws -> ProxyWorldConfiguration {
  let fd = try FileDescriptor.open(configPath, .readOnly)
  return try fd.closeAfter {
    try JSONDecoder().kwiftDecode(from: SystemFileManager.contents(ofFileDescriptor: fd) as Data, as: ProxyWorldConfiguration.self)
  }
}

struct DaemonState {
  private var runningClash: [UUID: Command.ChildProcess] = .init()
  internal private(set) var generetedClash: [UUID: ClashConfig] = .init()
  internal private(set) var instanceIDs: Set<UUID> = .init()

  init() {
  }

  mutating func add(instancdID: UUID, pid: Command.ChildProcess, config: ClashConfig) {
    runningClash[instancdID] = pid
    generetedClash[instancdID] = config
    precondition(instanceIDs.insert(instancdID).inserted)
  }

  mutating func remove(instancdID: UUID) -> Command.ChildProcess {
    let pid = runningClash.removeValue(forKey: instancdID)!
    generetedClash[instancdID] = nil
    precondition(instanceIDs.remove(instancdID) != nil)
    return pid
  }
}

struct ClashProcessInfo {
  let pid: Int32
}

actor Manager {

  nonisolated
  public let workDir: FilePath
  private let configPath: FilePath

  private var config: ProxyWorldConfiguration

  nonisolated
  private let networkOptions: NetworkOptions
  public var options: ProxyWorldConfiguration.GenerateOptions

  public struct NetworkOptions {
    public let retryLimit: UInt
    // try direct connection if proxy env detected
    public let tryDirectConnect: Bool
  }
  // MARK: Caches
  private let sessions: [URLSession]

  private var proxyCache = [String: [ProxyConfig]]()
  private var ruleCache = [String: RuleProvider]()

  // MARK: Runtime Properties Cache
  private let geoDBPath: FilePath
  nonisolated
  public let configEncoder: YAMLEncoder

  public init(workDir: FilePath, configPath: FilePath, networkOptions: NetworkOptions, options: ProxyWorldConfiguration.GenerateOptions) throws {
    self.workDir = workDir
    self.configPath = configPath
    self.networkOptions = networkOptions
    self.options = options
    self.geoDBPath = try defaultGeoDBPath()
    configEncoder = YAMLEncoder()
    configEncoder.options.allowUnicode = true
    configEncoder.options.sortKeys = true
    // TODO: detect proxy env
    let session = URLSession(configuration: .ephemeral)
    let directSession: URLSession? = nil
    sessions = [session, directSession].compactMap { $0 }
    config = try _readConfig(configPath: configPath)
  }

  deinit {
    sessions.forEach {$0.invalidateAndCancel() }
  }

  struct ReloadResult {
    let configChanged: Bool
    let sharedChanged: Bool
  }

  /// Reload config
  /// - Returns: true if config changed
  public func reloadConfig() throws -> ReloadResult {
    print(#function)
    let newConfig = try _readConfig(configPath: configPath)
    let configChanged = newConfig != config
    var sharedChanged = false

    if configChanged {
      sharedChanged = config.shared != newConfig.shared
      config = newConfig
    }

    return .init(configChanged: configChanged, sharedChanged: sharedChanged)
  }

  private func load(url: URL) async throws -> Data {
    var error: Error!
    for _ in 0...networkOptions.retryLimit {
      for session in sessions {
        do {
          return try await session.data(for: URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 20)).0
        } catch let e {
          error = e
        }
      }
    }
    throw error
  }

  // MARK: Daemon

  private var daemonStates: DaemonState = .init()

  public func cleanUnmanagedProcesses() throws {

  }

  private func genInstanceWorkDir(instance: UUID) -> FilePath {
    workDir.appending("instances").appending(instance.uuidString)
  }

  public func daemonRun(enableUpdating: Bool) async throws {
    if enableUpdating {
      _ = try await updateCaches()
    }
    var newInstancesConfigMap: [UUID: (ProxyWorldConfiguration.InstanceConfig, ClashConfig)] = .init()
    for config in generateClashConfigs(baseConfig: .init(mode: .rule)) {
      newInstancesConfigMap[config.0.id] = config
    }

    // generate clash configs for each instance
    let oldInstances = daemonStates.instanceIDs
    let newInstances = Set(newInstancesConfigMap.keys)

    let removedInstances = oldInstances.subtracting(newInstances)
    let stayedInstances = oldInstances.intersection(newInstances)
    let addedInstances = newInstances.subtracting(oldInstances)

    print("removed", removedInstances)
    print("stayed", stayedInstances)
    print("added", addedInstances)

    func prepareClash(instance: UUID, firstTime: Bool) throws {
      let instancdDir = genInstanceWorkDir(instance: instance)
      try SystemFileManager.createDirectoryIntermediately(.absolute(instancdDir))
      if firstTime {
        let fakeDBPath = instancdDir.appending("Country.mmdb")
        if !SystemFileManager.fileExists(atPath: .absolute(fakeDBPath)) {
          try FileSyscalls.createSymbolicLink(.absolute(fakeDBPath), toDestination: geoDBPath).get()
        }
      }
      let configPath = instancdDir.appending("config.yaml").string
      let config = newInstancesConfigMap[instance]!.1
      let encoded = try configEncoder.encode(config)
      try encoded.write(toFile: configPath, atomically: true, encoding: .utf8)

      let exe = Clash(configurationDirectory: instancdDir.string, configurationFile: configPath)
      var command = Command(executable: "clash", arg0: nil, arguments: exe.arguments)
      command.stdin = .null
      command.stdout = .inherit
      command.stderr = .inherit

      print("Launching \(newInstancesConfigMap[instance]!.0.name)")
      let process = try command.spawn()

      let pidFilePath = instancdDir.appending("pid.txt").string
      daemonStates.add(instancdID: instance, pid: process, config: config)
    }

    for instanceID in removedInstances {
      var pid = daemonStates.remove(instancdID: instanceID)
      // kill pid, remove files
      print("kill \(pid):", pid.pid.send(signal: SIGKILL))
      print("wait result: ", try pid.wait())
      try? SystemFileManager.remove(genInstanceWorkDir(instance: instanceID)).get()
    }

    for instanceID in addedInstances {
      try prepareClash(instance: instanceID, firstTime: true)
    }

    for instanceID in stayedInstances {
      let oldConfig = daemonStates.generetedClash[instanceID]!
      let newConfig = newInstancesConfigMap[instanceID]!.1
      if oldConfig != newConfig {
        let useReload = (oldConfig.httpPort == newConfig.httpPort)
        && (oldConfig.socksPort == newConfig.socksPort)
        && (oldConfig.mixedPort == newConfig.mixedPort)
        && (oldConfig.externalController == newConfig.externalController)
        // TODO: add more checks like interface

        // reload or restart process
        print("Unimplemented changed: \(newInstancesConfigMap[instanceID]!.0.name)")
//        try prepareClash(instance: instanceID, firstTime: false)
      }
    }
  }

  /// update subscription and rule caches
  /// - Returns: true if caches updated
  public func updateCaches() async throws -> Bool {
    print(#function)
    let oldCaches = (proxyCache, ruleCache)
    for subscription in config.shared.subscriptions {
      do {
        print("Start to update subscription \(subscription.name)")
        let responseData = try await load(url: subscription.url)

        let content = SubscriptionContent(subscription.type.decode(responseData))
        print("Success!")
        if content.metadata.hasUsefulInfo {
          print("Information: \(content.metadata)")
        }
        print("Totally \(content.configs.count) nodes.")
        proxyCache[subscription.id.uuidString] = content.configs
//        if verbose {
//          content.configs.forEach { config in
//            print(config)
//          }
//        }
      } catch {
        print("Error while updating subscription \(subscription.name), \(error)")
      }
    }

    for ruleSubscription in config.shared.ruleSubscriptions {
      do {
        print("Start to update rule subscription \(ruleSubscription.name)")
        let subscriptionData: Data
        if ruleSubscription.isLocalFile {
          let fileFD = try FileDescriptor.open(FilePath(ruleSubscription.url), .readOnly)
          subscriptionData = try fileFD.closeAfter {
            try SystemFileManager.contents(ofFileDescriptor: fileFD)
          }
        } else {
          subscriptionData = try await load(url: URL(string: ruleSubscription.url)!)
        }
        let decoded = try YAMLDecoder().decode(from: String(decoding: subscriptionData, as: UTF8.self)) as RuleProvider
        print("Success!")
        ruleCache[ruleSubscription.id.uuidString] = decoded
      } catch {
        print("Error while updating subscription \(ruleSubscription.name), \(error)")
      }
    }

    return oldCaches != (proxyCache, ruleCache)
  }

  public func generateClashConfigs(baseConfig: ClashConfig) -> [(ProxyWorldConfiguration.InstanceConfig, ClashConfig)] {
    config.generateClashConfigs(baseConfig: baseConfig, ruleSubscriptionCache: ruleCache, proxySubscriptionCache: proxyCache, options: options)
  }
}

func defaultWorkDir() throws -> FilePath {
  try FilePath(PosixEnvironment.get(key: "HOME").unwrap("no HOME env")).appending(".config/proxy-world")
}

func defaultClashConfigDir() throws -> FilePath {
  try FilePath(PosixEnvironment.get(key: "HOME").unwrap("no HOME env")).appending(".config/clash")
}

func defaultGeoDBPath() throws -> FilePath {
  try defaultClashConfigDir().appending("Country.mmdb")
}

struct Daemon: AsyncParsableCommand {

  @Option(help: "Reload config by interval if provided")
  var reloadInterval: Int?

  @Option(help: "Refresh interval for subscription/rule")
  var refreshInterval: Int = 600

  @OptionGroup(title: "NAME GENERATION")
  var options: GroupNameGenerateOptions

  @OptionGroup(title: "NETWORK")
  var networkOptions: NetworkOptions

  @Argument
  var configPath: FilePath

  func run() async throws {
    // TODO: user custom work dir
    let workDir = try defaultWorkDir()

    try SystemFileManager.createDirectoryIntermediately(.absolute(workDir))

    let lockFilePath = workDir.appending(".lock")
    let lockFile = try FileDescriptor.open(lockFilePath, .readOnly, options: [.create, .truncate], permissions: .fileDefault)
    defer {
      try? lockFile.close()
    }

    do {
      try FileSyscalls.lock(lockFile, flags: [.exclusive, .noBlock]).get()
    } catch {
      print("another daemon already running!")
      throw ExitCode(1)
    }
    defer { _ = FileSyscalls.unlock(lockFile) }

    let manager = try Manager(workDir: workDir, configPath: configPath, networkOptions: networkOptions.toInternal, options: options.toInternal())

    try await manager.cleanUnmanagedProcesses()

    if let reloadInterval {
      Task {
        let reloadInterval = Duration.seconds(reloadInterval)
        while true {
          try await Task.sleep(for: reloadInterval)
          do {
            let reloadResult = try await manager.reloadConfig()
            if reloadResult.configChanged {
              print("run daemon because of updated")
              try? await manager.daemonRun(enableUpdating: reloadResult.sharedChanged)
            }
          } catch {
            // cannot reload config
            print("error while reloading config: \(error)")
          }
        }
      }
    } else {
      print("reload disabled")
    }

    let refreshInterval: Duration = .seconds(refreshInterval)
    while true {
      try? await manager.daemonRun(enableUpdating: true)
      try await Task.sleep(for: refreshInterval)
    }
  }
}
