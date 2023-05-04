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
import Proc

extension SystemFileManager {
  static func contents(ofFile path: FilePath) throws -> Data {
    let fd = try FileDescriptor.open(path, .readOnly)
    return try fd.closeAfter {
      try SystemFileManager.contents(ofFileDescriptor: fd)
    }
  }

  static func contents(ofFile path: FilePath) throws -> String {
    let fd = try FileDescriptor.open(path, .readOnly)
    return try fd.closeAfter {
      try SystemFileManager.contents(ofFileDescriptor: fd)
    }
  }
}

private func _readConfig(configPath: FilePath) throws -> ProxyWorldConfiguration {
  try JSONDecoder().kwiftDecode(from: SystemFileManager.contents(ofFile: configPath) as Data, as: ProxyWorldConfiguration.self)
}

private func _genInstanceWorkDir(workDir: FilePath, instance: UUID) -> FilePath {
  workDir.appending("instances").appending(instance.uuidString)
}

struct DaemonStats {
  private var runningClash: [UUID: WaitPID.PID]
  internal private(set) var generetedClash: [UUID: ClashConfig]
  internal private(set) var instanceIDs: Set<UUID>

  init() {
    runningClash = .init()
    generetedClash = .init()
    instanceIDs = .init()
  }

  init(instanceRootPath: FilePath, dataPath: FilePath, decoder: JSONDecoder) throws {
    runningClash = try decoder.decode([UUID: WaitPID.PID.RawValue].self, from: SystemFileManager.contents(ofFile: dataPath))
      .mapValues { WaitPID.PID(rawValue: $0) }
    instanceIDs = .init(runningClash.keys)
    generetedClash = .init()
    let configDecoder = YAMLDecoder()
    for instanceID in instanceIDs {
      let configPath = instanceRootPath.appending(instanceID.uuidString).appending("config.yaml")
      do {
        let clashConfig = try configDecoder.decode(ClashConfig.self, from: SystemFileManager.contents(ofFile: configPath))
        generetedClash[instanceID] = clashConfig
      } catch {
        print("Cannot read clash config at \(configPath), skipped")
        fatalError()
      }
    }
  }

  mutating func add(instancdID: UUID, pid: WaitPID.PID, config: ClashConfig) {
    runningClash[instancdID] = pid
    generetedClash[instancdID] = config
    precondition(instanceIDs.insert(instancdID).inserted)
  }

  mutating func remove(instancdID: UUID) -> WaitPID.PID {
    let pid = runningClash.removeValue(forKey: instancdID)!
    generetedClash[instancdID] = nil
    precondition(instanceIDs.remove(instancdID) != nil)
    return pid
  }

  func encode(encoder: JSONEncoder) throws -> Data {
    try encoder.encode(runningClash.mapValues(\.rawValue))
  }

  func checkProcessRunning(id: UUID) -> Bool {
    guard let pid = runningClash[id] else {
      return false
    }
    do {
      #if os(macOS)
      let path = try PIDInfo.path(pid: pid.rawValue)
      // TODO: better detection
      return path.lastComponent?.string == "clash"
      #else
      #error("unimplemented")
      #endif
    } catch {

      return false
    }
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

  private var proxySubscriptionCache: [String : [ProxyConfig]]
  private var ruleSubscriptionCache: [String: RuleProvider]

  // MARK: Runtime Properties Cache
  /// ~/.config/clash/Country.mmdb
  nonisolated private let geoDBPath: FilePath
  nonisolated private let ruleSubCachePath: FilePath
  nonisolated private let proxySubCachePath: FilePath
  nonisolated private let statsPath: FilePath
  nonisolated public let configEncoder: YAMLEncoder

  /// encoder for cache/stats
  nonisolated private let cacheEncoder: JSONEncoder

  public init(workDir: FilePath, configPath: FilePath, loadDaemonStats: Bool, networkOptions: NetworkOptions, options: ProxyWorldConfiguration.GenerateOptions) throws {
    self.workDir = workDir
    self.configPath = configPath
    self.networkOptions = networkOptions
    self.options = options
    self.geoDBPath = try defaultGeoDBPath()
    self.cacheEncoder = .init()
    self.ruleSubCachePath = workDir.appending("cache_rule")
    self.proxySubCachePath = workDir.appending("cache_proxy")
    configEncoder = YAMLEncoder()
    configEncoder.options.allowUnicode = true
    configEncoder.options.sortKeys = true
    // TODO: detect proxy env
    let session = URLSession(configuration: .ephemeral)
    var directSession: URLSession?
    if networkOptions.tryDirectConnect {
      let config = URLSessionConfiguration.ephemeral
      config.connectionProxyDictionary = .init()
      directSession = .init(configuration: config)
    }
    sessions = [session, directSession].compactMap { $0 }
    config = try _readConfig(configPath: configPath)

    let decoder = JSONDecoder()
    let statsPath = workDir.appending("stats.json")
    if loadDaemonStats, SystemFileManager.fileExists(atPath: .absolute(statsPath)) {
      let instanceRootDir = workDir.appending("instances")
      print("load daemon stats")
      daemonStats = try .init(instanceRootPath: instanceRootDir, dataPath: statsPath, decoder: decoder)
    } else {
      daemonStats = .init()
    }
    do {
      ruleSubscriptionCache = try decoder.kwiftDecode(from: SystemFileManager.contents(ofFile: ruleSubCachePath))
      print("rule sub cache loaded")
    } catch {
      ruleSubscriptionCache = .init()
    }
    do {
      proxySubscriptionCache = try decoder.kwiftDecode(from: SystemFileManager.contents(ofFile: proxySubCachePath))
      print("proxy sub cache loaded")
    } catch {
      proxySubscriptionCache = .init()
    }
    self.statsPath = statsPath
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

  private func saveStats() throws {
    try daemonStats.encode(encoder: cacheEncoder)
      .write(to: URL(filePath: statsPath.string), options: .atomic)
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

  private var daemonStats: DaemonStats = .init()

  public func cleanUnmanagedProcesses() throws {
    for id in daemonStats.instanceIDs {
      if !daemonStats.checkProcessRunning(id: id) {
        print("\(id) not running!")
        _ = daemonStats.remove(instancdID: id)
      }
    }
    try saveStats()
  }

  private func genInstanceWorkDir(instance: UUID) -> FilePath {
    _genInstanceWorkDir(workDir: workDir, instance: instance)
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
    let oldInstances = daemonStats.instanceIDs
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
      daemonStats.add(instancdID: instance, pid: process.pid, config: config)
    }

    for instanceID in removedInstances {
      var pid = daemonStats.remove(instancdID: instanceID)
      // kill pid, remove files
      print("kill \(pid):", pid.send(signal: SIGKILL))
      print("wait result: ", WaitPID.wait(pid: pid))
      try? SystemFileManager.remove(genInstanceWorkDir(instance: instanceID)).get()
    }

    for instanceID in addedInstances {
      try prepareClash(instance: instanceID, firstTime: true)
    }

    for instanceID in stayedInstances {
      let oldConfig = daemonStats.generetedClash[instanceID]!
      let newConfig = newInstancesConfigMap[instanceID]!.1
      if oldConfig != newConfig {
//        print(try! configEncoder.encode(oldConfig))
//        print("======")
//        print(try! configEncoder.encode(newConfig))
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

    try saveStats()
  }

  /// update subscription and rule caches
  /// - Returns: true if caches updated
  public func updateCaches() async throws -> Bool {
    print(#function)
    let oldCaches = (proxySubscriptionCache, ruleSubscriptionCache)
    for subscription in config.shared.subscriptions {
      do {
        print("Start to update subscription \(subscription.name)")
        let responseData = try await load(url: subscription.url)

        let content = SubscriptionContent(subscription.type.decode(responseData))
        print("Success Parsed!")
        if content.configs.isEmpty {
          print("But no nodes, ignored!")
        } else {
          if content.metadata.hasUsefulInfo {
            print("Information: \(content.metadata)")
          }
          print("Totally \(content.configs.count) nodes.")
          proxySubscriptionCache[subscription.id.uuidString] = content.configs
        }
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
        ruleSubscriptionCache[ruleSubscription.id.uuidString] = decoded
      } catch {
        print("Error while updating subscription \(ruleSubscription.name), \(error)")
      }
    }

    var cacheUpdated: Bool = false

    if oldCaches.0 != proxySubscriptionCache {
      cacheUpdated = true
      try cacheEncoder.encode(proxySubscriptionCache)
        .write(to: URL(filePath: proxySubCachePath.string), options: .atomic)
    }
    if oldCaches.1 != ruleSubscriptionCache {
      cacheUpdated = true
      try cacheEncoder.encode(ruleSubscriptionCache)
        .write(to: URL(filePath: ruleSubCachePath.string), options: .atomic)
    }

    return cacheUpdated
  }

  public func generateClashConfigs(baseConfig: ClashConfig) -> [(ProxyWorldConfiguration.InstanceConfig, ClashConfig)] {
    config.generateClashConfigs(baseConfig: baseConfig, ruleSubscriptionCache: ruleSubscriptionCache, proxySubscriptionCache: proxySubscriptionCache, options: options)
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

  @Option(help: "Custom work dir")
  var workDir: FilePath?

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
    let workDir = try workDir ?? defaultWorkDir()

    try SystemFileManager.createDirectoryIntermediately(.absolute(workDir))

    let lockFilePath = workDir.appending(".lock")
    let lockFile = try FileDescriptor.open(lockFilePath, .readOnly, options: [.create, .truncate], permissions: .fileDefault)
    defer {
      try? lockFile.close()
    }

    do {
      try FileSyscalls.lock(lockFile, flags: [.exclusive, .noBlock]).get()
    } catch {
      print("another daemon for this work directory (\(workDir) is already running!")
      throw ExitCode(1)
    }
    defer { _ = FileSyscalls.unlock(lockFile) }

    let manager = try Manager(workDir: workDir, configPath: configPath, loadDaemonStats: true, networkOptions: networkOptions.toInternal, options: options.toInternal())

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
