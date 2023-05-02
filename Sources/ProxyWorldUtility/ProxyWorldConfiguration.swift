import Foundation
import ClashSupport
import ProxySubscription
import ProxyUtility
import ProxyRule
import Precondition
import CUtility
import SystemUp

public struct ProxyWorldProxy: Identifiable, Equatable, Codable {
  public let id: UUID
  public let proxy: ClashProxy
//  public var alterHosts: [AlterIP]

  public init(proxy: ClashProxy) {
    self.id = .init()
    self.proxy = proxy
  }

  public struct AlterIP: Equatable, Codable {
    public let host: String
    public let name: String?
  }
}

public enum PolicySwitchCutMethod: String, Codable, Equatable, CaseIterable, Identifiable, CustomStringConvertible {

  case disable
  case killRelated
  case killAll

  public var id: Self { self }

  public var description: String {
    rawValue
  }
}

extension ClashConfig.ProxyGroup.ProxyGroupType: Identifiable {
  public var id: Self { self }
}

public struct ProxyNodeSubscription: Identifiable, Codable, Equatable, Hashable {
  public let id: UUID
  public var name: String
  public var url: URL
  public var type: ProxySubscriptionType
  public var autogen: Set<ClashConfig.ProxyGroup.ProxyGroupType>

  public init(name: String, url: URL, type: ProxySubscriptionType,
              autogen: Set<ClashConfig.ProxyGroup.ProxyGroupType>) {
    self.name = name
    self.url = url
    self.type = type
    self.autogen = autogen
    id = .init()
  }
}

public struct StorageConfig: Codable, Equatable {
  public var rules: [RuleCollection]
  public var ruleSubscriptions: [ProxyWorldRuleSubscription]

  public var proxies: [ProxyWorldProxy]
  public var subscriptions: [ProxyNodeSubscription]

}

public struct InstanceConfig: Codable, Equatable {
  public let id: UUID
  public var name: String
  public var dns: ClashConfig.ClashDNS
  public var normal: ProxyWorldConfiguration.NormalConfiguration

  public var rules: [InstanceRule]
  public enum InstanceRule: Codable, Equatable {
    case subscription(UUID, overridePolicies: [RuleCollectionOverridePolicy])
    case collection(UUID)
  }

  public var enabledProxies: [UUID]
  public var enabledSubscriptions: [UUID]
}

public struct ProxyWorldConfiguration: Codable, Equatable {
  public init(
    rules: [RuleCollection], ruleSubscriptions: [ProxyWorldRuleSubscription],
    proxies: [ProxyWorldProxy], subscriptions: [ProxyNodeSubscription],
    dns: ClashConfig.ClashDNS, normal: ProxyWorldConfiguration.NormalConfiguration) {
    self.rules = rules
    self.ruleSubscriptions = ruleSubscriptions
    self.subscriptions = subscriptions
    self.dns = dns
    self.normal = normal
    self.proxies = proxies
  }

  public var rules: [RuleCollection]
  public var ruleSubscriptions: [ProxyWorldRuleSubscription]

  public var proxies: [ProxyWorldProxy]
  public var subscriptions: [ProxyNodeSubscription]

  public var dns: ClashConfig.ClashDNS
  public var normal: NormalConfiguration
  //    var exterbak: ExternalProxyConfig
}
extension ProxyWorldConfiguration {
  public struct ExternalProxyConfig: Codable, Equatable {
    public var portStart: Int
    public var portBlacklist: [Int]
  }

  public struct NormalConfiguration: Codable, Equatable {
    public init(
      mainProxyName: String,
      userProxyGroupName: String,
      finalDirect: Bool, logLevel: ClashConfig.LogLevel, allowLan: Bool,
      httpPort: Int?, socksPort: Int?, apiPort: Int) {
      self.mainProxyGroupName = mainProxyName
      self.userProxyGroupName = userProxyGroupName
      self.finalDirect = finalDirect
      self.logLevel = logLevel
      self.allowLan = allowLan
      self.httpPort = httpPort
      self.socksPort = socksPort
      self.apiPort = apiPort
    }

    // group
    public var mainProxyGroupName: String
    public var userProxyGroupName: String
    //        var selectUseMainProxy: Bool
    //        var useSubGroupForSubcriptions = true

    //        var joinSelectCatory: Bool

    // rule
    public var finalDirect: Bool
    public var autoAddLanRules: Bool = true
    public var addDirectToMainProxy: Bool = true

    public var logLevel: ClashConfig.LogLevel
    public var allowLan: Bool
    public var httpPort: Int?
    public var socksPort: Int?
    public var mixedPort: Int?
    public var apiPort: Int
    public var apiBindAddress: String?
    /// not working now, set this to Charles proxy or something
    public var overrideDirect: String?

    public var serverCheckUrl: String?
    public var serverCheckInterval: Int?
  }
}

let defaultServerCheckUrl = "http://www.google.com/generate_204"
let defaultServerCheckInterval = 300

extension ProxyWorldConfiguration {

  public struct GenerateOptions {
    public struct FormatStringError: Error {
      public let name: String
      public let required: String
    }

    public init(ruleGroupNameFormat: String, urlTestGroupNameFormat: String, fallbackGroupNameFormat: String) throws {
      try [
        (ruleGroupNameFormat, "ruleGroupNameFormat"),
        (urlTestGroupNameFormat, "urlTestGroupNameFormat"),
        (fallbackGroupNameFormat, "fallbackGroupNameFormat"),
      ].forEach { (format, name) in
        if !format.contains("%s") {
          throw FormatStringError(name: name, required: "%s")
        }
      }
      self.ruleGroupNameFormat = ruleGroupNameFormat
      self.urlTestGroupNameFormat = urlTestGroupNameFormat
      self.fallbackGroupNameFormat = fallbackGroupNameFormat
    }

    let ruleGroupNameFormat: String
    let urlTestGroupNameFormat: String
    let fallbackGroupNameFormat: String
  }

  public func generateClash(baseConfig: ClashConfig, mode: ClashConfig.Mode,
                            ruleSubscriptionCache: [String : RuleProvider],
                            proxySubscriptionCache: [String : [ProxyConfig]],
                            options: GenerateOptions,
                            fallback: (ProxyConfig) -> ClashProxy? = { _ in nil } ) -> ClashConfig {

    var proxyGroup: [ClashConfig.ProxyGroup] = []
    var outputProxies = [ClashProxy]()
    var outputRules: [Rule] = []

    // Check proxy name conflict
    var allProxyNames = Set<String>()
    var availableProxies: [String: [ClashProxy]] = .init()
    var urlTestProxies: [String: [ClashProxy]] = .init()
    var fallbackProxies: [String: [ClashProxy]] = .init()

    for subscription in subscriptions {
      var groupProxies = [ClashProxy]()
      let cachedNodes = proxySubscriptionCache[subscription.id.uuidString] ?? []
      for proxy in cachedNodes {
        var clashProxy = ClashProxy(proxy)
        let originalName = clashProxy.name
        if originalName.isEmpty {
          print("No name")
        } else {
          clashProxy.name = allProxyNames.makeUniqueName(basename: clashProxy.name, keyPath: \.self)
          allProxyNames.insert(clashProxy.name)
          groupProxies.append(clashProxy)
        }
      }
      if groupProxies.isEmpty {
        print("No available nodes in subscription: \(subscription.name)")
      } else {
        let groupName = availableProxies.keys.makeUniqueName(basename: subscription.name, keyPath: \.self)
        if subscription.autogen.contains(.select) {
          availableProxies[groupName] = groupProxies
        }
        if subscription.autogen.contains(.urlTest) {
          // TODO: maybe just use replace
          let genName = groupName.withCString { groupName in
            try! LazyCopiedCString(format: options.urlTestGroupNameFormat, groupName).string
          }
          urlTestProxies[genName] = groupProxies
        }
        if subscription.autogen.contains(.fallback) {
          let genName = groupName.withCString { groupName in
            try! LazyCopiedCString(format: options.fallbackGroupNameFormat, groupName).string
          }
          fallbackProxies[genName] = groupProxies
        }
      }
    }

    // User's custom proxies
    if !proxies.isEmpty {
      let userProxyGroupName = availableProxies.keys.makeUniqueName(basename: normal.userProxyGroupName, keyPath: \.self)

      availableProxies[userProxyGroupName] = proxies.map { $0.proxy }
    }
    availableProxies.values.forEach { outputProxies.append(contentsOf: $0) }

    var mainGroupProxies = [String]()

    if normal.addDirectToMainProxy {
      mainGroupProxies.append(ClashConfig.directPolicy)
    }

    // generate group for each subscription

    let subGroups = availableProxies.map { ClashConfig.ProxyGroup.select(name: $0.key, proxies: $0.value.map { $0.name }) }
    proxyGroup.append(contentsOf: subGroups)

    // url-test or fallback
    let checkUrl: String
    if let provided = normal.serverCheckUrl, !provided.isEmpty {
      checkUrl = provided
    } else {
      checkUrl = defaultServerCheckUrl
    }
    let checkInterval: Int
    if let provided = normal.serverCheckInterval, provided > 30 {
      checkInterval = provided
    } else {
      checkInterval = defaultServerCheckInterval
    }
    let urlTestGroups = urlTestProxies
      .map { ClashConfig.ProxyGroup.urlTest(name: $0.key, proxies: $0.value.map(\.name), url: checkUrl, interval: checkInterval) }
    let fallbackGroups = fallbackProxies
      .map { ClashConfig.ProxyGroup.fallback(name: $0.key, proxies: $0.value.map(\.name), url: checkUrl, interval: checkInterval) }
    proxyGroup.append(contentsOf: urlTestGroups)
    proxyGroup.append(contentsOf: fallbackGroups)
    mainGroupProxies.append(contentsOf: availableProxies.keys.sorted())
    mainGroupProxies.append(contentsOf: urlTestProxies.keys.sorted())
    mainGroupProxies.append(contentsOf: fallbackProxies.keys.sorted())

    // main group
    let mainGroup = ClashConfig.ProxyGroup.select(name: normal.mainProxyGroupName, proxies: mainGroupProxies)

    proxyGroup.insert(mainGroup, at: 0)

    // Begin rules and rule selection group

    let ruleSelectGroupProxies = CollectionOfOne(mainGroup.name) + mainGroupProxies

    func generateAndAddRuleGroup<T: Collection>(
      namePrefix: String = "", ruleCollections: T,
      overridePoliciesDictionary: [String : AbstractRulePolicy]? = nil)
    where T.Element == RuleCollection {

      for ruleCollection in ruleCollections {
        let basename = (namePrefix + ruleCollection.name).withCString { groupName in
          try! LazyCopiedCString(format: options.ruleGroupNameFormat, groupName).string
        }
        let newSelectGroupName = proxyGroup.makeUniqueName(basename: basename, keyPath: \.name)
        let selectGroup = ClashConfig.ProxyGroup.select(name: newSelectGroupName, proxies: ruleSelectGroupProxies)

        var matcherCount = [AbstractRulePolicy : Int]()

        let policy = overridePoliciesDictionary?[ruleCollection.name] ?? ruleCollection.recommendedPolicy

        for ruleInfo in ruleCollection.rules where !ruleInfo.matchers.isEmpty {
          matcherCount[policy, default: 0] += ruleInfo.matchers.count
          let policyName: String
          switch policy {
          case .direct: policyName = ClashConfig.directPolicy
          case .proxy: policyName = normal.mainProxyGroupName
          case .reject: policyName = ClashConfig.rejectPolicy
          case .select:
            // generate rule group
            policyName = newSelectGroupName
          case .selectProxy, .selectIpRegion:
            fatalError("Unimplemented")
          }

          outputRules.append(.init(info: ruleInfo, policy: policyName))
        }
        if matcherCount[.select, default: 0] > 0 {
          // or use direct/mainProxy
          proxyGroup.append(selectGroup)
        }
      }

    }

    for ruleCollection in rules {
      generateAndAddRuleGroup(ruleCollections: CollectionOfOne(ruleCollection))
    }

    for ruleSubscription in ruleSubscriptions {
      guard let cachedRuleProvider = ruleSubscriptionCache[ruleSubscription.id.uuidString] else {
        continue
      }
      var customName: String = ruleSubscription.name.isEmpty ? cachedRuleProvider.name : ruleSubscription.name
      if !customName.isEmpty {
        customName.append(" - ")
      }
      generateAndAddRuleGroup(namePrefix: customName, ruleCollections: cachedRuleProvider.collections, overridePoliciesDictionary: ruleSubscription.overridePoliciesDictionary)
    }

    if normal.finalDirect {
      outputRules.append(Rule(.final, "", ClashConfig.directPolicy))
    } else {
      outputRules.append(Rule(.final, "", normal.mainProxyGroupName))
    }

    var config = baseConfig
    config.proxyGroups = proxyGroup
    config.logLevel = normal.logLevel
    config.rules = outputRules.flatMap { $0.generateConfigLines(for: .clash) }
    config.allowLan = normal.allowLan
    config.externalController = "\(normal.apiBindAddress ?? "127.0.0.1"):\(normal.apiPort)"
    config.mode = mode
    config.ipv6 = dns.ipv6
    config.socksPort = normal.socksPort
    config.httpPort = normal.httpPort
    config.mixedPort = normal.mixedPort
    config.dns = dns
    config.proxies = outputProxies

    return config
  }
}
