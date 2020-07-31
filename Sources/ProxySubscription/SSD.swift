import Foundation
import ShadowsocksProtocol

struct SSD: Codable {
  var port: Int
  struct Server: Codable {
    var remarks: String
    var id: Int
    var ratio: Double
    var server: String
  }
  var servers: [Server]
  var expiry: String
  var encryption: ShadowsocksEnryptMethod
  var plugin: String
  var airport: String
  var trafficUsed: Double
  var pluginOptions: String
  var url: String
  var password: String
  var trafficTotal: Double
  private enum CodingKeys: String, CodingKey {
    case password
    case trafficTotal = "traffic_total"
    case expiry
    case airport
    case trafficUsed = "traffic_used"
    case servers
    case url
    case encryption
    case port
    case plugin
    case pluginOptions = "plugin_options"
  }

  var configs: [ShadowsocksConfig] {
    if let plugin = ShadowsocksPlugin.init(type: .local, plugin: plugin, pluginOpts: pluginOptions) {
      return servers.map({ (server) -> ShadowsocksConfig in
        return ShadowsocksConfig.local(id: "\(airport)_\(server.remarks)", server: server.server, serverPort: port, password: password, method: encryption, plugin: plugin)
      })
    } else {
      print("Unsupported ss plugin: \(plugin), opts: \(pluginOptions)")
      return []
    }

  }

}
