import ProxyUtility
import V2RayProtocol

extension ClashProxy {
  public struct VMess: Codable, Equatable {

    public var name: String
    public let type: ProxyType = .vmess
    public var server: String
    public var port: Int
    public var uuid: String
    public var alterId: Int
    public var cipher: Cipher
    public var udp: Bool
    public var tls: Bool?
    public var skipCertVerify: Bool?
    public var network: Network?
    public var wsPath: String?
    public var wsHeaders: WsHeaders

    //      http mode
    //      public var httpOpts: HttpOptions
    public enum Network: String, Codable {
      case ws
      case http
    }

    public struct HttpOptions: Codable {
      public var method: String
      public var path: [String]
      public var headers: [String: String]
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

    public init(name: String, server: String, port: Int, uuid: String, alterId: Int, cipher: Cipher,
                udp: Bool = false, tls: Bool? = nil, skipCertVerify: Bool? = nil,
                network: Network? = nil, wsPath: String? = nil, wsHeaders: WsHeaders) {
      self.name = name
      self.server = server
      self.port = port
      self.uuid = uuid
      self.alterId = alterId
      self.cipher = cipher
      self.udp = udp
      self.tls = tls
      self.skipCertVerify = skipCertVerify
      self.network = network
      self.wsPath = wsPath
      self.wsHeaders = wsHeaders
    }

    public enum Cipher: String, Codable, CaseIterable, Equatable {
      case auto
      case aes_128_gcm = "aes-128-gcm"
      case chacha20_poly1305 = "chacha20-poly1305"
      case none
    }

    private enum CodingKeys: String, CodingKey {
      case name, type, server, port, uuid, alterId, cipher, udp, tls
      case network
      case skipCertVerify = "skip-cert-verify"
      case wsPath = "ws-path"
      case wsHeaders = "ws-headers"
    }

  }


}

extension ClashProxy.VMess {
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
    network = Network(rawValue: vmess._value.net)

    wsHeaders = .init(host: vmess._value.host)
    wsPath = vmess._value.path
  }
}

extension VMess {
  public init(_ vmess: ClashProxy.VMess) {

    self.init(_VMess(v: .init(2), ps: vmess.name, add: vmess.server, port: .init(vmess.port),
                     id: vmess.uuid, aid: .init(vmess.alterId), net: "ws", type: "",
                     host: vmess.wsHeaders.host ?? "itunes.com", path: vmess.wsPath ?? "", tls: vmess.tls == true ? "tls" : ""))
  }
}

extension ProxyConfig {
  public init(_ vmess: ClashProxy.VMess) {
    self = .vmess(.init(vmess))
  }
}
