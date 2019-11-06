import Foundation
#if canImport(Kojirobot)
import Kojirobot
#endif
import ProxyUtility
import ShadowsocksProtocol
import SurgeSupport
import MaxMindDB

public enum ProxyCacheStatus: String, Codable {
    case local
    case failed
    case same
    case new
}

public struct ProxySubscriptionConfiguration: Codable {
    public let name: String
    public let url: URL

    public let type: ProxySubscriptionType
    public let notify: [String]?
    
    public init(name: String, url: URL, type: ProxySubscriptionType) {
        self.name = name
        self.url = url
        self.type = type
        self.notify = nil
    }
}

public enum ProxySubscriptionType: String, Codable {
    case surge
    case ssr
    case plain
    case ssd
    case vmess
}

public final class ProxySubscriptionCache: ProxyProvidable {

    public let configuration: ProxySubscriptionConfiguration

    public let cachePath: URL
    
    public let mmdb: MaxMindDB?

    #if canImport(Kojirobot)
    let robot: Kojirobot?
    #endif

    private static let updateQueue = DispatchQueue(label: "ProxyCache-Update")

    public private(set) var proxies: [Proxy] {
        didSet {
            // save to cache file
//            Log.info("Saving cache for \(sourceURL)")
            
            do {
                let fileData = proxies.map{ $0.config.uri }.joined(separator: "\n").data(using: .utf8)!
                #if canImport(Kojirobot)
                try robot?.send(KojirobotNotification(subject: "代理更新", title: "需要更新自行导入", contentTitle: id, content: """
                导入时看准每行开头是xx还是xxr，别导入错了
                windows一次导入全部会很卡，弄几个就够了
                """, application: "ProxyServer"), attachments: [Attachment(data: fileData, mime: "text/plain", name: "\(id).txt")], completion: nil)
                #endif
                try fileData.write(to: cachePath)
            } catch {
//                Log.error(error.localizedDescription)
            }
            
        }
    }

    public private(set) var status: ProxyCacheStatus

    public init(_ configuration: ProxySubscriptionConfiguration, enableNotification: Bool, rootCacheDirectory: URL, mmdb: MaxMindDB?) {
        let cachePath = rootCacheDirectory.appendingPathComponent(configuration.name.safeFilename())
        if FileManager.default.fileExists(atPath: cachePath.path) {
            do {
                let cacheData = try Data(contentsOf: cachePath)
                proxies = ProxyURIParser.parse(subsription: cacheData).map{Proxy(config: $0, mmdb: mmdb)}
            } catch {
                fatalError(error.localizedDescription)
            }
        } else {
            proxies = []
        }
        self.configuration = configuration
        self.cachePath = cachePath
        self.mmdb = mmdb
        status = .local
        #if canImport(Kojirobot)
        if enableNotification, let notify = configuration.notify {
            robot = Kojirobot(accountServer: .netease, destinations: notify)
        } else {
            robot = nil
        }
        #endif
        update()
    }

    func checkEqual(_ l: [ShadowsocksProtocol], _ r: [ShadowsocksProtocol]) -> Bool {
        guard l.count == r.count else {
            return false
        }
        for index in 0 ..< l.count {
            if index == 0 {} else if l[index].uri != r[index].uri {
                return false
            }
        }
        return true
    }

//    private let lock = NSLock()
    
    private func update() {
//        lock.lock()
//        Log.info("Start updating cache for \(id).")

        do {
            let new = try Data(contentsOf: configuration.url)
            let newP = serialize(new)
            if newP.count > 0 {
                if newP == proxies {
//                    Log.info("Updating cache for \(id) result: same.")
                    status = .same
                } else {
//                    Log.info("Updating cache for \(id) result: success.")
                    proxies = newP
                    status = .new
                }
            } else {
//                Log.info("Updating cache for \(id) result: none proxy.")
                status = .failed
            }
        } catch {
//            Log.info("Update cache for \(id) error: \(error.localizedDescription).")
            status = .failed
        }
//        lock.unlock()
        Self.updateQueue.asyncAfter(deadline: .now() + 3600, execute: update)
    }

    deinit {}

    public func serialize(_ data: Data) -> [Proxy] {
        switch configuration.type {
        case .plain:
            return ProxyURIParser.parse(subsription: data).map{Proxy(config: $0, mmdb: self.mmdb)}
        case .ssd:
            let str = String.init(decoding: data, as: UTF8.self)
                    guard str.hasPrefix("ssd://") else {
                        return []
                    }
                    
            let encoded = String(str.dropFirst(6))
            guard let decoded = encoded.base64URLDecoded else {
                return []
            }
            
            let newdata = decoded.data(using: .utf8)!
            guard let ssd = try? JSONDecoder.init().decode(SSD.self, from: newdata) else {
                return []
            }
    //        dump(ssd)
            return ssd.configs.map { Proxy.init(config: .ss($0)) }
        case .ssr:
            return ProxyURIParser.parse(subsription: data).compactMap { (p) -> Proxy? in
                switch p {
                case .ssr(var v):
                    v.id = "\(configuration.name)_\(v.id)"
                    return .init(config: .ssr(v))
                default: return nil
                }
            }
        case .surge:
            let confString = String(data: data, encoding: .utf8)!
            let lines = confString.split(separator: "\n").filter { !$0.isEmpty }
            return lines.compactMap { (str) -> Proxy? in
                guard var p = SurgeShadowsocksProxy(String(str)) else {
                    return nil
                }
                p.id = "\(configuration.name)_\(p.id)"
                return .init(config: .ss(p.ssconf))
            }
        case .vmess:
            return ProxyURIParser.parse(subsription: data).compactMap { (p) -> Proxy? in
                switch p {
                case .vmess(var v):
                    v.id = "\(configuration.name)_\(v._value.ps)"
                    return .init(v)
                default: return nil
                }
            }
        }
    }
    
    struct SSD: Codable {
        
        var port: Int
        
        struct Server: Codable {
            
            var remarks: String
            
            var id: Int
            
            var ratio: Double
            
            var server: String
            
            private enum CodingKeys: String, CodingKey {
                case id
                case remarks
                case ratio
                case server
            }
            
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
}
