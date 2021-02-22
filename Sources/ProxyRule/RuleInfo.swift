public struct RuleInfo: Codable, Equatable {

  public var ruleType: RuleType
  public var matchers: [String]
  public var noResolve: Bool

  public init(_ ruleType: RuleType, _ matchers: [String], noResolve: Bool = false) {
    self.ruleType = ruleType
    self.matchers = matchers
    self.noResolve = noResolve
  }

  public init(_ ruleType: RuleType, _ matcher: String, noResolve: Bool = false) {
    self.ruleType = ruleType
    self.matchers = [matcher]
    self.noResolve = noResolve
  }

  func isRuleNoResolveSupported(for client: ProxyClient) -> Bool {
    switch client {
    case .clash:
      switch ruleType {
      case .geoip, .ipCIDR, .ipCIDR6:
        return true
      default:
        return false
      }
    case .quantumult:
      return false
    }
  }
}
