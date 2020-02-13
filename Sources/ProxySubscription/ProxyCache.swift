import Foundation
#if canImport(Kojirobot)
import Kojirobot
#endif
import ProxyUtility
import ShadowsocksProtocol
import SurgeSupport
import MaxMindDB
import URLFileManager
import KwiftExtension

public enum ProxyCacheStatus {
    case local
    case failed(ProxyCacheError)
    case same
    case new
}

public enum ProxyCacheError: Error {
    case network(URLError)
    case noneNodes
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

public struct SubscriptionContent {
    public struct Metadata {
        public var remainingData: String?
        public var expirationDate: String?
        public var domain: String?
    }
    public let metadata: Metadata
    public let configs: [ProxyConfig]

    public init(_ configs: [ProxyConfig]) {
        let invalidC = CharacterSet(charactersIn: ":： \n\r")
        func clearChineseInput(_ str: Substring) -> String {
            str.trimmingCharacters(in: invalidC)
        }

        var remainingData: String?
        var expirationDate: String?
        var domain: String?
        var _configs: [ProxyConfig] = []

        configs.forEach { (config) in
            if config.id.hasPrefix("剩余流量") {
                remainingData = clearChineseInput(config.id.dropFirst(4))
            } else if config.id.hasPrefix("过期时间") {
                expirationDate = clearChineseInput(config.id.dropFirst(4))
            } else if config.id.hasPrefix("最新域名") {
                domain = clearChineseInput(config.id.dropFirst(4))
            } else {
                _configs.append(config)
            }
        }

        self.metadata = .init(remainingData: remainingData, expirationDate: expirationDate, domain: domain)
        self.configs = _configs
    }
}

public enum ProxySubscriptionType: String, Codable, CaseIterable {
    case surge
    case ssr
    case plain
    case ssd
    case vmess

    public func decode(_ data: Data) -> [ProxyConfig] {
        switch self {
        case .plain:
            return ProxyURIParser.parse(subsription: data)
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
            return ssd.configs.map {ProxyConfig.ss($0)}
        case .ssr:
            return ProxyURIParser.parse(subsription: data)
//                .compactMap { (p) -> ProxyConfig? in
//                switch p {
//                case .ssr(var v):
////                    v.id = "\(configuration.name)_\(v.id)"
//                    return .ssr(v)
//                default: return nil
//                }
//            }
        case .surge:
            let confString = String(data: data, encoding: .utf8)!
            let lines = confString.split(separator: "\n").filter { !$0.isEmpty }
            return lines.compactMap { (str) -> ProxyConfig? in
                guard let p = SurgeShadowsocksProxy(String(str)) else {
                    return nil
                }
//                p.id = "\(configuration.name)_\(p.id)"
                return .ss(p.ssconf)
            }
        case .vmess:
            return ProxyURIParser.parse(subsription: data)
//                .compactMap { (p) -> Proxy? in
//                switch p {
//                case .vmess(var v):
//                    v.id = v._value.ps
////                    "\(configuration.name)_\(v._value.ps)"
//                    return .init(v)
//                default: return nil
//                }
//            }
        }
    }
}

public final class ProxySubscriptionCache: ProxyProvidable {
    public let configuration: ProxySubscriptionConfiguration
    public let cachePath: URL
    public let mmdb: MaxMindDB?
    private let session: URLSession

    #if canImport(Kojirobot)
    let robot: Kojirobot?
    #endif

    private static let updateQueue = DispatchQueue(label: "ProxySubscriptionCache")

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

    public init(_ configuration: ProxySubscriptionConfiguration, enableNotification: Bool, rootCacheDirectory: URL, mmdb: MaxMindDB?, session: URLSession) {
        let cachePath = rootCacheDirectory.appendingPathComponent(configuration.name.safeFilename())
        if URLFileManager.default.fileExistance(at: cachePath).exists {
            do {
                let cacheData = try autoreleasepool {
                    try Data(contentsOf: cachePath, options: .uncached)
                }
                proxies = ProxyURIParser.parse(subsription: cacheData)
                            .map{Proxy(config: $0, mmdb: mmdb)}
            } catch {
                fatalError(error.localizedDescription)
            }
        } else {
            proxies = []
        }
        self.configuration = configuration
        self.cachePath = cachePath
        self.mmdb = mmdb
        self.session = session
        status = .local
        #if canImport(Kojirobot)
        if enableNotification, let notify = configuration.notify {
            robot = Kojirobot(accountServer: .netease, destinations: notify)
        } else {
            robot = nil
        }
        #endif
        startUpdate()
    }

    public func startUpdate() {
        let updateResult = session.syncResultTask(request: .init(url: configuration.url))
        switch updateResult {
        case .failure(let e):
            self.status = .failed(.network(e))
        case .success(let r):
            let newNodes = self.configuration.type.decode(r.data)
                .map {Proxy(config: $0, mmdb: self.mmdb)}
            if newNodes.isEmpty {
                status = .failed(.noneNodes)
            } else {
                if newNodes == proxies {
                    self.status = .same
                } else {
                    self.proxies = newNodes
                    self.status = .same
                }
            }
        }
        Self.updateQueue.asyncAfter(deadline: .now() + 3600, execute: startUpdate)
//Log.info("Updating cache for \(id) result: same.")
//Log.info("Updating cache for \(id) result: success.")
//Log.info("Updating cache for \(id) result: none proxy.")
//Log.info("Update cache for \(id) error: \(error.localizedDescription).")
    }

    deinit {}

    
}
