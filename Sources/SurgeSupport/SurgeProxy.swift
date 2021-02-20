import Foundation
import ProxyProtocol
public enum ServerSpeedType: Hashable {
  case slow, fast
}

public enum SurgeProxyType: String {
  case direct
  case http
  case https
  case socks5
  case socks5tls = "socks5-tls"
  case custom
}

public protocol SurgeProxyGroupMember: IdProvidable {}

public protocol SurgeProxy: SurgeProxyGroupMember, LosslessStringConvertible {
  var type: SurgeProxyType { get }
  var arguments: [String] { get }
}

extension SurgeProxy {
  public var arguments: [String] {
    []
  }

  public var description: String {
    if arguments.count == 0 {
      return "\(id) = \(type.rawValue)"
    } else {
      return "\(id) = \(type.rawValue), \(arguments.joined(separator: ", "))"
    }
  }
}
