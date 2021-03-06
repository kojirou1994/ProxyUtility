import Foundation
import ProxyProtocol
import ExtrasBase64

public struct VMess: Codable, Equatable, ComplexProxyProtocol {
  public init(version: VMess.ChineseInt?, id: String, server: String, port: VMess.ChineseInt, uuid: String, aid: VMess.ChineseInt, net: String, type: String, host: String, path: String?, tls: String) {
    self.version = version
    self.id = id
    self.server = server
    self.port = port
    self.uuid = uuid
    self.aid = aid
    self.net = net
    self.type = type
    self.host = host
    self.path = path
    self.tls = tls
  }

  public static let localExecutable: String = ""

  public let version: ChineseInt?
  public var id: String
  public let server: String
  public let port: ChineseInt
  public let uuid: String
  public let aid: ChineseInt
  public let net: String
  public let type: String
  public let host: String
  public let path: String?
  public let tls: String

  private enum CodingKeys: String, CodingKey {
    case version = "v"
    case id = "ps"
    case server = "add"
    case port
    case uuid = "id"
    case aid
    case net
    case type
    case host
    case path
    case tls
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

  public var uri: String{
    "vmess://\(Base64.encodeString(bytes: try! JSONEncoder().encode(self)))"
  }
}

extension VMess {
  public struct ChineseInt: Codable, Equatable, CustomStringConvertible {

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

    public var description: String { value.description }
  }
}

extension VMess.ChineseInt: ExpressibleByIntegerLiteral {
  public init(integerLiteral value: Int) {
    self.init(value)
  }
}
