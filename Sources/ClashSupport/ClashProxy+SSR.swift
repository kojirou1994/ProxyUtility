import ShadowsocksProtocol
import ProxyUtility

extension ClashProxy {
  public struct ShadowsocksR: Codable, Equatable, ClashUDPFeature {

    public var name: String
    public let type: ProxyType = .ssr

    public var server: String
    public var port: Int
    public var cipher: ShadowsocksEnryptMethod
    public var password: String
    public var obfs: ShadowsocksRConfig.Obfs
    public var `protocol`: ShadowsocksRConfig.Protocols
    public var obfsParam: String?
    public var protocolParam: String?
    public var udp: Bool?

    public init(name: String, server: String, port: Int,
                cipher: ShadowsocksEnryptMethod, password: String,
                obfs: ShadowsocksRConfig.Obfs, protocol: ShadowsocksRConfig.Protocols,
                obfsParam: String = "", protocolParam: String = "",
                udp: Bool) {
      self.name = name
      self.server = server
      self.port = port
      self.cipher = cipher
      self.password = password
      self.obfs = obfs
      self.protocol = `protocol`
      self.obfsParam = obfsParam
      self.protocolParam = protocolParam
      self.udp = udp
    }

    private enum CodingKeys: String, CodingKey {
      case name
      case type
      case server
      case port
      case cipher
      case password
      case obfs
      case `protocol`
      case obfsParam = "obfs-param"
      case protocolParam = "protocol-param"
      case udp
    }
  }
}

extension ShadowsocksRConfig {
  public init(_ ssr: ClashProxy.ShadowsocksR) {

    self.init(id: ssr.name, group: nil,
              server: ssr.server, server_port: ssr.port,
              local_address: nil, local_port: 1080,
              password: ssr.password, timeout: 3600,
              method: ssr.cipher, protocol: ssr.protocol,
              proto_param: ssr.protocolParam,
              obfs: ssr.obfs, obfs_param: ssr.obfsParam)
  }
}

extension ClashProxy.ShadowsocksR {
  public init(_ ssr: ShadowsocksRConfig) {
    self.init(name: ssr.id,
              server: ssr.server, port: ssr.serverPort,
              cipher: ssr.method, password: ssr.password,
              obfs: ssr.obfs, protocol: ssr.protocol,
              obfsParam: ssr.obfsParam ?? "", protocolParam: ssr.protoParam ?? "",
              udp: true)
  }
}

extension ProxyConfig {
  public init(_ ssr: ClashProxy.ShadowsocksR) {
    self = .ssr(.init(ssr))
  }
}
