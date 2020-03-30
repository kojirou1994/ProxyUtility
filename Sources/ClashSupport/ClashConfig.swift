import Foundation

public struct ClashConfig: Codable {

    public var proxyGroups: [ProxyGroup]
    
    public var experimental: ExperimantalFeature?

    public var authentication: [Authentication]?

    /// optional in fact
    public var dns: ClashDNS
    
    public var logLevel: LogLevel
    
    public var rules: [String]
    
    public var allowLan: Bool
    
    public var externalController: String?
    
    public var mode: Mode
    
    public var socksPort: Int
    
    public var httpPort: Int
    
    public var proxies: [ClashProxy]

    public var proxyProviders: [String: ProxyProvider] = .init()
    
    private enum CodingKeys: String, CodingKey {
        case proxyGroups = "proxy-groups"
        case mode
        case dns
        case rules
        case externalController = "external-controller"
        case allowLan = "allow-lan"
        case proxies
        case socksPort = "socks-port"
        case httpPort = "port"
        case logLevel = "log-level"
        case proxyProviders = "proxy-providers"
    }
    
    public init(proxyGroups: [ProxyGroup], logLevel: LogLevel,
                rules: [String], allowLan: Bool,
                externalController: String? = "127.0.0.1:9090",
                mode: Mode = .rule,
                socksPort: Int = 7891, httpPort: Int = 7890,
                proxies: [ClashProxy], dns: ClashDNS) {
        self.proxyGroups = proxyGroups
        self.logLevel = logLevel
        self.rules = rules
        self.allowLan = allowLan
        self.externalController = externalController
        self.mode = mode
        self.socksPort = socksPort
        self.httpPort = httpPort
        self.proxies = proxies// + [.socks5(.socks5(name: "UseLocal", server: "localhost", port: 1080))]
        self.dns = dns
    }
    
}

extension ClashConfig {

    public struct ProxyGroup: Codable, Equatable {

        public var url: String?

        public var interval: Int?

        public var name: String

        public let type: ProxyGroupType

        public enum ProxyGroupType: String, Codable, CaseIterable {
            case urlTest = "url-test"
            case fallback
            case loadBalance = "load-balance"
            case select
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

        public static func loadBalance(name: String, proxies: [String]) -> Self {
            .init(url: nil, interval: nil, name: name, type: .loadBalance, proxies: proxies)
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
        public var enable: Bool

        public var ipv6: Bool

        public var listen: String?

        public var nameserver: [String]

        public var fallback: [String]

        public var fallbackFilter: FallbackFilter?

        private enum CodingKeys: String, CodingKey {
            case enable, ipv6, listen, nameserver, fallback
            case fallbackFilter = "fallback-filter"
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
        case rule = "Rule"
        case global = "Global"
        case direct = "Direct"
    }

    public enum LogLevel: String, Codable, CaseIterable, Equatable {
        case info
        case warning
        case error
        case debug
        case silent
    }
}


