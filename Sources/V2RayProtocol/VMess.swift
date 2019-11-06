import Foundation
import ProxyProtocol

public struct VMess: Codable, Equatable, ComplexProxyProtocol {
    
    public var id: String
    
    public func encode(to encoder: Encoder) throws {
        try _value.encode(to: encoder)
    }
    
    public init(from decoder: Decoder) throws {
        let value = try _VMess.init(from: decoder)
        try self.init(value)
    }
    
    public static let localExecutable: String = ""
    public let _value: _VMess
    public struct _VMess: Codable, Equatable {
        public let v: Int
        public let ps: String
        public let add: String
        public let port: String
        public let id: String
        public let aid: Int
        public let net: String
        public let type: String
        public let host: String
        public let path: String
        public let tls: String
    }
    
    private init(_ value: _VMess) throws {
        self._value = value
        id = value.ps
    }

    
    public var localAddress: String? {
        set {
            fatalError()
        }
        get {
            fatalError()
        }
    }
    
    public var localPort: Int {
        set {
            fatalError()
        }
        get {
            fatalError()
        }
    }
    
    public var jsonConfig: Data {
        set {
            fatalError()
        }
        get {
            fatalError()
        }
    }
    
    public func localArguments(configPath: String) -> [String] {
        fatalError()
    }
    
    public var localType: LocalType{
        set {
            fatalError()
        }
        get {
            fatalError()
        }
    }
    
    public var server: String {
        return _value.add
    }
    
    public var uri: String{
        return "vmess://\(String.init(decoding: try! JSONEncoder().encode(_value), as: UTF8.self).base64URLEncoded)"
    }
}
