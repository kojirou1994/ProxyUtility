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
import AsyncHTTPClient
import ProxyInfo
import AsyncHTTPClientProxy
import NIO
import NIOFoundationCompat

private func _readConfig(configPath: FilePath) throws -> ProxyWorldConfiguration {
  try JSONDecoder().kwiftDecode(from: SystemFileManager.contents(ofFile: configPath) as Data, as: ProxyWorldConfiguration.self)
}

private func _genInstanceWorkDir(workDir: FilePath, instance: UUID) -> FilePath {
  workDir.appending("instances").appending(instance.uuidString)
}

struct DaemonStats {
  private var runningClash: [UUID: ProcessID]
  internal private(set) var generetedClash: [UUID: ClashConfig]
  internal private(set) var instanceIDs: Set<UUID>

  init() {
    runningClash = .init()
    generetedClash = .init()
    instanceIDs = .init()
  }

  init(instanceRootPath: FilePath, dataPath: FilePath, decoder: JSONDecoder) throws {
    runningClash = try decoder.decode([UUID: ProcessID.RawValue].self, from: SystemFileManager.contents(ofFile: dataPath) as Data)
      .mapValues { ProcessID(rawValue: $0) }
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

  mutating func add(instancdID: UUID, pid: ProcessID, config: ClashConfig) {
    runningClash[instancdID] = pid
    generetedClash[instancdID] = config
    precondition(instanceIDs.insert(instancdID).inserted)
  }

  mutating func remove(instancdID: UUID) -> ProcessID {
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
      // TODO: better detection
      let path: FilePath
      #if os(macOS)
      path = try Proc.path(pid: pid)
      #elseif os(Linux)
      let full = try Data(contentsOf: URL(fileURLWithPath: "/proc/\(pid)/cmdline"))
      if full.isEmpty {
        return false
      }
      path = FilePath(String(decoding: full.split(separator: 0, maxSplits: 1)[0], as: UTF8.self))
      #else
      #error("unimplemented")
      #endif
      return path.lastComponent?.string == "clash"
    } catch {
      return false
    }
  }
}

struct ClashProcessInfo {
  let pid: Int32
}

actor Manager {

  public let workDir: FilePath
  private let clashPath: String?
  private let configPath: FilePath

  private var config: ProxyWorldConfiguration

  nonisolated
  private let networkOptions: NetworkOptions
  public var options: ProxyWorldConfiguration.GenerateOptions

  internal struct HTTPClients: ~Copyable {
    internal init(proxy: HTTPClient?, direct: HTTPClient) {
      self.proxy = proxy
      self.direct = direct
      clients = [proxy, direct].compactMap { $0 }
    }

    private let proxy: HTTPClient?
    private let direct: HTTPClient

    internal let clients: [HTTPClient]

    deinit {
      try? direct.syncShutdown()
      try? proxy?.syncShutdown()
    }
  }

  public struct NetworkOptions {
    public init(retryLimit: UInt, tryDirectConnect: Bool, timeoutInterval: some FixedWidthInteger) {
      self.retryLimit = retryLimit
      self.tryDirectConnect = tryDirectConnect
      self.timeoutInterval = .seconds(numericCast(timeoutInterval))
    }

    public let retryLimit: UInt
    // try direct connection if proxy env detected
    public let tryDirectConnect: Bool
    public let timeoutInterval: TimeAmount
  }
  // MARK: Caches
  private let http: HTTPClients

  private var proxySubscriptionCache: [String : [ProxyConfig]]
  private var ruleSubscriptionCache: [String: RuleProvider]

  // MARK: Runtime Properties Cache
  /// ~/.config/clash/Country.mmdb
  nonisolated private let geoDBPath: FilePath
  nonisolated private let ruleSubCachePath: FilePath
  nonisolated private let proxySubCachePath: FilePath
  nonisolated private let statsPath: FilePath
  private let configEncoder: YAMLEncoder

  /// encoder for cache/stats
  nonisolated private let cacheEncoder: JSONEncoder

  public init(workDir: FilePath, clashPath: FilePath?, configPath: FilePath, loadDaemonStats: Bool, networkOptions: NetworkOptions, options: ProxyWorldConfiguration.GenerateOptions) throws {
    self.workDir = workDir
    self.clashPath = clashPath?.string
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
    do {
      let proxyEnv = ProxyEnvironment(environment: PosixEnvironment.global.environment, parseUppercaseKey: true)
      var proxyHTTP: HTTPClient?
      if !proxyEnv.isEmpty {
        print("http client proxy enabled")
        proxyHTTP = .init(eventLoopGroupProvider: .singleton, configuration: .init(proxy: .environment(proxyEnv)))
      }
      let directHTTP = HTTPClient(eventLoopGroupProvider: .singleton)
      self.http = .init(proxy: proxyHTTP, direct: directHTTP)
    }
    config = try _readConfig(configPath: configPath)

    let decoder = JSONDecoder()
    let statsPath = workDir.appending("stats.json")
    if loadDaemonStats, SystemFileManager.fileExists(atPath: statsPath) {
      let instanceRootDir = workDir.appending("instances")
      print("load daemon stats")
      daemonStats = try .init(instanceRootPath: instanceRootDir, dataPath: statsPath, decoder: decoder)
    } else {
      daemonStats = .init()
    }
    do {
      ruleSubscriptionCache = try decoder.kwiftDecode(from: SystemFileManager.contents(ofFile: ruleSubCachePath) as Data)
      print("rule sub cache loaded")
    } catch {
      ruleSubscriptionCache = .init()
    }
    do {
      proxySubscriptionCache = try decoder.kwiftDecode(from: SystemFileManager.contents(ofFile: proxySubCachePath) as Data)
      print("proxy sub cache loaded")
    } catch {
      proxySubscriptionCache = .init()
    }
    self.statsPath = statsPath
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
      .write(to: URL(fileURLWithPath: statsPath.string), options: .atomic)
  }

  private func load(url: URL) async throws -> Data {
    var error: Error!
    let request = try HTTPClient.Request(url: url, method: .GET)

    for client in http.clients {
      for _ in 0...networkOptions.retryLimit {
        do {
          var body = try await client.execute(request: request, deadline: .now() + networkOptions.timeoutInterval)
            .get().body.unwrap()
          return try body.readData(length: body.readableBytes).unwrap()
        } catch let e {
          error = e
        }
      }
    }
    throw error
  }

  // MARK: Daemon

  private var daemonStats: DaemonStats = .init()

  public func cleanVanishedInstances() throws {
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

  public func daemonRun(enableUpdating: Bool) async {
    print("daemon running started, don't kill this process")
    defer {
      print("daemon running finished, you can exit now")
    }
    if enableUpdating {
      _ = try? await updateCaches()
    }
    var newInstancesConfigMap: [UUID: (ProxyWorldConfiguration.InstanceConfig, ClashConfig)] = .init()

    var baseConfig = ClashConfig(mode: .rule)
    baseConfig.profile?.storeSelected = true

    for config in generateClashConfigs(baseConfig: baseConfig) {
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
      let instanceDir = genInstanceWorkDir(instance: instance)
      try SystemFileManager.createDirectoryIntermediately(instanceDir)
      if firstTime {
        let fakeDBPath = instanceDir.appending("Country.mmdb")
        if !SystemFileManager.fileExists(atPath: fakeDBPath) {
          try SystemCall.createSymbolicLink(fakeDBPath, toDestination: geoDBPath).get()
        }
      }
      let configPath = instanceDir.appending("config.yaml").string
      let config = newInstancesConfigMap[instance]!.1
      let encoded = try configEncoder.encode(config)
      try encoded.write(toFile: configPath, atomically: true, encoding: .utf8)

      let exe = Clash(configurationDirectory: instanceDir.string, configurationFile: configPath)
      var command = Command(executable: clashPath ?? "clash", arguments: exe.arguments)
      command.defaultIO = .null
      command.stdout = .inherit

      print("Launching \(newInstancesConfigMap[instance]!.0.name)")
      let process = try command.spawn()

      daemonStats.add(instancdID: instance, pid: process.pid, config: config)
    }

    func kill(instanceID: UUID, removeFiles: Bool) {
      let pid = daemonStats.remove(instancdID: instanceID)
      // kill pid, remove files
      print("kill \(pid.rawValue):", Signal.kill.send(to: .processID(pid)))
      print("wait result: ", WaitPID.wait(.processID(pid)))
      if removeFiles {
        try? SystemFileManager.remove(genInstanceWorkDir(instance: instanceID))
      }
    }

    for instanceID in removedInstances {
      kill(instanceID: instanceID, removeFiles: true)
    }

    for instanceID in addedInstances {
      do {
        try prepareClash(instance: instanceID, firstTime: true)
      } catch {
        print("FAILED TO SETUP CLASH \(instanceID) \(newInstancesConfigMap[instanceID]!.0.name)")
      }
    }

    for instanceID in stayedInstances {
      let oldConfig = daemonStats.generetedClash[instanceID]!
      let newConfig = newInstancesConfigMap[instanceID]!.1
      if oldConfig != newConfig {
        let useReload = (oldConfig.httpPort == newConfig.httpPort)
        && (oldConfig.socksPort == newConfig.socksPort)
        && (oldConfig.mixedPort == newConfig.mixedPort)
        && (oldConfig.externalController == newConfig.externalController)
        // TODO: add more checks like interface

        print("RESTART CLASH \(newInstancesConfigMap[instanceID]!.0.name)")
        // reload or restart process
        kill(instanceID: instanceID, removeFiles: false)
        do {
          try prepareClash(instance: instanceID, firstTime: true)
        } catch {
          print("FAILED TO SETUP CLASH \(instanceID) \(newInstancesConfigMap[instanceID]!.0.name)")
        }
      }
    }

    do {
      try saveStats()
    } catch {
      print("FATAL ERROR saving stats: \(error)")
    }
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
        .write(to: URL(fileURLWithPath: proxySubCachePath.string), options: .atomic)
    }
    if oldCaches.1 != ruleSubscriptionCache {
      cacheUpdated = true
      try cacheEncoder.encode(ruleSubscriptionCache)
        .write(to: URL(fileURLWithPath: ruleSubCachePath.string), options: .atomic)
    }

    return cacheUpdated
  }

  public func generateClashConfigs(baseConfig: ClashConfig) -> [(ProxyWorldConfiguration.InstanceConfig, ClashConfig)] {
    config.generateClashConfigs(baseConfig: baseConfig, ruleSubscriptionCache: ruleSubscriptionCache, proxySubscriptionCache: proxySubscriptionCache, options: options)
  }

  public func terminateCLI() {
    print(#function)
    exit(0)
  }

  public struct InstanceStatus {
    let instanceID: UUID
    let running: Bool
  }

  public func reportInstances() -> [InstanceStatus] {
    daemonStats.instanceIDs
      .map { .init(instanceID: $0, running: daemonStats.checkProcessRunning(id: $0)) }
  }

  public func encodeYAML(_ config: ClashConfig) throws -> String {
    try configEncoder.encode(config)
  }
}

func defaultWorkDir() throws -> FilePath {
  try FilePath(PosixEnvironment.get(key: "HOME").unwrap("no HOME env")).appending(".config/proxy-world")
}

func defaultClashConfigDir() throws -> FilePath {
  try FilePath(PosixEnvironment.get(key: "HOME").unwrap("no HOME env")).appending(".config/clash")
}

func defaultGeoDBPath(rootPath: FilePath? = nil) throws -> FilePath {
  try (rootPath ?? defaultClashConfigDir()).appending("Country.mmdb")
}

extension FilePath: @retroactive @unchecked Sendable {}

struct Daemon: AsyncParsableCommand {

  @Option(help: "Custom work dir")
  var workDir: FilePath?

  @Option(help: "Reload config by interval if provided")
  var reloadInterval: Int?

  @Option(help: "Report instances status by interval if provided")
  var reportInterval: Int?

  @Option(help: "Refresh interval for subscription/rule")
  var refreshInterval: Int = 600

  @OptionGroup(title: "NAME GENERATION")
  var options: GroupNameGenerateOptions

  @OptionGroup(title: "NETWORK")
  var networkOptions: NetworkOptions

  @Option
  var clashPath: FilePath?

  @Argument
  var configPath: FilePath

  nonisolated(unsafe)
  static var manager: Manager?

  func run() async throws {
    let workDir = try workDir ?? defaultWorkDir()

    try SystemFileManager.createDirectoryIntermediately(workDir)

    let lockFilePath = workDir.appending(".lock")
    let lockFile = try FileDescriptor.open(lockFilePath, .readOnly, options: [.create, .truncate], permissions: .fileDefault)
    defer {
      try? lockFile.close()
    }

    do {
      try SystemCall.lock(lockFile, flags: [.exclusive, .noBlock]).get()
    } catch {
      print("another daemon for this work directory (\(workDir) is already running!")
      throw ExitCode(1)
    }
    defer { _ = SystemCall.unlock(lockFile) }

    let manager = try Manager(workDir: workDir, clashPath: clashPath, configPath: configPath, loadDaemonStats: true, networkOptions: networkOptions.toInternal, options: options.toInternal())
    Self.manager = manager

    Signal.set(handler: .custom({ signal in
      Task.detached {
        await Daemon.manager?.terminateCLI()
      }
    }), for: [.terminate, .interrupt])

    try await manager.cleanVanishedInstances()

    if let reloadInterval {
      Task(priority: .background) {
        let reloadInterval = Duration.seconds(reloadInterval)
        while true {
          try await Task.sleep(for: reloadInterval)
          do {
            let reloadResult = try await manager.reloadConfig()
            if reloadResult.configChanged {
              print("run daemon because of updated")
              await manager.daemonRun(enableUpdating: reloadResult.sharedChanged)
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

    if let reportInterval {
      Task(priority: .background) {
        let reportInterval = Duration.seconds(reportInterval)
        while true {
          try await Task.sleep(for: reportInterval)
          let stats = await manager.reportInstances()
          print("status report:")
          for stat in stats {
            print("id: \(stat.instanceID), running: \(stat.running)")
          }
        }
      }
    } else {
      print("report disabled")
    }

    // first time
    await manager.daemonRun(enableUpdating: !networkOptions.skipFirstRefresh)

    let refreshInterval: Duration = .seconds(refreshInterval)
    while true {
      try? await Task.sleep(for: refreshInterval)
      await manager.daemonRun(enableUpdating: true)
    }
  }
}
