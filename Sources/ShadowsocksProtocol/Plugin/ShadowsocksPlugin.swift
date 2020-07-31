import Foundation

public enum PluginLaunchMode {
  case server
  case local
}

public protocol ShadowsocksPluginProtocol {
  init?<S>(type: PluginLaunchMode, plugin: String, pluginOpts: S) where S: StringProtocol
  var plugin: String {get}
  var pluginOpts: String {get}
  var serverExecutable: String {get}
  var localExecutable: String {get}

  static var availablePluginValues: [String] {get}
}

public enum ShadowsocksPlugin: ShadowsocksPluginProtocol, Equatable {
  public static let availablePluginValues: [String] = []

  case obfs(Obfs)

  case v2ray(V2ray)

  public init?<S>(type: PluginLaunchMode, plugin: String, pluginOpts: S) where S : StringProtocol {
    if let obfs = Obfs.init(type: type, plugin: plugin, pluginOpts: pluginOpts) {
      self = .obfs(obfs)
    } else if let v2ray = V2ray.init(type: type, plugin: plugin, pluginOpts: pluginOpts) {
      self = .v2ray(v2ray)
    } else {
      print("Unsupported plugin: \(plugin)")
      return nil
    }
  }

  public var plugin: String {
    switch self {
    case .obfs(let v):
      return v.plugin
    case .v2ray(let v):
      return v.plugin
    }
  }

  public var pluginOpts: String {
    switch self {
    case .obfs(let v):
      return v.pluginOpts
    case .v2ray(let v):
      return v.pluginOpts
    }
  }

  public var serverExecutable: String {
    switch self {
    case .obfs(let v):
      return v.serverExecutable
    case .v2ray(let v):
      return v.serverExecutable
    }
  }

  public var localExecutable: String {
    switch self {
    case .obfs(let v):
      return v.localExecutable
    case .v2ray(let v):
      return v.localExecutable
    }
  }

  private enum Keys: String, CodingKey {
    case plugin
    case pluginOpts = "plugin_opts"
  }

  //    public func encode(to encoder: Encoder) throws {
  //        switch self {
  //        case .obfs(let v):
  //            try v.encode(to: encoder)
  //        case .v2ray(let v):
  //            try v.encode(to: encoder)
  //        }
  //    }

  public init(from decoder: Decoder) throws {
    //        let container = try decoder.container(keyedBy: Keys.self)

    fatalError()
  }
}
