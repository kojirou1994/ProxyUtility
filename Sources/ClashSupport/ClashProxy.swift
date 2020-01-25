import Foundation
import ProxyUtility
import V2RayProtocol
import ShadowsocksProtocol

public enum ClashProxy: Codable, Equatable {
    
    case shadowsocks(Shadowsocks)
    case socks5(Socks5)
    case http(HTTP)
    case vmess(ClashVMess)
    
    public enum ProxyType: String, Codable, CaseIterable, Equatable {
        case ss
        case vmess
        case socks5
        case http
    }
    
    public init?(_ proxy: ProxyConfig) {
        switch proxy {
        case .socks5(let v):
            #warning("auth not added")
            self = .socks5(.socks5(name: v.id, server: v.server, port: v.port))
        case .ss(let v):
            self = .shadowsocks(.init(v))
        case .vmess(let v):
            self = .vmess(.init(v))
        default:
            return nil
        }
    }
    
    public init(from decoder: Decoder) throws {
        
        enum TempKey: CodingKey {
            case type
        }
        
        let container = try decoder.container(keyedBy: TempKey.self)
        let type = try container.decode(ProxyType.self, forKey: .type)
        switch type {
        case .ss:
            self = .shadowsocks(try .init(from: decoder))
        case .socks5 :
            self = .socks5(try .init(from: decoder))
        case .http:
            self = .http(try .init(from: decoder))
        case .vmess:
            self = .vmess(try .init(from: decoder))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .shadowsocks(let s):
            var c = encoder.singleValueContainer()
            try c.encode(s)
        case .socks5(let s):
            var c = encoder.singleValueContainer()
            try c.encode(s)
        case .http(let h):
            var c = encoder.singleValueContainer()
            try c.encode(h)
        case .vmess(let v):
            var c = encoder.singleValueContainer()
            try c.encode(v)
        }
    }
    
    public var server: String {
        switch self {
        case .shadowsocks(let s):
            return s.server
        case .socks5(let s):
            return s.server
        case .http(let h):
            return h.server
        case .vmess(let v):
            return v.server
        }
    }
    
    public var name: String {
        set {
            switch self {
            case .shadowsocks(var s):
                s.name = newValue
                self = .shadowsocks(s)
            case .socks5(var s):
                s.name = newValue
                self = .socks5(s)
            case .http(var h):
                h.name = newValue
                self = .http(h)
            case .vmess(var v):
                v.name = newValue
                self = .vmess(v)
            }
        }
        get {
            switch self {
            case .shadowsocks(let s):
                return s.name
            case .socks5(let s):
                return s.name
            case .http(let h):
                return h.name
            case .vmess(let v):
                return v.name
            }
        }
    }

    public var port: Int {
        switch self {
        case .shadowsocks(let s):
            return s.port
        case .socks5(let s):
            return s.port
        case .http(let h):
            return h.port
        case .vmess(let v):
            return v.port
        }
    }

    public var type: ProxyType {
        switch self {
        case .shadowsocks(_):
            return .ss
        case .socks5(_):
            return .socks5
        case .http(_):
            return .http
        case .vmess(_):
            return .vmess
        }
    }
    
    public struct ClashVMess: Codable, Equatable {
        public var name: String
        public let type: ProxyType = .vmess
        public var server: String
        public var port: Int
        public var uuid: String
        public var alterId: Int
        public var cipher: VMessCipher
        public var udp: Bool?
        public var tls: Bool?
        public var skipCertVerify: Bool?
        public var network: String?
        public var wsPath: String?
        public var wsHeaders: [String: String]?

        public init(_ vmess: VMess) {
            name = vmess._value.ps
            server = vmess._value.add
            port = vmess._value.port.value
            uuid = vmess._value.id
            alterId = vmess._value.aid.value
            cipher = .auto
            udp = true
            tls = vmess._value.tls == "tls"
//            skipCertVerify = false
            if vmess._value.net == "ws" {
                network = vmess._value.net
            }
            if !vmess._value.path.isEmpty {
                wsPath = vmess._value.path
            }
        }

        private enum CodingKeys: String, CodingKey {
            case name, type, server, port, uuid, alterId, cipher, udp, tls
            case network
            case skipCertVerify = "skip-cert-verify"
            case wsPath = "ws-path"
            case wsHeaders = "ws-headers"
        }

    }
    
    public enum VMessCipher: String, Codable, CaseIterable, Equatable {
        case auto
        case none
    }
    
    public struct Shadowsocks: Codable, LosslessShadowsocksConvertible, Equatable {
        
        public init(_ shadowsocks: ShadowsocksConfig) {
            self.cipher = shadowsocks.method
            self.password = shadowsocks.password
            self.server = shadowsocks.server
            self.port = shadowsocks.serverPort
            self.name = shadowsocks.id
            self.plugin = shadowsocks.plugin
            #warning("udp feature")
            self.udp = true
        }
        
        public var shadowsocks: ShadowsocksConfig {
            return ShadowsocksConfig.local(id: name, server: server, serverPort: port, password: password, method: cipher, plugin: plugin)
        }
        
        public var cipher: ShadowsocksEnryptMethod
        
        public var plugin: ShadowsocksPlugin?

        public var password: String
        
        public var server: String
        
        public var port: Int
        
        public let type: ProxyType = .ss
        
        public var name: String
        
        public var udp: Bool
        
        private enum CodingKeys: String, CodingKey {
            case password
            case type
            case name
            case cipher
            case server
            case port
            case plugin
            case pluginOpts = "plugin-opts"
            case udp
        }
        
//        public init(cipher: ShadowsocksCipher, obfs: ObfsLocalArgument?, password: String, server: String, port: Int, name: String) {
//            self.cipher = cipher
//            if let obfs = obfs {
//                self.obfsHost = obfs.obfsHost
//                self.obfs = obfs.obfs
//            }
//            self.password = password
//            self.server = server
//            self.port = port
//            self.name = name
//        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            password = try container.decode(String.self, forKey: .password)
            name = try container.decode(String.self, forKey: .name)
            cipher = try container.decode(ShadowsocksEnryptMethod.self, forKey: .cipher)
            server = try container.decode(String.self, forKey: .server)
            port = try container.decode(Int.self, forKey: .port)
            if let plugin = try container.decodeIfPresent(String.self, forKey: .plugin) {
                switch plugin {
                case "obfs":
                    let obfs = try container.decode(Obfs.self, forKey: .pluginOpts)
                    self.plugin = .obfs(obfs)
                case "v2ray-plugin":
                    let v2 = try container.decode(V2ray.self, forKey: .pluginOpts)
                    self.plugin = .v2ray(v2)
                default:
                    fatalError("Unknown plugin: \(plugin)")
                }
            } else {
                self.plugin = nil
            }
            udp = try container.decode(Bool.self, forKey: .udp)
        }
        
        private var clashPlugin: String {
            switch plugin.unsafelyUnwrapped {
            case .obfs:
                return "obfs"
            case .v2ray:
                return "v2ray-plugin"
            }
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(password, forKey: .password)
            try container.encode(type, forKey: .type)
            try container.encode(name, forKey: .name)
            try container.encode(cipher, forKey: .cipher)
            try container.encode(server, forKey: .server)
            try container.encode(port, forKey: .port)
            if let plugin = plugin {
                try container.encode(clashPlugin, forKey: .plugin)
                switch plugin {
                case .obfs(let v):
                    try container.encode(v, forKey: .pluginOpts)
                case .v2ray(let v):
                    try container.encode(v, forKey: .pluginOpts)
                }
            }
            try container.encode(udp, forKey: .udp)
        }
    }

    public struct Socks5: Codable, Equatable {
        public var name: String
        public let type: ProxyType = .socks5
        public var server: String
        public var port: Int
        public var tls: Bool
        public var username: String?
        public var password: String?
        public var skipCertVerify: Bool
        
        public static func socks5(name: String, server: String, port: Int) -> Socks5 {
            return .init(name: name, server: server, port: port, tls: false, username: nil, password: nil, skipCertVerify: false)
        }
        
        private init(name: String, server: String, port: Int,
                     tls: Bool, username: String?, password: String?,
                     skipCertVerify: Bool) {
            self.name = name
            self.server = server
            self.port = port
            self.tls = tls
            self.username = username
            self.password = password
            self.skipCertVerify = skipCertVerify
        }
        
        private enum CodingKeys: String, CodingKey {
            case name, type, server, port, tls, username, password
            case skipCertVerify = "skip-cert-verify"
        }
    }
    
    public struct HTTP: Codable, Equatable {
        public var name: String
        public let type: ProxyType = .http
        public var server: String
        public var port: Int
        public var tls: Bool
        public var username: String?
        public var password: String?
        public var skipCertVerify: Bool
        
        public init(name: String, server: String, port: Int, tls: Bool, username: String?, password: String?, skipCertVerify: Bool) {
            self.name = name
            self.server = server
            self.port = port
            self.tls = tls
            self.username = username
            self.password = password
            self.skipCertVerify = skipCertVerify
        }
        
        private enum CodingKeys: String, CodingKey {
            case name, type, server, port, tls, username, password
            case skipCertVerify = "skip-cert-verify"
        }
    }
    
}

