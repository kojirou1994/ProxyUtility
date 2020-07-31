import ShadowsocksProtocol

extension ClashProxy {
  public struct Snell: Codable, Equatable {
    public var name: String

    public let type: ProxyType = .snell

    public var server: String

    public var port: Int

    public var psk: String

    public var obfsOpts: ObfsOpts?
    
    public init(name: String, server: String, port: Int, psk: String, obfsOpts: ClashProxy.Snell.ObfsOpts? = nil) {
      self.name = name
      self.server = server
      self.port = port
      self.psk = psk
      self.obfsOpts = obfsOpts
    }

    public struct ObfsOpts: Codable, Equatable {
      public var mode: Obfs.Mode
      public var host: String
      public init(mode: Obfs.Mode, host: String) {
        self.mode = mode
        self.host = host
      }
    }

    private enum CodingKeys: String, CodingKey {
      case name, type, server, port, psk
      case obfsOpts = "obfs-opts"
    }
  }
}
