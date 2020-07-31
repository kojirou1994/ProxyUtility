import Foundation
import ShadowsocksProtocol

public protocol ProxyProvidable {

  var proxies: [Proxy] { get }

}

extension ProxyProvidable {

  public var allShadowsocks: [ShadowsocksConfig] {
    proxies.compactMap { $0.config.shadowsocks }
  }

  public var allShadowsocksR: [ShadowsocksRConfig] {
    proxies.compactMap { $0.config.shadowsocksR }
  }

}
