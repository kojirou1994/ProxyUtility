import Foundation

public enum RuleType: String, CustomStringConvertible, CaseIterable, Codable {
  case domain = "DOMAIN"
  case domainSuffix = "DOMAIN-SUFFIX"
  case domainKeyword = "DOMAIN-KEYWORD"
  case ipCIDR = "IP-CIDR"
  case geoip = "GEOIP"
  case final = "FINAL"
  case userAgent = "USER-AGENT"
  case urlRegex = "URL-REGEX"
  case processName = "PROCESS-NAME"
  case destPort = "DEST-PORT"
  case srcIPCIDR = "SRC-IP-CIDR"
  case srcPort = "SRC-PORT"

  public var description: String { return rawValue }

  public func supports(for client: Client) -> Bool {
    switch client {
    case .quantumult:
      switch self {
      case .domain, .domainKeyword, .domainSuffix, .final, .ipCIDR, .geoip:
        return true
      default:
        return false
      }
    case .clash :
      switch self {
      case .userAgent, .urlRegex, .processName:
        return false
      default:
        return true
      }
    }
  }

  public func string(for client: Client) -> String {
    switch (client, self) {
    case (.clash, .final):
      return "MATCH"
    case (.clash, .destPort):
      return "DST-PORT"
    case (.quantumult, .domainSuffix):
      return "HOST-SUFFIX"
    case (.quantumult, .domainKeyword):
      return "HOST-KWYWORD"
    case (.quantumult, .domain):
      return "HOST"
    default:
      return rawValue
    }
  }

  public static let clashSupported = Self.allCases.filter {$0.supports(for: .clash)}

}

public struct Rule: CustomStringConvertible, Codable {

  public static func parse<S: StringProtocol>(_ string: S, allowEmptyPolicy: Bool = false) -> Self? {
    let parts = string.split(separator: ",", omittingEmptySubsequences: false)
    guard (parts.count == 2 || parts.count == 3),
          let type = RuleType(rawValue: String(parts[0])) else {
      return nil
    }
    let matcher: String
    let policy: String
    if type == .final {
      matcher = .init()
      policy = parts.last!.trimmingCharacters(in: .whitespacesAndNewlines)
    } else {
      guard parts.count == 3 else {
        return nil
      }
      matcher = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
      policy = parts[2].trimmingCharacters(in: .whitespacesAndNewlines)
    }
    if !allowEmptyPolicy, policy.isEmpty {
      return nil
    }
    return .init(type: type, matcher: matcher, policy: policy)
  }

  public var description: String {
    if type == .final {
      return "\(type.rawValue),\(policy)"
    }
    return "\(type.rawValue),\(matcher),\(policy)"
  }

  public func generateConfigLine(for client: Client) -> String? {
    guard type.supports(for: client) else {
      return nil
    }
    if type == .final {
      return "\(type.string(for: client)),\(policy)"
    }
    return "\(type.string(for: client)),\(matcher),\(policy)"
  }

  /// this init method will not check if matcher is empty string
  public init(type: RuleType, matcher: String, policy: String) {
    self.type = type
    self.matcher = matcher
    self.policy = policy
  }

  public var type: RuleType
  public var matcher: String
  public var policy: String

}

public class RuleManager {

  public let forceDirect: String
  public let forceProxy: String
  public let forceReject: String

  public let selectProxy: String

  public let finalPolicy: String

  static let regularRules: [Rule] = """
    IP-CIDR,10.0.0.0/8,DIRECT
    IP-CIDR,100.64.0.0/10,DIRECT
    IP-CIDR,127.0.0.0/8,DIRECT
    IP-CIDR,17.0.0.0/8,DIRECT
    IP-CIDR,192.168.0.0/16,DIRECT
    IP-CIDR,172.16.0.0/12,DIRECT
    IP-CIDR,128.199.244.16/32,DIRECT
    IP-CIDR,123.125.117.0/22,REJECT,no-resolve
    IP-CIDR,61.160.200.252/32,REJECT,no-resolve
    GEOIP,CN,DIRECT
    """.components(separatedBy: "\n").compactMap{ Rule.parse($0) }

  private func readRules(_ filename: String) -> [Rule] {
    (try? String.init(contentsOfFile: filename).components(separatedBy: .newlines).compactMap{ Rule.parse($0) }) ?? []
  }

  public var selectPolicies: [String] {
    readRules(selectProxy).map{$0.policy}
  }

  public var allRules: [Rule] {
    readRules(forceProxy) + readRules(forceDirect) + readRules(selectProxy)
      + readRules(forceReject) + RuleManager.regularRules + [Rule.init(type: .final, matcher: "", policy: finalPolicy)]
  }

  public init(forceDirect: String, forceProxy: String, forceReject: String, selectProxy: String, finalPolicy: String) {
    self.forceDirect = forceDirect
    self.forceProxy = forceProxy
    self.forceReject = forceReject
    self.selectProxy = selectProxy
    self.finalPolicy = finalPolicy
  }

}
