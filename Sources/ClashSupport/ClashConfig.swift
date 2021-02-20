import Foundation

public struct ClashConfig: Codable {

  public var proxyGroups: [ProxyGroup]?

  public var experimental: ExperimantalFeature?

  public var authentication: [Authentication]?

  /// optional in fact
  public var dns: ClashDNS?

  public var tun: ClashTun?

  public var hosts: [String: String]?

  public var logLevel: LogLevel?

  public var rules: [String]?

  public var allowLan: Bool?

  public var externalController: String?
  public var secret: String?

  public var mode: Mode

  public var socksPort: Int?
  public var httpPort: Int?
  public var redirPort: Int?

  public var proxies: [ClashProxy]?

  public var proxyProviders: [String: ProxyProvider]?
  public var profile: Profile? = .init()

  private enum CodingKeys: String, CodingKey {
    case proxyGroups = "proxy-groups"
    case mode
    case dns
    case tun
    case hosts
    case rules
    case externalController = "external-controller"
    case allowLan = "allow-lan"
    case proxies
    case socksPort = "socks-port"
    case httpPort = "port"
    case redirPort = "redir-port"
    case logLevel = "log-level"
    case proxyProviders = "proxy-providers"
  }

  public init(
    mode: Mode = .rule,
    socksPort: Int = 7891, httpPort: Int = 7890,
    proxies: [ClashProxy], dns: ClashDNS) {
    self.mode = mode
    self.socksPort = socksPort
    self.httpPort = httpPort
    self.proxies = proxies
    self.dns = dns
  }
  public init(mode: Mode) {
    self.mode = mode
  }

}

extension ClashConfig {

  public static let directPolicy = "DIRECT"

  public static let rejectPolicy = "REJECT"

  public struct ProxyGroup: Codable, Equatable {

    public var url: String?

    public var interval: Int?

    public var name: String

    public let type: ProxyGroupType

    public enum ProxyGroupType: String, Codable, CaseIterable {
      case select
      case urlTest = "url-test"
      case fallback
      case loadBalance = "load-balance"
      //          case relay
    }

    public var proxies: [String]

    private enum CodingKeys: String, CodingKey {
      case name
      case url
      case proxies
      case type
      case interval
    }

    private init(url: String?, interval: Int?, name: String,
                 type: ProxyGroupType, proxies: [String]) {
      self.url = url
      self.interval = interval
      self.name = name
      self.type = type
      self.proxies = proxies
    }

    public static func urlTest(name: String, proxies: [String],
                               url: String, interval: Int) -> Self {
      .init(url: url, interval: interval, name: name, type: .urlTest, proxies: proxies)
    }

    public static func fallback(name: String, proxies: [String],
                                url: String, interval: Int) -> Self {
      .init(url: url, interval: interval, name: name, type: .fallback, proxies: proxies)
    }

    public static func select(name: String, proxies: [String]) -> Self {
      .init(url: nil, interval: nil, name: name, type: .select, proxies: proxies)
    }

    public static func loadBalance(name: String, proxies: [String],
                                   url: String, interval: Int) -> Self {
      .init(url: url, interval: interval, name: name, type: .loadBalance, proxies: proxies)
    }

  }

  public struct ExperimantalFeature: Codable, Equatable {

    public var ignoreResolveFail: Bool?

    public var interfaceName: String?

    public init(ignoreResolveFail: Bool? = nil, interfaceName: String? = nil) {
      self.ignoreResolveFail = ignoreResolveFail
      self.interfaceName = interfaceName
    }

    private enum CodingKeys: String, CodingKey {
      case ignoreResolveFail = "ignore-resolve-fail"
      case interfaceName = "interface-name"
    }
  }

  public struct Authentication: Codable, Equatable {

    public var username: String

    public var password: String

    public init(username: String, password: String) {
      self.username = username
      self.password = password
    }

    public init(from decoder: Decoder) throws {
      let c = try decoder.singleValueContainer()
      let str = try c.decode(String.self)
      if let sep = str.firstIndex(of: ":") {
        username = String(str[..<sep])
        password = String(str[str.index(after: sep)...])
      } else {
        username = str
        password = ""
      }
    }

    public func encode(to encoder: Encoder) throws {
      try "\(username):\(password)".encode(to: encoder)
    }
  }

  public struct ClashDNS: Codable, Equatable {

    /// set true to enable dns
    public var enable: Bool?
    public var ipv6: Bool?
    public var listen: String?
    public var enhancedMode: EnhanceMode?
    public var fakeIpRange: String?
    public var nameserver: [String]?
    public var fallback: [String]?
    public var fallbackFilter: FallbackFilter?

    private enum CodingKeys: String, CodingKey {
      case enable, ipv6, listen, nameserver, fallback
      case enhancedMode = "enhanced-mode"
      case fallbackFilter = "fallback-filter"
      case fakeIpRange = "fake-ip-range"
    }

    public enum EnhanceMode: String, Codable {
      case redirHost = "redir-host"
      case fakeIp = "fake-ip"
    }

    public struct FallbackFilter: Codable, Equatable {

      public var geoip: Bool

      /// ips in these subnets will be considered polluted
      public var ipcidr: [String]

      public init(geoip: Bool = true, ipcidr: [String]) {
        self.geoip = geoip
        self.ipcidr = ipcidr
      }
    }

    public init(enable: Bool, ipv6: Bool = false, listen: String? = nil,
                nameserver: [String], fallback: [String],
                fallbackFilter: FallbackFilter? = nil) {
      self.enable = enable
      self.ipv6 = ipv6
      self.listen = listen
      self.nameserver = nameserver
      self.fallback = fallback
      self.fallbackFilter = fallbackFilter
    }
  }

  public struct ClashTun: Codable, Equatable {
    public let enable: Bool
    public var stack: TunStack?
    public var dnsHijack: [String]?
    public var macOSAutoRoute: Bool?

    private enum CodingKeys: String, CodingKey {
      case enable, stack
      case dnsHijack = "dns-hijack"
      case macOSAutoRoute = "macOS-auto-route"
    }

    public enum TunStack: String, Codable {
      case system
      case gvisor
    }
  }

  public struct ProxyProvider: Codable {
    public enum ProviderType: String, Codable {
      case http
      case file
    }

    public var healthCheck: HealthCheck

    public var path: String

    public var url: String?

    public var interval: Int?

    public struct HealthCheck: Codable {
      public var enable: Bool
      public var interval: Int
      public var url: String
    }
  }

  public enum Mode: String, Codable, CaseIterable, Equatable {
    case rule
    case global
    case direct
//    case script
  }

  public enum LogLevel: String, Codable, CaseIterable, Equatable {
    case info
    case warning
    case error
    case debug
    case silent
  }

  public struct Profile: Codable {
    public var storeSelected: Bool = false

    private enum CodingKeys: String, CodingKey {
      case storeSelected = "store-selected"
    }
  }
}
