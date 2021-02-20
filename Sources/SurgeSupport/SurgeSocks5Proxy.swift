import Foundation

public struct SurgeSocks5Proxy: Hashable, Comparable {
  public var id: String

  public var server: String

  public var port: Int

  public var username: String

  public var password: String

  public init(id: String, server: String, port: Int, username: String = "", password: String = "") {
    self.id = id
    self.server = server
    self.port = port
    self.username = username
    self.password = password
  }

  public static func < (lhs: SurgeSocks5Proxy, rhs: SurgeSocks5Proxy) -> Bool {
    lhs.id < rhs.id
  }
}

extension SurgeSocks5Proxy: SurgeProxy {
  public var type: SurgeProxyType {
    .socks5
  }

  public var arguments: [String] {
    [server, port.description, username, password]
  }

  public init?(_ description: String) {
    guard let parsed = SurgeConfigParser.parse(full: description),
          parsed.1 == .socks5,
          parsed.2.count == 4,
          let port = Int(parsed.2[1]) else {
      return nil
    }
    id = parsed.0
    server = parsed.2[0]
    self.port = port
    username = parsed.2[2]
    password = parsed.2[3]
  }
}
