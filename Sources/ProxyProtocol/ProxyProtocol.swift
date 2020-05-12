import Foundation

public protocol UriRepresentable {
    var uri: String { get }
}

public protocol IdProvidable {
    var id: String { get set }
}

public protocol PureProxyProtocol: IdProvidable, UriRepresentable {
    var server: String { get }
}

public enum LocalType {
    case http
    case socks5
}

public protocol ComplexProxyProtocol: PureProxyProtocol {
    var localAddress: String? { set get }
    static var localExecutable: String { get }
    var localPort: Int { get set }
    var jsonConfig: Data { get }
    
    func localArguments(configPath: String) -> [String]
    var localType: LocalType { get }
}

extension ComplexProxyProtocol {
    public var jsonString: String {
        String.init(decoding: jsonConfig, as: UTF8.self)
    }
    
    public var localExecutable: String {
        Self.localExecutable
    }
}
