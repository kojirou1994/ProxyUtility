import Foundation
import ProxyWorldUtility
import KwiftExtension
import ProxySubscription
import ProxyUtility
import URLFileManager
import ClashSupport
import ProxyRule
import Yams
import ArgumentParser
import QuantumultSupport
import Precondition
import SystemPackage
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

  let configPath: FilePath
  var config: ProxyWorldConfiguration

  // MARK: Caches
  private let session = URLSession(configuration: .ephemeral)
  var proxyCache = [String: [ProxyConfig]]()
  var ruleCache = [String: RuleProvider]()

  init(configPath: FilePath) throws {
    self.configPath = configPath
    config = try _readConfig(configPath: configPath)
  }

  func reloadConfig() throws -> Bool {
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

  func refresh() async throws {
    print(#function)
    for subscription in config.subscriptions {
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

    for ruleSubscription in config.ruleSubscriptions {
      do {
        print("Start to update rule subscription \(ruleSubscription.name)")
        let subscriptionData: Data
        if ruleSubscription.isLocalFile {
          subscriptionData = try Data(contentsOf: URL(fileURLWithPath: ruleSubscription.url))
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

  func generateClash(
    baseConfig: ClashConfig,
    mode: ClashConfig.Mode,
    ruleGroupPrefix: String,
    urlTestGroupPrefix: String,
    fallbackGroupPrefix: String,
    fallback: (ProxyConfig) -> ClashProxy?) -> ClashConfig {
      config.generateClash(baseConfig: baseConfig, mode: mode, ruleSubscriptionCache: ruleCache, proxySubscriptionCache: proxyCache, ruleGroupPrefix: ruleGroupPrefix, urlTestGroupPrefix: urlTestGroupPrefix, fallbackGroupPrefix: fallbackGroupPrefix, fallback: fallback)
    }
}

struct Daemon: AsyncParsableCommand {

  @Option(help: "Reload config by interval if provided")
  var reloadInterval: Int?

  @Option(help: "Refresh interval for subscription/rule")
  var refreshInterval: Int = 1

  @Argument
  var configPath: FilePath

  func run() async throws {
    let manager = try Manager(configPath: configPath)

    let refreshInterval: Duration = .seconds(refreshInterval)
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

    while true {
      try? await manager.refresh()
      try await Task.sleep(for: refreshInterval)
    }
  }
}
