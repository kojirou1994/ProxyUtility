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

enum ConfigFormat: String, ExpressibleByArgument, CaseIterable {
  case clash
  case qx
  case qxServer
  case qxFilter
}

@main
struct GenerateProxyConfig: ParsableCommand {

  @Option(name: .shortAndLong)
  var output: String

  @Option(name: .shortAndLong, help: "Available: \(ConfigFormat.allCases.map(\.rawValue).joined(separator: ", "))")
  var format: ConfigFormat

  @Flag
  var verbose: Bool = false

  @Argument()
  var configPath: String

  func run() throws {
    let fm = URLFileManager.default
    let inputURL = URL(fileURLWithPath: configPath)
    let outputURL = URL(fileURLWithPath: output)
    try preconditionOrThrow(!fm.fileExistance(at: outputURL).exists, "Output existed!")
    let config = try JSONDecoder().kwiftDecode(from: Data(contentsOf: inputURL), as: ProxyWorldConfiguration.self)
    let session = URLSession(configuration: .ephemeral)

    var proxyCache = [String: [ProxyConfig]]()
    var ruleCache = [String: RuleProvider]()

    config.subscriptions.forEach { subscription in
      do {
        print("Start to update subscription \(subscription.name)")
        let response = try session
          .syncResultTask(with: URLRequest(url: subscription.url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 20))
          .get()

        let content = SubscriptionContent(subscription.type.decode(response.data))
        print("Success!")
        if content.metadata.hasUsefulInfo {
          print("Information: \(content.metadata)")
        }
        print("Totally \(content.configs.count) nodes.")
        proxyCache[subscription.id.uuidString] = content.configs
        if verbose {
          content.configs.forEach { config in
            print(config)
          }
        }
      } catch {
        print("Error while updating subscription \(subscription.name), \(error)")
      }
    }

    config.ruleSubscriptions.forEach { ruleSubscription in
      do {
        print("Start to update rule subscription \(ruleSubscription.name)")
        let subscriptionData: Data
        if ruleSubscription.isLocalFile {
          subscriptionData = try Data(contentsOf: URL(fileURLWithPath: ruleSubscription.url))
        } else {
          subscriptionData = try session
            .syncResultTask(with: URLRequest(url: URL(string: ruleSubscription.url)!, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 20))
            .get().data
        }
        let decoded = try YAMLDecoder().decode(from: String(decoding: subscriptionData, as: UTF8.self)) as RuleProvider
        print("Success!")
        ruleCache[ruleSubscription.id.uuidString] = decoded
      } catch {
        print("Error while updating subscription \(ruleSubscription.name), \(error)")
      }
    }

    let clashConfig = config.generateClash(
      baseConfig: ClashConfig(mode: .rule),
      mode: .rule,
//      tailDirectRules: Rule.normalLanRules,
      ruleSubscriptionCache: ruleCache,
      proxySubscriptionCache: proxyCache,
      ruleGroupPrefix: "[RULE] ",
      urlTestGroupPrefix: "[BEST] ",
      fallbackGroupPrefix: "[FALLBACK] ") { _ in nil }

    let outputString: String
    switch format {
    case .clash:
      outputString = try YAMLEncoder().encode(clashConfig)
    case .qx:
      outputString = clashConfig.quantumultXConfig
    case .qxServer:
      outputString = clashConfig.serverLocalQXLines
    case .qxFilter:
      outputString = clashConfig.filterLocalQXLines
    }

    print("Writing...")
    try outputString.write(to: outputURL, atomically: true, encoding: .utf8)
  }
}
