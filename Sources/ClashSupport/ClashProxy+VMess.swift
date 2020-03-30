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
        public var network: String?
        public var wsPath: String?
        public var wsHeaders: [String: String]?

        public init(name: String, server: String, port: Int, uuid: String, alterId: Int, cipher: Cipher, udp: Bool = false, tls: Bool? = nil, skipCertVerify: Bool? = nil, network: String? = nil, wsPath: String? = nil, wsHeaders: [String : String]? = nil) {
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
        if vmess._value.net == "ws" {
            network = vmess._value.net
        }
        if !vmess._value.path.isEmpty {
            wsPath = vmess._value.path
        }
    }
}
