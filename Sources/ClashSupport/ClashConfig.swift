import Foundation

public struct ClashConfig: Codable {
    
    public struct ProxyGroup: Codable {
        
        public var url: String?
        
        public var interval: Int?
        
        public var name: String
        
        public var type: ProxyGroupType
        
        public enum ProxyGroupType: String, Codable, CaseIterable {
            case urlTest = "url-test"
            case fallback
            case loadBalance = "load-balance"
            case select
        }
        
        public private(set) var proxies: [String]
        
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
                                   url: String, interval: Int) -> ClashConfig.ProxyGroup {
            return .init(url: url, interval: interval, name: name, type: .urlTest, proxies: proxies)
        }
        
        public static func fallback(name: String, proxies: [String],
                                        url: String, interval: Int) -> ClashConfig.ProxyGroup {
            return .init(url: url, interval: interval, name: name, type: .fallback, proxies: proxies)
        }
        
        public static func select(name: String, proxies: [String]) -> ClashConfig.ProxyGroup {
            return .init(url: nil, interval: nil, name: name, type: .select, proxies: proxies)
        }
        
    }
    
    public var proxyGroup: [ProxyGroup]
    
    public var experimental: Experimantal?
    
    public struct Experimantal: Codable {
        public let ignoreResolveFail: Bool
        private enum CodingKeys: String, CodingKey {
            case ignoreResolveFail = "ignore-resolve-fail"
        }
    }

    public var authentication: [Authentication]?
    
    public struct Authentication: Codable {
        public let username: String
        public let password: String

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
    
    public let dns: ClashDNS?
    
    public struct ClashDNS: Codable {
        public let enable: Bool
        public let ipv6: Bool
        public let listen: String?
        //        var enhancedMode
        public let nameserver: [String]
        public let fallback: [String]
        
        public init(enable: Bool, ipv6: Bool, listen: String?,
                    nameserver: [String], fallback: [String]) {
            self.enable = enable
            self.ipv6 = ipv6
            self.listen = listen
            self.nameserver = nameserver
            self.fallback = fallback
        }
    }
    
    public var logLevel: LogLevel
    
    public var rule: [String]
    
    public var allowLan: Bool
    
    public var externalController: String?
    
    public var mode: Mode
    
    public enum Mode: String, Codable, CaseIterable {
        case rule = "Rule"
        case global = "Global"
        case direct = "Direct"
    }
    
    public enum LogLevel: String, Codable, CaseIterable {
        case info
        case warning
        case error
        case debug
    }
    
    public var socksPort: Int
    
    public var httpPort: Int
    
    public var proxy: [ClashProxy]
    
    private enum CodingKeys: String, CodingKey {
        case proxyGroup = "Proxy Group"
        case mode
        case dns
        case rule = "Rule"
        case externalController = "external-controller"
        case allowLan = "allow-lan"
        case proxy = "Proxy"
        case socksPort = "socks-port"
        case httpPort = "port"
        case logLevel = "log-level"
    }
    
    public init(proxyGroup: [ProxyGroup] = [], logLevel: LogLevel = .info,
                rule: [String] = ["FINAL,,DIRECT"], allowLan: Bool = true,
                externalController: String? = "127.0.0.1:9090",
                mode: Mode = .rule, socksPort: Int = 7891, httpPort: Int = 7890,
                proxy: [ClashProxy], dns: ClashDNS?) {
        self.proxyGroup = proxyGroup
        self.logLevel = logLevel
        self.rule = rule
        self.allowLan = allowLan
        self.externalController = externalController
        self.mode = mode
        self.socksPort = socksPort
        self.httpPort = httpPort
        self.proxy = proxy + [.socks5(.socks5(name: "UseLocal", server: "localhost", port: 1080))]
        self.dns = dns
    }
    
}
