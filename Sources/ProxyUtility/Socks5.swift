import Foundation
import ProxyProtocol

public struct Socks5: Codable, Equatable, UriRepresentable {
    
    public let id: String
    public let server: String
    public let port: Int
//    public let tls: Bool?
//    public let username: String?
//    public let password: String?
//    public let skipCertVerify: Bool?
    
    public init(id: String, server: String, port: Int) {
        self.id = id
        self.server = server
        self.port = port
    }
    
    public var uri: String {
        var url = URLComponents.init()
        url.scheme = "socks"
        url.host = server
        url.port = port
        return url.url!.absoluteString
    }
}
