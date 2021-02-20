import Foundation
import ClashSupport
import ProxySubscription
import ProxyUtility
import ProxyRule

public struct ProxyWorldProxy: Identifiable, Equatable, Codable {
  public let id: UUID
  public let proxy: ClashProxy

  public init(proxy: ClashProxy) {
    self.id = .init()
    self.proxy = proxy
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

public struct ProxyWorldSubscription: Identifiable, Codable, Equatable, Hashable {
  public var id: UUID
  public var name: String
  public var url: URL
  public var type: ProxySubscriptionType
  public var generateAutoGroup: Bool
  public var generateFallbackGroup: Bool

  public init(name: String, url: URL, type: ProxySubscriptionType,
              generateAutoGroup: Bool, generateFallbackGroup: Bool) {
    self.name = name
    self.url = url
    self.type = type
    self.generateAutoGroup = generateAutoGroup
    self.generateFallbackGroup = generateFallbackGroup
    id = .init()
  }
}

public struct ProxyWorldConfiguration: Codable, Equatable {
  public init(rules: [ProxyWorldRuleGroup], subscriptions: [ProxyWorldSubscription], dns: ClashConfig.ClashDNS, normal: ProxyWorldConfiguration.NormalConfiguration, proxies: [ProxyWorldProxy]) {
    self.rules = rules
    self.subscriptions = subscriptions
    self.dns = dns
    self.normal = normal
    self.proxies = proxies
  }

  public var rules: [ProxyWorldRuleGroup]
  public var subscriptions: [ProxyWorldSubscription]
  public var dns: ClashConfig.ClashDNS
  public var normal: NormalConfiguration
  //    var exterbak: ExternalProxyConfig
  public var proxies: [ProxyWorldProxy]
}
extension ProxyWorldConfiguration {
  public struct ExternalProxyConfig: Codable, Equatable {
    public var portStart: Int
    public var portBlacklist: [Int]
  }

  public struct NormalConfiguration: Codable, Equatable {
    public init(mainProxyName: String,
                  userProxyGroupName: String,
                  //                      selectUseMainProxy: Bool,
                  //                      joinSelectCatory: Bool,
                  finalDirect: Bool, logLevel: ClashConfig.LogLevel, allowLan: Bool,
                  httpPort: Int, socksPort: Int, apiPort: Int) {
      self.mainProxyGroupName = mainProxyName
      self.userProxyGroupName = userProxyGroupName
      //            self.selectUseMainProxy = selectUseMainProxy
      //            self.joinSelectCatory = joinSelectCatory
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

    public var logLevel: ClashConfig.LogLevel
    public var allowLan: Bool
    public var httpPort: Int
    public var socksPort: Int
    public var apiPort: Int
    public var apiBindAddress: String?
  }
}

extension ProxyWorldConfiguration {
  public func generateClash(
    baseConfig: ClashConfig,
    mode: ClashConfig.Mode,
    tailDirectRules: [Rule],
    proxyCache: [String : [ProxyConfig]],
    ruleGroupPrefix: String,
    urlTestGroupPrefix: String,
    fallbackGroupPrefix: String,
    fallback: (ProxyConfig) -> ClashProxy?) -> ClashConfig {

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
      let cachedNodes = proxyCache[subscription.id.uuidString] ?? []
      for proxy in cachedNodes {
        var clashProxy = ClashProxy(proxy)
        let originalName = clashProxy.name
        if originalName.isEmpty {
          print("No name")
        } else {
          clashProxy.name = allProxyNames.makeUniqueName(basename: clashProxy.name, keyPath: \.self)
          //                    var number = 1
          //                    while allProxyNames.contains(clashProxy.name) {
          //                        clashProxy.name = "\(originalName) \(number)"
          //                        number += 1
          //                    }
          allProxyNames.insert(clashProxy.name)
          groupProxies.append(clashProxy)
        }
      }
      if groupProxies.isEmpty {
        print("No available nodes in subscription: \(subscription.name)")
      } else {
        let groupName = availableProxies.keys.makeUniqueName(basename: subscription.name, keyPath: \.self)
        availableProxies[groupName] = groupProxies
        if subscription.generateAutoGroup {
          urlTestProxies[urlTestGroupPrefix + groupName] = groupProxies
        }
        if subscription.generateFallbackGroup {
          fallbackProxies[fallbackGroupPrefix + groupName] = groupProxies
        }
      }
    }

    // User's custom proxies
    if !proxies.isEmpty {
      let userProxyGroupName = availableProxies.keys.makeUniqueName(basename: normal.userProxyGroupName, keyPath: \.self)

      availableProxies[userProxyGroupName] = proxies.map { $0.proxy }
    }
    availableProxies.values.forEach { outputProxies.append(contentsOf: $0) }

    var mainGroupProxies: [String] = [ClashConfig.directPolicy]

    // generate group for each subscription

    let subGroups = availableProxies.map { ClashConfig.ProxyGroup.select(name: $0.key, proxies: $0.value.map { $0.name }) }
    proxyGroup.append(contentsOf: subGroups)

    // url-test or fallback
    let urlTestGroups = urlTestProxies
      .map { ClashConfig.ProxyGroup.urlTest(name: $0.key, proxies: $0.value.map { $0.name }, url: "http://www.gstatic.com/generate_204", interval: 300) }
    let fallbackGroups = fallbackProxies
      .map { ClashConfig.ProxyGroup.fallback(name: $0.key, proxies: $0.value.map { $0.name }, url: "http://www.gstatic.com/generate_204", interval: 300) }
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

    for ruleSet in rules {
      var tempRules = ruleSet.nodes.flatMap { $0.rules }
      let policyName: String
      switch ruleSet.policy {
      case .direct: policyName = ClashConfig.directPolicy
      case .proxy: policyName = normal.mainProxyGroupName
      case .reject: policyName = ClashConfig.rejectPolicy
      case .select, .selectProxy:
        // generate rule group
        policyName = proxyGroup.makeUniqueName(basename: ruleGroupPrefix + ruleSet.name, keyPath: \.name)
        let selectGroup = ClashConfig.ProxyGroup.select(name: policyName, proxies: ruleSelectGroupProxies)
        // or use direct/mainProxy
        proxyGroup.append(selectGroup)
      }

      for index in tempRules.indices {
        tempRules[index].policy = policyName
      }
      outputRules.append(contentsOf: tempRules)
    }

    tailDirectRules.forEach { rule in
      #warning("fix me")
//      outputRules.append(.init(rule.info.ruleType, rule.info.matchers, ClashConfig.directPolicy))
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
//    if config.allowLan == nil {
      config.allowLan = normal.allowLan
//    }
    config.externalController = "\(normal.apiBindAddress ?? "127.0.0.1"):\(normal.apiPort)"
    config.mode = mode
//    if config.socksPort == nil {
      config.socksPort = normal.socksPort
//    }
//    if config.httpPort == nil {
      config.httpPort = normal.httpPort
//    }
//    if config.dns == nil {
      config.dns = dns
//    }
    config.proxies = outputProxies
    return config
  }
}
