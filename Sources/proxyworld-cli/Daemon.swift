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

private func _readConfig(configPath: FilePath) throws -> ProxyWorldConfiguration {
  let fd = try FileDescriptor.open(configPath, .readOnly)
  return try fd.closeAfter {
    try JSONDecoder().kwiftDecode(from: SystemFileManager.contents(ofFileDescriptor: fd) as Data, as: ProxyWorldConfiguration.self)
  }
}

struct DaemonState {
  private var runningClash: [UUID: WaitPID.PID] = .init()
  internal private(set) var generetedClash: [UUID: ClashConfig] = .init()
  internal private(set) var instanceIDs: Set<UUID> = .init()

  init() {
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
}

struct ClashProcessInfo {
  let pid: Int32
}

actor Manager {

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

  public init(configPath: FilePath, networkOptions: NetworkOptions, options: ProxyWorldConfiguration.GenerateOptions) throws {
    self.configPath = configPath
    self.networkOptions = networkOptions
    self.options = options
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

  private var deamonStates: DaemonState = .init()

  public func daemonRun(enableUpdating: Bool) async throws {
    if enableUpdating {
      try await updateCaches()
    }
    let configs = generateClashConfigs(baseConfig: .init(mode: .rule))

    // generate clash configs for each instance
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
    let workDir = try FilePath(PosixEnvironment.get(key: "HOME").unwrap("no HOME env")).appending(".config/proxy-world")

    try SystemFileManager.createDirectoryIntermediately(.absolute(workDir))

    let lockFilePath = workDir.appending(".lock")
    let lockFile = try FileDescriptor.open(lockFilePath, .readOnly, options: [.create, .truncate], permissions: .fileDefault)
    defer {
      _ = FileSyscalls.unlock(lockFile)
      try? lockFile.close()
    }

    do {
      try FileSyscalls.lock(lockFile, flags: [.exclusive, .noBlock]).get()
    } catch {
      print("another daemon already running!")
      throw ExitCode(1)
    }

    let manager = try Manager(configPath: configPath, networkOptions: networkOptions.toInternal, options: options.toInternal())

    if let reloadInterval {
      Task {
        let reloadInterval = Duration.seconds(reloadInterval)
        while true {
          try await Task.sleep(for: reloadInterval)
          do {
            let reloadResult = try await manager.reloadConfig()
            if reloadResult.configChanged {
              print("refresh because of updated")
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
