import ShadowsocksProtocol

extension ClashProxy {
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
            ShadowsocksConfig.local(id: name, server: server, serverPort: port, password: password, method: cipher, plugin: plugin)
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
}
