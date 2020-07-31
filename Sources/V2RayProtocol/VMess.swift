import Foundation
import ProxyProtocol

public struct VMess: Codable, Equatable, ComplexProxyProtocol {
    
    public var id: String
    
    public func encode(to encoder: Encoder) throws {
        try _value.encode(to: encoder)
    }
    
    public init(from decoder: Decoder) throws {
        let value = try _VMess.init(from: decoder)
        self.init(value)
    }
    
    public static let localExecutable: String = ""
    public let _value: _VMess

  public struct ChineseInt: Codable, Equatable {
    public init(_ value: Int) {
      self.value = value
    }

        public let value: Int
        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let int = try? container.decode(Int.self) {
                value = int
            } else if let int = Int(try container.decode(String.self)) {
                value = int
            } else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Fuck chinese int")
            }
        }
        public func encode(to encoder: Encoder) throws {
            try value.encode(to: encoder)
        }
    }

  public struct _VMess: Codable, Equatable {
    public init(v: VMess.ChineseInt?, ps: String, add: String, port: VMess.ChineseInt, id: String, aid: VMess.ChineseInt, net: String, type: String, host: String, path: String, tls: String) {
      self.v = v
      self.ps = ps
      self.add = add
      self.port = port
      self.id = id
      self.aid = aid
      self.net = net
      self.type = type
      self.host = host
      self.path = path
      self.tls = tls
    }

        public let v: ChineseInt?
        public let ps: String
        public let add: String
        public let port: ChineseInt
        public let id: String
        public let aid: ChineseInt
        public let net: String
        public let type: String
        public let host: String
        public let path: String?
        public let tls: String
    }
    
    public init(_ value: _VMess) {
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
        _value.add
    }
    
    public var uri: String{
      "vmess://\(Base64.encode(bytes: try! JSONEncoder().encode(_value)))"
    }
}
