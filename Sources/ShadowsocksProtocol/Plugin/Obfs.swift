import Foundation
import KwiftExtension

fileprivate let defaultObfsHost = "www.bing.com"

public struct Obfs: ShadowsocksPluginProtocol, Equatable, Codable {
    public static var availablePluginValues: [String] { return ["obfs-local", "simple-obfs"] }
    
    public let launchMode: PluginLaunchMode
    
    public var mode: Mode
    
    public var obfsHost: String?
    
    public init?<S>(type: PluginLaunchMode, plugin: String, pluginOpts: S) where S : StringProtocol {
        guard Obfs.availablePluginValues.contains(plugin) else {
            return nil
        }
        let parts = pluginOpts.split(separator: ";")
        if parts.count == 1, parts[0].hasPrefix("obfs="),
            let obfs = Mode.init(rawValue: String(String(parts[0])[5...])) {
            self.mode = obfs
            self.obfsHost = defaultObfsHost
        } else if parts.count == 2 {
            if parts[0].hasPrefix("obfs="), parts[1].hasPrefix("obfs-host="),
                let obfs = Mode.init(rawValue: String(String(parts[0])[5...])) {
                self.mode = obfs
                self.obfsHost = String(String(parts[1])[10...])
            } else if parts[1].hasPrefix("obfs="), parts[0].hasPrefix("obfs-host="),
                let obfs = Mode.init(rawValue: String(String(parts[1])[5...])){
                self.mode = obfs
                self.obfsHost = String(String(parts[0])[10...])
            } else {
                return nil
            }
        } else {
            return nil
        }
        self.launchMode = type
    }
    
    public enum Mode: String, Codable {
        case http
        case tls
    }
    
    private enum CodingKeys: String, CodingKey {
        case mode, host
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mode = try container.decode(Mode.self, forKey: .mode)
        obfsHost = try container.decodeIfPresent(String.self, forKey: .host)
        launchMode = .local
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mode, forKey: .mode)
        try container.encodeIfPresent(obfsHost, forKey: .host)
    }
    
    public static func server(obfs: Mode) -> Obfs {
        return .init(type: .server, obfs: obfs, obfsHost: nil)
    }
    
    public static func local(obfs: Mode, obfsHost: String = "baidu.com") -> Obfs {
        return .init(type: .local, obfs: obfs, obfsHost: obfsHost)
    }
    
    private init(type: PluginLaunchMode, obfs: Mode, obfsHost: String?) {
        self.launchMode = type
        self.mode = obfs
        self.obfsHost = obfsHost
    }
    
    public var plugin: String {
        return "obfs-local"
    }
    
    public var pluginOpts: String {
        switch launchMode {
        case .server:
            return "obfs=\(mode)"
        case .local:
            return "obfs=\(mode);obfs-host=\(obfsHost!)"
        }
    }
    
    public var serverExecutable: String {
        return "obfs-server"
    }
    
    public var localExecutable: String {
        return "obfs-local"
    }
    
}
