import Foundation
import ShadowsocksProtocol

public struct SurgeShadowsocksProxy: Equatable {
  static let module = "http://wangzi.gq/downloads/SSEncrypt.module"

  typealias ExtraFlag = [String: String]

  public var id: String

  var server: String

  var serverPort: Int

  var method: ShadowsocksEnryptMethod

  var password: String

  var extra: ExtraFlag

  public init(ssconf: ShadowsocksConfig) {
    id = ssconf.id
    server = ssconf.server
    serverPort = ssconf.serverPort
    method = ssconf.method
    password = ssconf.password
    extra = [:]
    if let plugin = ssconf.plugin {
      if case let ShadowsocksPlugin.obfs(obfs) = plugin {
        extra = generateExtra(obfs.pluginOpts.components(separatedBy: ";"))
      } else {
        fatalError("Unsupported plugin: \(plugin)")
      }
    }
  }

  public var isJapan: Bool {
    false
  }

  public var ssconf: ShadowsocksConfig {
    if extra.count == 0 {
      return ShadowsocksConfig.local(id: id, server: server, serverPort: serverPort, password: password, method: method, plugin: nil)
    } else {
      let obfs = Obfs.init(type: .local, plugin: "obfs-local", pluginOpts: extra.filter({$0.key.hasPrefix("obfs")}).sorted(by: {$0.key < $1.key}).map({"\($0.key)=\($0.value)"}).joined(separator: ";"))!
      return ShadowsocksConfig.local(id: id, server: server, serverPort: serverPort, password: password,
                                     method: method, plugin: .obfs(obfs))
    }
  }

  public var speed: ServerSpeedType {
    let nameComp = id.components(separatedBy: "_").map { $0.lowercased() }
    for comp in nameComp {
      if comp.contains("gbps") || comp.contains("大带宽") {
        return .fast
      } else if comp.hasSuffix("mbps") {
        if let speedValue = Int(comp[comp.startIndex ..< comp.index(comp.endIndex, offsetBy: -4)]) {
          if speedValue > 50 {
            return .fast
          } else {
            return .slow
          }
        }
      }
    }
    return .slow
  }
}

extension SurgeShadowsocksProxy: SurgeProxy {

  public init?(_ description: String) {
    guard let parsed = SurgeConfigParser.parse(full: description) else {
      return nil
    }
    guard parsed.1 == .custom else {
      return nil
    }
    id = parsed.0
    let arguments = parsed.2
    guard case let server = arguments[0],
          let server_port = Int(arguments[1]),
          let method = ShadowsocksEnryptMethod.init(rawValue: arguments[2]),
          case let password = arguments[3] else {
      return nil
    }
    self.server = server
    serverPort = server_port
    self.method = method
    self.password = password
    extra = [:]
    if arguments.count > 5 {
      extra = generateExtra(arguments[5...].filter({ !$0.isEmpty }))
    }
  }

  private func generateExtra(_ v: [String]) -> ExtraFlag {
    return v.reduce(ExtraFlag(), {
      var dic = $0
      let parts = $1.split(separator: "=")
      if parts.count == 2 {
        dic[String(parts[0])] = String(parts[1])
      }
      return dic
    })
  }

  private func extractExtra() -> [String] {
    extra.map({"\($0)=\($1)"})
  }

  public var type: SurgeProxyType {
    .custom
  }

  public var arguments: [String] {
    return [server, serverPort.description, method.rawValue, password, SurgeShadowsocksProxy.module] + extractExtra()
  }
}
