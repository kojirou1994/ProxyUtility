import Foundation

public struct V2ray: ShadowsocksPluginProtocol, Equatable, Codable {

  public static let availablePluginValues: [String] = []

  public var mode: Mode

  public var tls: Bool

  public var mux: Bool

  public var launchMode: PluginLaunchMode

  public var path: String

  public var host: String

  public init?<S>(type: PluginLaunchMode, plugin: String, pluginOpts: S) where S : StringProtocol {
    #warning("Unimplemented")
    return nil
  }

  public var plugin: String {
    localExecutable
  }

  public var pluginOpts: String {
    var opts = "mode=\(mode)"
    if launchMode == .server {
      opts.append(";server")
    }
    if tls {
      opts.append(";tls")
    }
    if !host.isEmpty {
      opts.append(";host=\(host)")
    }
    if !path.isEmpty {
      opts.append(";path=\(path)")
    }
    return opts
  }

  public var serverExecutable: String {
    localExecutable
  }

  public var localExecutable: String {
    "v2ray-plugin"
  }

  public enum Mode: String, Codable {
    case websocket
    case quic
  }

  public static func server(mode: Mode, tls: Bool, host: String) -> V2ray {
    .init(mode: mode, tls: tls, mux: true, type: .server, path: "", host: host)
  }

  public static func local(mode: Mode, tls: Bool, host: String, path: String) -> V2ray {
    .init(mode: mode, tls: tls, mux: true, type: .local, path: path, host: host)
  }

  private init(mode: Mode, tls: Bool, mux: Bool,
               type: PluginLaunchMode, path: String, host: String) {
    self.mode = mode
    self.tls = tls
    self.launchMode = type
    self.path = path
    self.host = host
    self.mux = mux
  }

  private enum CodingKeys: String, CodingKey {
    case mode, tls, host, path, mux
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    mode = try container.decode(Mode.self, forKey: .mode)
    tls = try container.decodeIfPresent(Bool.self, forKey: .tls) ?? false
    mux = try container.decodeIfPresent(Bool.self, forKey: .mux) ?? true
    host = try container.decode(String.self, forKey: .host)
    path = (try container.decodeIfPresent(String.self, forKey: .path)) ?? ""
    launchMode = .local
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(mode, forKey: .mode)
    try container.encode(tls, forKey: .tls)
    try container.encode(mux, forKey: .mux)
    try container.encode(host, forKey: .host)
    if !path.isEmpty {
      try container.encode(path, forKey: .path)
    }
  }

}
