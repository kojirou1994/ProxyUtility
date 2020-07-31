extension ClashProxy {
  public struct HTTP: Codable, Equatable {
    public var name: String
    public let type: ProxyType = .http
    public var server: String
    public var port: Int
    public var tls: Bool
    public var username: String?
    public var password: String?
    public var skipCertVerify: Bool
    
    public init(name: String, server: String, port: Int, tls: Bool,
                username: String?, password: String?, skipCertVerify: Bool) {
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

