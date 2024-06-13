import TwoCase

public struct ClashConfig: Codable, Equatable {

  public var httpPort: Int?
  public var socksPort: Int?
  public var redirPort: Int?
  public var tproxyPort: Int?
  public var mixedPort: Int?
  public var inbounds: Inbounds?

  public var authentication: [Authentication]?

  public var allowLan: Bool?
  /// This is only applicable when  allowLan is true, set to "*" to bind all IP addresses
  public var bindAddress: String?

  public var mode: Mode
  public var logLevel: LogLevel?
  public var ipv6: Bool?
  public var externalController: String?
  public var externalUI: String?
  public var secret: String?

  public var interfaceName: String?
  public var routingMark: Int?

  public var hosts: [String: String]?

  public var profile: Profile? = .init()

  public var dns: ClashDNS?

  public var proxies: [ClashProxy]?

  public var proxyGroups: [ProxyGroup]?

  public var proxyProviders: [String: ProxyProvider]?

  public var rules: [String]?

  // MARK: Premium Features

  public var tun: ClashTun?

  public var script: Script?

  public var ruleProviders: [String: RuleProvider]?

  private enum CodingKeys: String, CodingKey {
    case httpPort = "port"
    case socksPort = "socks-port"
    case redirPort = "redir-port"
    case tproxyPort = "tproxy-port"
    case mixedPort = "mixed-port"
    case authentication
    case allowLan = "allow-lan"
    case bindAddress = "bind-address"
    case mode
    case logLevel = "log-level"
    case ipv6
    case externalController = "external-controller"
    case externalUI = "external-ui"
    case secret
    case interfaceName = "interface-name"
    case hosts
    case profile
    case dns
    case proxies
    case proxyGroups = "proxy-groups"
    case proxyProviders = "proxy-providers"
    case rules
    case tun
    case routingMark = "routing-mark"
    case script
    case ruleProviders = "rule-providers"
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
    public var name: String
    public let type: ProxyGroupType
    public var proxies: [String]

    public var tolerance: Int?
    public var lazy: Bool?
    public var url: String?
    public var interval: Int?
    public var strategy: Strategy?
    public var disableUDP: Bool?
    public var interfaceName: String?

    public var providers: [String]?

    public enum ProxyGroupType: String, Codable, CaseIterable, Identifiable {
      case select
      case urlTest = "url-test"
      case fallback
      case loadBalance = "load-balance"
      case relay
      case tolerance, lazy

      public var id: Self { self }
    }

    public enum Strategy: String, Codable, CaseIterable {
      case consistentHashing = "consistent-hashing"
      case roundRobin = "round-robin"
    }

    private enum CodingKeys: String, CodingKey {
      case name, type, proxies, tolerance
      case lazy, url, interval, strategy
      case disableUDP = "disable-udp"
      case interfaceName = "interface-name"
      case providers = "use"
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

  public struct Authentication: Codable, Equatable {

    public var username: String

    public var password: String

    public init(username: String, password: String) {
      self.username = username
      self.password = password
    }

    public init(from decoder: Decoder) throws {
      let str = try decoder.singleValueContainer().decode(String.self)
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
    public var listen: String?
    public var ipv6: Bool?
    public var enhancedMode: EnhanceMode?
    public var fakeIpRange: String?
    public var useHosts: Bool?
    public var defaultNameserver: [String]?
    public var nameserver: [String]?
    public var fallback: [String]?
    public var fakeIpFilter: [String]?
    public var fallbackFilter: FallbackFilter?
    public var nameserverPolicy: [String : String]?

    private enum CodingKeys: String, CodingKey {
      case enable, ipv6, listen, nameserver, fallback
      case enhancedMode = "enhanced-mode"
      case fallbackFilter = "fallback-filter"
      case fakeIpRange = "fake-ip-range"
      case fakeIpFilter = "fake-ip-filter"
      case defaultNameserver = "default-nameserver"
      case nameserverPolicy = "nameserver-policy"
      case useHosts = "use-hosts"
    }

    public enum EnhanceMode: String, Codable {
      case redirHost = "redir-host"
      case fakeIp = "fake-ip"
    }

    public struct FallbackFilter: Codable, Equatable {

      public var geoip: Bool
      public var geoipCode: String

      /// ips in these subnets will be considered polluted
      public var ipcidr: [String]
      public var domain: [String]
      private enum CodingKeys: String, CodingKey {
        case geoip, ipcidr, domain
        case geoipCode = "geoip-code"
      }
    }

    public init(enable: Bool, ipv6: Bool = false, listen: String? = nil,
                nameserver: [String]? = nil, fallback: [String]? = nil,
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
    public var macOSAutoDetectInterface: Bool?

    private enum CodingKeys: String, CodingKey {
      case enable, stack
      case dnsHijack = "dns-hijack"
      case macOSAutoRoute = "macOS-auto-route"
      case macOSAutoDetectInterface = "macOS-auto-detect-interface"
    }

    public enum TunStack: String, Codable {
      case system
      case gvisor
    }
  }

  public struct Script: Codable, Equatable {
    public var code: String?
    public var shortcuts: [String: String]?
  }

  public struct ProxyProvider: Codable, Equatable {
    public enum ProviderType: String, Codable, Equatable {
      case http
      case file
    }

    public var type: ProviderType
    public var url: String?
    public var path: String
    public var interval: Int?
    public var healthCheck: HealthCheck

    public struct HealthCheck: Codable, Equatable {
      public var enable: Bool
      public var interval: Int
      public var lazy: Bool?
      public var url: String
    }

    private enum CodingKeys: String, CodingKey {
      case type, url, interval, path
      case healthCheck = "health-check"
    }
  }

  public struct RuleProvider: Codable, Equatable {
    public enum Behavior: String, Codable, Equatable, CaseIterable {
      case domain
      case ipcidr
      case classical
    }
    public enum ProviderType: String, Codable, Equatable, CaseIterable {
      case http
      case file
    }

    public var behavior: Behavior
    public var type: ProviderType
    public var url: String?
    public var interval: Int?
    public var path: String

  }

  public enum Mode: String, Codable, CaseIterable, Equatable {
    case rule
    case global
    case direct
    /// premium only
    case script = "Script"
  }

  public enum LogLevel: String, Codable, CaseIterable, Equatable {
    case info
    case warning
    case error
    case debug
    case silent
  }

  public struct Profile: Codable, Equatable {
    public init(storeSelected: Bool = false, storeFakeIP: Bool = false) {
      self.storeSelected = storeSelected
      self.storeFakeIP = storeFakeIP
    }

    public var storeSelected: Bool
    public var storeFakeIP: Bool
    public var tracing: Bool?

    private enum CodingKeys: String, CodingKey {
      case storeSelected = "store-selected"
      case storeFakeIP = "store-fake-ip"
      case tracing
    }
  }

  public typealias Inbounds = [TwoCase<Inbound, String>]

  public struct Inbound: Codable, Equatable {
    public init(type: InboundType, bindAddress: String) {
      self.type = type
      self.bindAddress = bindAddress
    }

    public var type: InboundType
    public var bindAddress: String

    private enum CodingKeys: String, CodingKey {
      case type
      case bindAddress = "bind-address"
    }

    public enum InboundType: String, Codable, CaseIterable, Equatable {
      case socks
      case redir
      case tproxy
      case http
      case mixed
    }
  }
}
