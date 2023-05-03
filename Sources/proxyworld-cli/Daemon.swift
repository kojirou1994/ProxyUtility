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

struct ClashProcessInfo {
  let pid: Int32
}

actor Manager {

  private let configPath: FilePath
  private var config: ProxyWorldConfiguration

  // MARK: Caches
  private let session = URLSession(configuration: .ephemeral)
  private var proxyCache = [String: [ProxyConfig]]()
  private var ruleCache = [String: RuleProvider]()

  public init(configPath: FilePath) throws {
    self.configPath = configPath
    config = try _readConfig(configPath: configPath)
  }


  /// Reload config
  /// - Returns: true if config changed
  public func reloadConfig() throws -> Bool {
    print(#function)
    let newConfig = try _readConfig(configPath: configPath)
    let updated = newConfig != config
    if updated {
      config = newConfig
    }
    return updated
  }

  private func load(url: URL) async throws -> Data {
    try await session.data(for: URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 20)).0
  }

  public func refresh() async throws {
    print(#function)
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
  }

  public func generateClashConfigs(
    baseConfig: ClashConfig,
    options: ProxyWorldConfiguration.GenerateOptions,
    fallback: (ProxyConfig) -> ClashProxy?) -> [(ProxyWorldConfiguration.InstanceConfig, ClashConfig)] {
      config.generateClashConfigs(baseConfig: baseConfig, ruleSubscriptionCache: ruleCache, proxySubscriptionCache: proxyCache, options: options, fallback: fallback)
    }
}

struct Daemon: AsyncParsableCommand {

  @Option(help: "Reload config by interval if provided")
  var reloadInterval: Int?

  @Option(help: "Refresh interval for subscription/rule")
  var refreshInterval: Int = 600

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

    let manager = try Manager(configPath: configPath)

    if let reloadInterval {
      Task {
        let reloadInterval = Duration.seconds(reloadInterval)
        while true {
          try await Task.sleep(for: reloadInterval)
          do {
            if try await manager.reloadConfig() {
              print("refresh because of updated")
              try? await manager.refresh()
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
      try? await manager.refresh()
      try await Task.sleep(for: refreshInterval)
    }
  }
}
