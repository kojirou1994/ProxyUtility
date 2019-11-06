import Foundation
import ProxyProtocol

internal struct SharedEncoders {
    
    internal static let jsonEncoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = .prettyPrinted
        return e
    }()
    
}

public protocol ShadowsocksProtocol: ComplexProxyProtocol {
    
}

public protocol LosslessShadowsocksConvertible {
    init(_ shadowsocks: ShadowsocksConfig)
    
    var shadowsocks: ShadowsocksConfig { get }
}

public struct ShadowsocksConfig: ShadowsocksProtocol, Equatable, Encodable {
    public var localType: LocalType { return .socks5 }
    
    public func localArguments(configPath: String) -> [String] {
        return ["-c", configPath, "-u"]
    }
    

    public var id: String
    public let server: String
    public let serverPort: Int
    public var localAddress: String?
    public var localPort: Int
    public let password: String
    public let timeout: Int
    public let method: ShadowsocksEnryptMethod
    public let plugin: ShadowsocksPlugin?
    
    struct Experimantal {
        var fast_open: Bool
        var reuse_port: Bool
        var no_delay: Bool
        enum Mode: String, Codable, CaseIterable {
            case udp = "udp_only"
            case tcp = "tcp_only"
            case both = "tcp_and_udp"
            var argument: String? {
                switch self {
                case .both: return "-u"
                case .tcp: return nil
                case .udp: return "-U"
                }
            }
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case server
        case serverPort = "server_port"
        case localAddress = "local_address"
        case localPort = "local_port"
        case password, timeout, method, plugin
        case pluginOpts = "plugin_opts"
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(server, forKey: .server)
        try container.encode(serverPort, forKey: .serverPort)
        try container.encode(localAddress, forKey: .localAddress)
        try container.encode(localPort, forKey: .localPort)
        try container.encode(password, forKey: .password)
        try container.encode(timeout, forKey: .timeout)
        try container.encode(method, forKey: .method)
        if let plugin = plugin {
            try container.encode(plugin.plugin, forKey: .plugin)
            try container.encode(plugin.pluginOpts, forKey: .pluginOpts)
        }
    }

    public static func server(id: String, server: String, serverPort: Int, password: String,
                              timeout: Int = 3600, method: ShadowsocksEnryptMethod,
                              plugin: ShadowsocksPlugin? = nil) -> ShadowsocksConfig {
        return .init(id: id, server: server, serverPort: serverPort, localAddress: nil,
                     localPort: 0, password: password, timeout: timeout, method: method, plugin: plugin)
    }
    
    public static func local(id: String, server: String, serverPort: Int, localAddress: String = "127.0.0.1",
                             localPort: Int = 1080, password: String, method: ShadowsocksEnryptMethod,
                             plugin: ShadowsocksPlugin? = nil) -> ShadowsocksConfig {
        return .init(id: id, server: server, serverPort: serverPort, localAddress: localAddress,
                     localPort: localPort, password: password, timeout: 3600, method: method, plugin: plugin)
    }
    
    private init(id: String, server: String, serverPort: Int, localAddress: String? = nil, localPort: Int = 1080, password: String, timeout: Int = 600, method: ShadowsocksEnryptMethod, plugin: ShadowsocksPlugin?) {
        self.id = id.isEmpty ? server : id
        self.server = server
        self.serverPort = serverPort
        self.localAddress = localAddress
        self.localPort = localPort
        self.password = password
        self.timeout = timeout
        self.method = method
        self.plugin = plugin
    }
    
    public var uri: String {
        let userinfo = (method.rawValue + ":" + password).base64URLEncoded
        var pluginPart: String
        if let plugin = plugin {
//            if plugin.hasPrefix("/usr/local/bin/") {
//                plugin = plugin.replacingOccurrences(of: "/usr/local/bin/", with: "")
//            }
            pluginPart = "/?plugin="
            let plugin_param = "\(plugin.plugin);\(plugin.pluginOpts)"
            pluginPart = pluginPart + plugin_param.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: ":;=\\").inverted)!
        } else {
            pluginPart = String()
        }
        return "ss://\(userinfo)@\(server):\(serverPort)\(pluginPart)#\(id.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? id)"
    }
    
    public var jsonConfig: Data {
        return try! SharedEncoders.jsonEncoder.encode(self)
    }
    
    public static let localExecutable = "ss-local"
}


public struct ShadowsocksRConfig: ShadowsocksProtocol, Codable, Equatable {
    public var localType: LocalType { return .socks5 }
    public func localArguments(configPath: String) -> [String] {
        return ["-c", configPath, "-u"]
    }
    
    public let server: String
    public let serverPort: Int
    public var localAddress: String?
    public var localPort: Int
    public let password: String
    public let timeout: Int
    public let method: ShadowsocksEnryptMethod
    public let `protocol`: String
    public let protoParam: String?
    public let obfs: String
    public let obfsParam: String?

    public var id: String

    public let group: String?

    public init(id: String, group: String? = nil, server: String, server_port: Int, local_address: String? = nil, local_port: Int = 1080, password: String, timeout: Int = 600, method: ShadowsocksEnryptMethod, protocol: String, proto_param: String? = nil, obfs: String, obfs_param: String? = nil) {
        self.id = id.isEmpty ? server : id
        self.group = group
        self.server = server
        self.serverPort = server_port
        self.localAddress = local_address
        self.localPort = local_port
        self.password = password
        self.timeout = timeout
        self.method = method
        self.protocol = `protocol`
        self.protoParam = proto_param
        self.obfs = obfs
        self.obfsParam = obfs_param
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case group
        case server
        case serverPort = "server_port"
        case localAddress = "local_address"
        case localPort = "local_port"
        case password, timeout, method
        case `protocol` = "protocol"
        case obfs
        case protoParam = "protocol_param"
        case obfsParam = "obfs_param"
    }

    public var uri: String {
        // save static uri
        var params = "?"
        if obfsParam != nil {
            params += "obfsparam=\(obfsParam!.base64URLEncoded)&"
        }
        if protoParam != nil {
            params += "protoparam=\(protoParam!.base64URLEncoded)&"
        }
        params += "remarks=\(id.base64URLEncoded)&"
        if group != nil {
            params += "group=\(group!.base64URLEncoded)&"
        }
        
        return "ssr://\("\(server):\(serverPort):\(`protocol`):\(method):\(obfs):\(password.base64URLEncoded)/\(params.dropLast())".base64URLEncoded)"
    }

    public static let localExecutable = "ssr-local"

    public var jsonConfig: Data {
        return try! SharedEncoders.jsonEncoder.encode(self)
    }
}
