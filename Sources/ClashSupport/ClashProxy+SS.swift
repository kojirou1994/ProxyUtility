import ShadowsocksProtocol

extension ShadowsocksPlugin {
  var toClash: ClashProxy.Shadowsocks.PluginOptions {
    switch self {
    case .obfs(let obfs):
      return .obfs(.init(mode: obfs.mode, host: obfs.obfsHost))
    case .v2ray(let v):
      return .v2ray(.init(mode: v.mode, tls: v.tls, skipCertVerify: nil, host: v.host, path: v.path, mux: v.mux, headers: nil))
    }
  }
}

public protocol ClashUDPFeature {
  var udp: Bool? { get }
}
public protocol ClashTLSFeature {
  var tls: Bool? { get }
}
public protocol ClashVerifyCertFeature {
  var skipCertVerify: Bool? { get }
}
extension ClashUDPFeature {
  public var isUDPEnabled: Bool {
    udp ?? false
  }
}

extension ClashTLSFeature {
  public var isTLSEnabled: Bool {
    tls ?? false
  }
}

extension ClashVerifyCertFeature {
  public var isCertVerificationEnabled: Bool {
    !(skipCertVerify ?? false)
  }
}

extension ClashProxy {
  public struct Shadowsocks: Codable, Equatable, ClashUDPFeature {
    public init(cipher: ShadowsocksEnryptMethod, plugin: ClashProxy.Shadowsocks.PluginOptions? = nil, password: String, server: String, port: Int, name: String, udp: Bool? = nil) {
      self.cipher = cipher
      self.plugin = plugin
      self.password = password
      self.server = server
      self.port = port
      self.name = name
      self.udp = udp
    }

    public init(_ shadowsocks: ShadowsocksConfig) {
      self.cipher = shadowsocks.method
      self.password = shadowsocks.password
      self.server = shadowsocks.server
      self.port = shadowsocks.serverPort
      self.name = shadowsocks.id
      self.plugin = shadowsocks.plugin?.toClash
      self.udp = shadowsocks.mode != .tcp
    }

//    public var shadowsocks: ShadowsocksConfig {
//      .local(id: name, server: server, serverPort: port, password: password, method: cipher, mode: isUDPEnabled ? .both : .tcp, plugin: plugin)
//    }

    public var cipher: ShadowsocksEnryptMethod

    public var plugin: PluginOptions?

    public var password: String

    public var server: String

    public var port: Int

    public let type: ProxyType = .ss

    public var name: String

    public var udp: Bool?

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
          let obfs = try container.decode(PluginOptions.Obfs.self, forKey: .pluginOpts)
          self.plugin = .obfs(obfs)
        case "v2ray-plugin":
          let v2 = try container.decode(PluginOptions.V2ray.self, forKey: .pluginOpts)
          self.plugin = .v2ray(v2)
        default:
          fatalError("Unknown plugin: \(plugin)")
        }
      } else {
        self.plugin = nil
      }
      udp = try container.decodeIfPresent(Bool.self, forKey: .udp)
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
      try container.encodeIfPresent(udp, forKey: .udp)
    }
  }
}

public typealias ObfsMode = Obfs.Mode
public typealias V2rayMode = V2ray.Mode

extension ClashProxy.Shadowsocks {
  public enum PluginOptions: Codable, Equatable {
    case obfs(Obfs)

    case v2ray(V2ray)

    public struct Obfs: Codable, Equatable {
      public var mode: ObfsMode
      public var host: String?
    }

    public struct V2ray: Codable, Equatable {
      public init(mode: V2rayMode, tls: Bool? = nil, skipCertVerify: Bool? = nil, host: String? = nil, path: String? = nil, mux: Bool? = nil, headers: [String : String]? = nil) {
        self.mode = mode
        self.tls = tls
        self.skipCertVerify = skipCertVerify
        self.host = host
        self.path = path
        self.mux = mux
        self.headers = headers
      }

      public var mode: V2rayMode {
        willSet {
          precondition(newValue != .quic, "no QUIC now")
        }
      }
      public var tls: Bool?
      public var skipCertVerify: Bool?
      public var host: String?
      public var path: String?
      public var mux: Bool?
      public var headers: [String: String]?

      private enum CodingKeys: String, CodingKey {
        case mode, tls, host, path, mux, headers
        case skipCertVerify = "skip-cert-verify"
      }
    }
  }
}
