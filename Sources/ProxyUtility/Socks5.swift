import Foundation
import ProxyProtocol

public struct Socks5: Codable, Equatable, UriRepresentable {

    public var id: String
    public var server: String
    public var port: Int
    public var tls: Bool
    public var username: String?
    public var password: String?
    public var skipCertVerify: Bool
    public var udp: Bool

    public init(id: String, server: String, port: Int, tls: Bool, username: String? = nil, password: String? = nil, skipCertVerify: Bool, udp: Bool) {
        self.id = id
        self.server = server
        self.port = port
        self.tls = tls
        self.username = username
        self.password = password
        self.skipCertVerify = skipCertVerify
        self.udp = udp
    }

    public var uri: String {
        var url = URLComponents.init()
        url.scheme = "socks"
        url.host = server
        url.port = port
        return url.url!.absoluteString
    }
}
