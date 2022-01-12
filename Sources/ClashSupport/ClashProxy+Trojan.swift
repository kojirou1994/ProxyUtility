extension ClashProxy {
  public struct Trojan: Codable, Equatable, ClashUDPFeature {
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

    public enum Network: String, Codable {
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
