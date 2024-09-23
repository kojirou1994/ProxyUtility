import Foundation

public struct Rule: CustomStringConvertible, Codable {

  public static func parse<S: StringProtocol>(_ string: S, allowEmptyPolicy: Bool = false) -> Self? {
    let parts = string.split(separator: ",", omittingEmptySubsequences: false)
    guard parts.count > 1,
          let ruleType = RuleType(rawValue: String(parts[0])) else {
      return nil
    }
    let matcher: String
    let policy: String
    if ruleType == .final {
      matcher = .init()
      policy = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
    } else {
      guard parts.count > 2 else {
        return nil
      }
      matcher = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
      policy = parts[2].trimmingCharacters(in: .whitespacesAndNewlines)
    }
    if !allowEmptyPolicy, policy.isEmpty {
      return nil
    }
    return .init(info: .init(ruleType, matcher, noResolve: parts.dropFirst(3).contains("no-resolve")), policy: policy)
  }

  public var description: String {
    if info.ruleType == .final {
      return "\(info.ruleType.rawValue),\(policy)"
    }
    return "\(info.ruleType.rawValue),\(info.matchers),\(policy)"
  }

  public func generateConfigLines(for client: ProxyClient) -> [String] {
    info.ruleType.supports(for: client)
      ?
      info.matchers.map { matcher in
        var line = info.ruleType.string(for: client)
        if info.ruleType != .final {
          line.append(",")
          line.append(matcher)
        }
        line.append(",")
        line.append(policy)

        if info.noResolve,
           info.isRuleNoResolveSupported(for: client) {
          line.append(",")
          line.append("no-resolve")
        }

        return line
      }
      : []
  }

  public var info: RuleInfo
  public var policy: String

  /// this init method will not check if matcher is empty string
  public init(info: RuleInfo, policy: String) {
    self.info = info
    self.policy = policy
  }

  public init(_ ruleType: RuleType, _ matcher: String, _ policy: String, noResolve: Bool = false) {
    self.info = .init(ruleType, matcher, noResolve: noResolve)
    self.policy = policy
  }
}

public class RuleManager {

  public let forceDirect: String
  public let forceProxy: String
  public let forceReject: String

  public let selectProxy: String

  public let finalPolicy: String

  private func readRules(_ filename: String) -> [Rule] {
    (try? String.init(contentsOfFile: filename).components(separatedBy: .newlines).compactMap{ Rule.parse($0) }) ?? []
  }

  public var selectPolicies: [String] {
    readRules(selectProxy).map{$0.policy}
  }

  public var allRules: [Rule] {
    readRules(forceProxy) + readRules(forceDirect) + readRules(selectProxy)
      + readRules(forceReject) + Rule.normalLanRules + [Rule(.final, "", finalPolicy)]
  }

  public init(forceDirect: String, forceProxy: String, forceReject: String, selectProxy: String, finalPolicy: String) {
    self.forceDirect = forceDirect
    self.forceProxy = forceProxy
    self.forceReject = forceReject
    self.selectProxy = selectProxy
    self.finalPolicy = finalPolicy
  }

}

extension Rule {
  nonisolated(unsafe)
  public static let normalLanRules: [Rule] = [
    .init(.ipCIDR, "10.0.0.0/8", ""),
    .init(.ipCIDR, "100.64.0.0/10", ""),
    .init(.ipCIDR, "127.0.0.0/8", ""),
    .init(.ipCIDR, "17.0.0.0/8", ""),
    .init(.ipCIDR, "192.168.0.0/16", ""),
    .init(.ipCIDR, "172.16.0.0/12", ""),
    .init(.geoip, "CN", "")
  ]
}
