import Foundation
import V2RayProtocol
import MaxMindDB
import ProxyProtocol
import ShadowsocksProtocol
import ClashSupport

public struct Proxy: Equatable {

  public var config: ProxyConfig

  public let ip: String

  public let country: String

  public init(config: ProxyConfig, mmdb: MaxMindDB? = nil) {
    self.config = config
    self.ip = config.server.parseDNS() ?? "127.0.0.1"
    if let mmdb = mmdb,
       let result = try? mmdb.lookupResult(ip: ip),
       let country = result.country?.isoCode {
      if let city = result.city?.names.en {
        self.country = "\(country)-\(city)"
      } else {
        self.country = country
      }
    } else {
      self.country = "UD"
    }
  }

  public init(_ ss: ShadowsocksConfig, mmdb: MaxMindDB? = nil) {
    self.init(config: .ss(ss), mmdb: mmdb)
  }

  public init(_ ssr: ShadowsocksRConfig, mmdb: MaxMindDB? = nil) {
    self.init(config: .ssr(ssr), mmdb: mmdb)
  }

  public init(_ vmess: VMess, mmdb: MaxMindDB? = nil) {
    self.init(config: .vmess(vmess), mmdb: mmdb)
  }

  public static func ==(lhs: Proxy, rhs: Proxy) -> Bool {
    return lhs.config == rhs.config
  }
}

public enum ProxyConfig: Equatable, UriRepresentable {

  case ss(ShadowsocksConfig)
  case ssr(ShadowsocksRConfig)
  case socks5(Socks5)
  case vmess(VMess)
  case clash(ClashProxy)

  public var id: String {
    switch self {
    case .socks5(let v): return v.id
    case .ss(let v): return v.id
    case .ssr(let v): return v.id
    case .vmess(let v): return v.id
    case .clash(let v): return v.name
    }
  }

  public var uri: String {
    switch self {
    case .socks5(let v): return v.uri
    case .ss(let v): return v.uri
    case .ssr(let v): return v.uri
    case .vmess(let v): return v.uri
    case .clash: fatalError()
    }
  }

  public var server: String {
    switch self {
    case .socks5(let v): return v.server
    case .ss(let v): return v.server
    case .ssr(let v): return v.server
    case .vmess(let v): return v.server
    case .clash(let v): return v.server
    }
  }

  public var localExecutable: String {
    switch self {
    case .socks5(_): fatalError()
    case .ss(let v): return v.localExecutable
    case .ssr(let v): return v.localExecutable
    case .vmess(let v): return v.localExecutable
    case .clash: fatalError()
    }
  }

  public var localPort: Int {
    switch self {
    case .socks5(_): fatalError()
    case .ss(let v): return v.localPort
    case .ssr(let v): return v.localPort
    case .vmess(let v): return v.localPort
    case .clash: fatalError()
    }
  }

  public var shadowsocks: ShadowsocksConfig? {
    switch self {
    case .ss(let v): return v
    default: return nil
    }
  }

  public var shadowsocksR: ShadowsocksRConfig? {
    switch self {
    case .ssr(let v): return v
    default: return nil
    }
  }
}

extension String {

  /// get IPv4 address from current host DNS name
  /// - parameters:
  ///   - service: service port, such as "http", "ftp", "https" or "ssh", etc.
  /// - returns:
  ///   - ip address if success, or nil if something wrong.
  public func parseDNS(_ service: String = "http") -> String? {
    let hints = UnsafePointer<addrinfo>(bitPattern: 0)
    var res = UnsafeMutablePointer<addrinfo>(bitPattern: 0)
    guard 0 == getaddrinfo(self, service, hints, &res), let s = res else {
      return nil
    }//end guard
    let p = unsafeBitCast(s.pointee.ai_addr, to: UnsafePointer<sockaddr_in>.self)
    var address = p.pointee.sin_addr
    let ipAddress = UnsafeMutablePointer<Int8>.allocate(capacity: Int(INET_ADDRSTRLEN + 1))
    var ip = ""
    if let _ = inet_ntop(AF_INET, &address, ipAddress, socklen_t(INET_ADDRSTRLEN)) {
      ipAddress.advanced(by: Int(INET_ADDRSTRLEN)).pointee = 0
      ip = String(cString: ipAddress)
    }//end if
    ipAddress.deinitialize(count: Int(INET_ADDRSTRLEN + 1))
    ipAddress.deallocate()
    freeaddrinfo(s)
    return ip.isEmpty ? nil: ip
  }//end func
}//end extension

extension ClashProxy {
  public init(_ proxy: ProxyConfig) {
    switch proxy {
    case .socks5(let v):
      self = .socks5(.init(name: v.id, server: v.server, port: v.port, tls: false, username: v.username, password: v.password, skipCertVerify: v.skipCertVerify, udp: v.udp))
    case .ss(let v):
      self = .shadowsocks(.init(v))
    case .vmess(let v):
      self = .vmess(.init(v))
    case .ssr(let v):
      self = .ssr(.init(v))
    case .clash(let v):
      self = v
    }
  }
}

extension ClashProxy.VMess {
  public init(_ vmess: VMess) {
    fatalError("wrong conversion")
    name = vmess.id
    server = vmess.server
    port = vmess.port.value
    uuid = vmess.uuid
    alterId = vmess.aid.value
    cipher = .auto
    udp = true
    tls = vmess.tls == "tls"
    network = Network(rawValue: vmess.net)
    wsOptions = .init(path: vmess.path, headers: .init(host: vmess.host))
  }
}

extension VMess {
  public init(_ vmess: ClashProxy.VMess) {
    fatalError("wrong conversion")
    self.init(version: 2, id: vmess.name, server: vmess.server, port: .init(vmess.port),
              uuid: vmess.uuid, aid: .init(vmess.alterId), net: "ws", type: "",
              host: vmess.wsOptions?.headers?.host ?? "itunes.com", path: vmess.wsOptions?.path ?? "", tls: vmess.tls == true ? "tls" : "")
  }
}

extension ProxyConfig {
  public init(_ vmess: ClashProxy.VMess) {
    self = .vmess(.init(vmess))
  }
}
