public enum RuleType: String, CustomStringConvertible, CaseIterable, Codable {
  case domain = "DOMAIN"
  case domainSuffix = "DOMAIN-SUFFIX"
  case domainKeyword = "DOMAIN-KEYWORD"
  case ipCIDR = "IP-CIDR"
  case ipCIDR6 = "IP-CIDR6"
  case geoip = "GEOIP"
  case final = "FINAL"
  case userAgent = "USER-AGENT"
  case urlRegex = "URL-REGEX"
  case processName = "PROCESS-NAME"
  case destPort = "DEST-PORT"
  case srcIPCIDR = "SRC-IP-CIDR"
  case srcPort = "SRC-PORT"
//  case `protocol` = "PROTOCOL" // Surge only. The possible values are HTTP, HTTPS, TCP, UDP, DOH.

  public init?(rawValue: String) {
    let uppercased = rawValue.uppercased()
    for ruleType in Self.allCases {
      for client in ProxyClient.allCases {
        if uppercased == ruleType.string(for: client) {
          self = ruleType
          return
        }
      }
    }
    return nil
  }

  public var description: String { rawValue }

  public func supports(for client: ProxyClient) -> Bool {
    switch client {
    case .quantumult:
      return supportsQuantumultX
    case .clash :
      return supportsClash
    }
  }

  public var supportsQuantumultX: Bool {
    switch self {
    case .domain, .domainKeyword, .domainSuffix, .final,
         .ipCIDR, .ipCIDR6, .geoip,
         .userAgent:
      return true
    default:
      return false
    }
  }

  public var supportsClash: Bool {
    switch self {
    case .userAgent, .urlRegex:
      return false
    default:
      return true
    }
  }

  public func string(for client: ProxyClient) -> String {
    switch (client, self) {
    case (.clash, .final):
      return "MATCH"
    case (.clash, .destPort):
      return "DST-PORT"
    case (.quantumult, .domainSuffix):
      return "HOST-SUFFIX"
    case (.quantumult, .domainKeyword):
      return "HOST-KEYWORD"
    case (.quantumult, .domain):
      return "HOST"
    case (.quantumult, .ipCIDR6):
      return "IP6-CIDR"
    default:
      return rawValue
    }
  }

  public static let clashSupported = allCases.filter(\.supportsClash)

}
