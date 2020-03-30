extension ClashProxy {
    public struct Trojan: Codable, Equatable {
        public var name: String
        public let type: ProxyType = .trojan
        public var server: String
        public var port: Int
        public var udp: Bool
        public var sni: String?
        public var alpn: [String]?
        public var skipCertVerify: Bool

        public init(name: String, server: String, port: Int, udp: Bool, sni: String? = nil, alpn: [String]? = nil, skipCertVerify: Bool) {
            self.name = name
            self.server = server
            self.port = port
            self.udp = udp
            self.sni = sni
            self.alpn = alpn
            self.skipCertVerify = skipCertVerify
        }

        private enum CodingKeys: String, CodingKey {
            case name, type, server, port, udp, sni, alpn
            case skipCertVerify = "skip-cert-verify"
        }
    }
}
