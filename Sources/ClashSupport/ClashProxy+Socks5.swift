extension ClashProxy {
  public struct Socks5: Codable, Equatable, Sendable {
    public var name: String
    public let type: ProxyType = .socks5
    public var server: String
    public var port: Int
    public var tls: Bool?
    public var username: String?
    public var password: String?
    public var skipCertVerify: Bool?
    public var udp: Bool?
    public init(name: String, server: String, port: Int, tls: Bool,
                username: String? = nil, password: String? = nil,
                skipCertVerify: Bool, udp: Bool) {
      self.name = name
      self.server = server
      self.port = port
      self.tls = tls
      self.username = username
      self.password = password
      self.skipCertVerify = skipCertVerify
      self.udp = udp
    }
    
    private enum CodingKeys: String, CodingKey {
      case name, type, server, port, tls, username, password, udp
      case skipCertVerify = "skip-cert-verify"
    }
  }
}
