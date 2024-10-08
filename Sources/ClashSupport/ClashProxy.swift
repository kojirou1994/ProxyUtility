import Foundation

public enum ClashProxy: Codable, Equatable, Sendable {

  case shadowsocks(Shadowsocks)
  case socks5(Socks5)
  case http(HTTP)
  case vmess(VMess)
  case snell(Snell)
  case trojan(Trojan)
  case ssr(ShadowsocksR)

  public enum ProxyType: String, Codable, CaseIterable, Equatable, Identifiable, Sendable {
    case ss
    case vmess
    case socks5
    case http
    case snell
    case trojan
    case ssr

    public var id: Self { self }
  }

  public init(from decoder: Decoder) throws {

    enum TempTypeKey: CodingKey {
      case type
    }

    let container = try decoder.container(keyedBy: TempTypeKey.self)
    let type = try container.decode(ProxyType.self, forKey: .type)
    switch type {
    case .ss:
      self = .shadowsocks(try .init(from: decoder))
    case .socks5 :
      self = .socks5(try .init(from: decoder))
    case .http:
      self = .http(try .init(from: decoder))
    case .vmess:
      self = .vmess(try .init(from: decoder))
    case .snell:
      self = .snell(try .init(from: decoder))
    case .trojan:
      self = .trojan(try .init(from: decoder))
    case .ssr:
      self = .ssr(try .init(from: decoder))
    }
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.singleValueContainer()
    switch self {
    case .shadowsocks(let s): try c.encode(s)
    case .socks5(let s): try c.encode(s)
    case .http(let h): try c.encode(h)
    case .vmess(let v): try c.encode(v)
    case .snell(let s): try c.encode(s)
    case .trojan(let s): try c.encode(s)
    case .ssr(let s): try c.encode(s)
    }
  }

  public var server: String {
    get {
      switch self {
      case .shadowsocks(let s): return s.server
      case .snell(let s): return s.server
      case .trojan(let s): return s.server
      case .socks5(let s): return s.server
      case .http(let h): return h.server
      case .vmess(let v): return v.server
      case .ssr(let s): return s.server
      }
    }
    set {
      switch self {
      case .shadowsocks(var s):
        s.server = newValue
        self = .shadowsocks(s)
      case .socks5(var s):
        s.server = newValue
        self = .socks5(s)
      case .http(var h):
        h.server = newValue
        self = .http(h)
      case .vmess(var v):
        v.server = newValue
        self = .vmess(v)
      case .snell(var s):
        s.server = newValue
        self = .snell(s)
      case .trojan(var s):
        s.server = newValue
        self = .trojan(s)
      case .ssr(var s):
        s.server = newValue
        self = .ssr(s)
      }
    }
  }

  public var name: String {
    set {
      switch self {
      case .shadowsocks(var s):
        s.name = newValue
        self = .shadowsocks(s)
      case .socks5(var s):
        s.name = newValue
        self = .socks5(s)
      case .http(var h):
        h.name = newValue
        self = .http(h)
      case .vmess(var v):
        v.name = newValue
        self = .vmess(v)
      case .snell(var s):
        s.name = newValue
        self = .snell(s)
      case .trojan(var s):
        s.name = newValue
        self = .trojan(s)
      case .ssr(var s):
        s.name = newValue
        self = .ssr(s)
      }
    }
    get {
      switch self {
      case .shadowsocks(let s): return s.name
      case .socks5(let s): return s.name
      case .http(let h): return h.name
      case .vmess(let v): return v.name
      case .snell(let s): return s.name
      case .trojan(let s): return s.name
      case .ssr(let s): return s.name
      }
    }
  }

  public var port: Int {
    switch self {
    case .shadowsocks(let s): return s.port
    case .socks5(let s): return s.port
    case .http(let h): return h.port
    case .vmess(let v): return v.port
    case .snell(let s): return s.port
    case .trojan(let s): return s.port
    case .ssr(let s): return s.port
    }
  }

  public var type: ProxyType {
    switch self {
    case .shadowsocks: return .ss
    case .socks5: return .socks5
    case .http: return .http
    case .vmess: return .vmess
    case .snell: return .snell
    case .trojan: return .trojan
    case .ssr: return .ssr
    }
  }
}

