extension ClashProxy {
  public struct Trojan: Codable, Equatable, ClashUDPFeature, Sendable {
    public init(name: String, server: String, port: Int, password: String, udp: Bool? = nil, sni: String? = nil, alpn: [String]? = nil, skipCertVerify: Bool? = nil, network: ClashProxy.Trojan.Network? = nil, grpcOptions: ClashProxy.VMess.GrpcOptions? = nil, wsOptions: ClashProxy.VMess.WsOptions? = nil) {
      self.name = name
      self.server = server
      self.port = port
      self.password = password
      self.udp = udp
      self.sni = sni
      self.alpn = alpn
      self.skipCertVerify = skipCertVerify
      self.network = network
      self.grpcOptions = grpcOptions
      self.wsOptions = wsOptions
    }
    
    public var name: String
    public let type: ProxyType = .trojan
    public var server: String
    public var port: Int
    public var password: String
    public var udp: Bool?
    public var sni: String?
    public var alpn: [String]?
    public var skipCertVerify: Bool?
    public var network: Network?
    public var grpcOptions: VMess.GrpcOptions?
    public var wsOptions: VMess.WsOptions?

    public enum Network: String, Codable, Sendable {
      case grpc
      case ws
    }

    private enum CodingKeys: String, CodingKey {
      case name, type, server, port, udp, sni, alpn, password, network
      case skipCertVerify = "skip-cert-verify"
      case grpcOptions = "grpc-opts"
      case wsOptions = "ws-opts"
    }
  }
}
