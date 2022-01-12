import ProxyUtility
import V2RayProtocol

extension ClashProxy {
  public struct VMess: Codable, Equatable, ClashUDPFeature, ClashTLSFeature {

    public var name: String
    public let type: ProxyType = .vmess
    public var server: String
    public var port: Int
    public var uuid: String
    public var alterId: Int
    public var cipher: Cipher
    public var udp: Bool?
    public var tls: Bool?
    public var skipCertVerify: Bool?
    public var servername: String?
    public var network: Network?

    public var wsOptions: WsOptions? {
      willSet {
        assert(network == .ws)
      }
    }

    public var h2Options: H2Options? {
      willSet {
        assert(network == .h2)
      }
    }

    public var httpOptions: HttpOptions? {
      willSet {
        assert(network == .http)
      }
    }

    public var grpcOptions: GrpcOptions? {
      willSet {
        assert(network == .grpc)
      }
    }

    public init(name: String, server: String, port: Int, uuid: String, alterId: Int, cipher: Cipher,
                udp: Bool) {
      self.name = name
      self.server = server
      self.port = port
      self.uuid = uuid
      self.alterId = alterId
      self.cipher = cipher
      self.udp = udp
    }

    private enum CodingKeys: String, CodingKey {
      case name, type, server, port, uuid, alterId, cipher, udp, tls
      case network
      case skipCertVerify = "skip-cert-verify"
      case servername
      case wsOptions = "ws-opts"
      case h2Options = "h2-opts"
      case httpOptions = "http-opts"
      case grpcOptions = "grpc-opts"
    }

    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.name = try container.decode(String.self, forKey: .name)
      self.server = try container.decode(String.self, forKey: .server)
      self.port = try container.decode(Int.self, forKey: .port)
      self.uuid = try container.decode(String.self, forKey: .uuid)
      self.alterId = try container.decode(Int.self, forKey: .alterId)
      self.cipher = try container.decode(Cipher.self, forKey: .cipher)
      self.udp = try container.decodeIfPresent(Bool.self, forKey: .udp)
      self.tls = try container.decodeIfPresent(Bool.self, forKey: .tls)
      self.skipCertVerify = try container.decodeIfPresent(Bool.self, forKey: .skipCertVerify)
      self.servername = try container.decodeIfPresent(String.self, forKey: .servername)
      self.network = try container.decodeIfPresent(Network.self, forKey: .network)

      self.wsOptions = try container.decodeIfPresent(WsOptions.self, forKey: .wsOptions)
      self.h2Options = try container.decodeIfPresent(H2Options.self, forKey: .h2Options)
      self.httpOptions = try container.decodeIfPresent(HttpOptions.self, forKey: .httpOptions)
      self.grpcOptions = try container.decodeIfPresent(GrpcOptions.self, forKey: .grpcOptions)

      // TODO: remove support for legacy vmess conf
      enum LegacyKeys: String, CodingKey {
        case wsPath = "ws-path"
        case wsHeaders = "ws-headers"
      }
      let legacyContainer = try decoder.container(keyedBy: LegacyKeys.self)
      let wsPath: String? = try legacyContainer.decodeIfPresent(String.self, forKey: .wsPath)
      let wsHeaders: WsHeaders? = try legacyContainer.decodeIfPresent(WsHeaders.self, forKey: .wsHeaders)
      if wsPath != nil || wsHeaders != nil {
        if wsOptions == nil {
          wsOptions = .init()
        }
        if wsOptions?.path == nil {
          wsOptions?.path = wsPath
        }
        if wsOptions?.headers == nil {
          wsOptions?.headers = wsHeaders
        }
      }
    }

  }

}

extension ClashProxy.VMess {
  public init(_ vmess: VMess) {
    name = vmess.ps
    server = vmess.add
    port = vmess.port.value
    uuid = vmess.id
    alterId = vmess.aid.value
    cipher = .auto
    udp = true
    tls = vmess.tls == "tls"
    //            skipCertVerify = false
    network = Network(rawValue: vmess.net)

//    wsHeaders = .init(host: vmess.host)
//    wsPath = vmess.path
  }
}

extension ClashProxy.VMess {

  public enum Cipher: String, Codable, CaseIterable, Equatable {
    case auto
    case aes_128_gcm = "aes-128-gcm"
    case chacha20_poly1305 = "chacha20-poly1305"
    case none
  }

  public enum Network: String, Codable {
    case ws
    case h2
    case http
    case grpc
  }

  public struct WsOptions: Codable, Equatable {
    public var path: String?
    public var headers: WsHeaders?
    public var maxEarlyData: Int?
    public var earlyDataHeaderName: String?

    private enum CodingKeys: String, CodingKey {
      case path, headers
      case maxEarlyData = "max-early-data"
      case earlyDataHeaderName = "early-data-header-name"
    }
  }

  public struct H2Options: Codable, Equatable {
    public var host: [String]
    public var path: String
  }

  public struct HttpOptions: Codable, Equatable {
    public var method: String?
    public var path: [String]?
    public var headers: [String: [String]]?
  }

  public struct GrpcOptions: Codable, Equatable {
    public var grpcServiceName: String
    private enum CodingKeys: String, CodingKey {
      case grpcServiceName = "grpc-service-name"
    }
  }

  public struct WsHeaders: Codable, Equatable {
    public init(host: String? = nil) {
      self.host = host
    }

    public var host: String?

    private enum CodingKeys: String, CodingKey {
      case host = "Host"
    }
  }
}

extension VMess {
  public init(_ vmess: ClashProxy.VMess) {

    self.init(v: 2, ps: vmess.name, add: vmess.server, port: .init(vmess.port),
              uuid: vmess.uuid, aid: .init(vmess.alterId), net: "ws", type: "",
              host: vmess.wsOptions?.headers?.host ?? "itunes.com", path: vmess.wsOptions?.path ?? "", tls: vmess.tls == true ? "tls" : "")
  }
}

extension ProxyConfig {
  public init(_ vmess: ClashProxy.VMess) {
    self = .vmess(.init(vmess))
  }
}
