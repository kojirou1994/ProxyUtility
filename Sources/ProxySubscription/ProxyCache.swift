import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import ProxyUtility
import ShadowsocksProtocol
import SurgeSupport
import MaxMindDB
import URLFileManager
import KwiftExtension
import ClashSupport
import Yams
import ProxyProtocol

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
  public struct Metadata: Equatable {
    public var remainingData: String?
    public var expirationDate: String?
    public var domain: String?

    public var hasUsefulInfo: Bool {
      remainingData != nil || expirationDate != nil || domain != nil
    }
  }
  public let metadata: Metadata
  public let configs: [ProxyConfig]

  @usableFromInline
  static let invalidC = CharacterSet(charactersIn: ":： \n\r")

  @usableFromInline
  static func clearChineseInput(_ str: Substring) -> String {
    str.trimmingCharacters(in: invalidC)
  }

  public init(_ configs: [ProxyConfig]) {
    var remainingData: String?
    var expirationDate: String?
    var domain: String?
    var _configs: [ProxyConfig] = []

    _configs.reserveCapacity(configs.count)
    configs.forEach { (config) in
      if config.id.hasPrefix("剩余流量") {
        remainingData = Self.clearChineseInput(config.id.dropFirst(4))
      } else if config.id.hasPrefix("过期时间") {
        expirationDate = Self.clearChineseInput(config.id.dropFirst(4))
      } else if config.id.hasPrefix("最新域名") {
        domain = Self.clearChineseInput(config.id.dropFirst(4))
      } else {
        _configs.append(config)
      }
    }

    self.metadata = .init(remainingData: remainingData, expirationDate: expirationDate, domain: domain)
    self.configs = _configs
  }
}

public enum ProxySubscriptionType: String, Codable, CaseIterable, Identifiable {
  case surge
  case ssr
  case plain
  case ssd
  case vmess
  case clash

  private static let jsonDecoder = JSONDecoder()
  private static let yamlDecoder = YAMLDecoder()

  public var id: Self { self }

  public func decode(_ data: Data) -> [ProxyConfig] {
    switch self {
    case .plain:
      return ProxyURIParser.parse(subsription: data)
    case .ssd:
      let str = data.utf8String
      guard str.starts(with: "ssd://") else {
        return []
      }

      guard let decoded = String(str.dropFirst(6)).base64URLDecoded else {
        return []
      }

      guard let ssd: SSD = try? Self.jsonDecoder.kwiftDecode(from: decoded) else {
        return []
      }
      //        dump(ssd)
      return ssd.configs.map {ProxyConfig.ss($0)}
    case .ssr:
      return ProxyURIParser.parse(subsription: data)
    case .surge:
      let confString = data.utf8String
      let lines = confString.split(separator: "\n").filter { !$0.isBlank }
      return lines.compactMap { (str) -> ProxyConfig? in
        if let p = SurgeShadowsocksProxy(String(str)) {
          return .ss(p.ssconf)
        }
        return nil
      }
    case .clash:
      do {
        struct _ClashProxyConfig: Decodable {
          var proxies: [ClashProxy]?
        }
        let decoded = try Self.yamlDecoder.decode(_ClashProxyConfig.self, from: String(decoding: data, as: UTF8.self), userInfo: .init())
        return decoded.proxies?.compactMap { (clashProxy) -> ProxyConfig? in
          switch clashProxy {
          case .vmess(let vmess):
            return .init(vmess)
          case .ssr(let ssr):
          return .init(ssr)
          default: break
          }
          return nil
        } ?? []
      } catch {
        #if DEBUG
        print("Failed to decode clash config, error: \(error)")
        #endif
        return []
      }
    case .vmess:
      return ProxyURIParser.parse(subsription: data)
    }
  }
}

public final class ProxySubscriptionCache: ProxyProvidable {
  public let configuration: ProxySubscriptionConfiguration
  public let cachePath: URL
  public let mmdb: MaxMindDB?
  private let session: URLSession

  private static let updateQueue = DispatchQueue(label: "ProxySubscriptionCache")

  public private(set) var proxies: [Proxy] {
    didSet {
      // save to cache file
      //            Log.info("Saving cache for \(sourceURL)")

      do {
        let fileData = proxies.map{ $0.config.uri }.joined(separator: "\n").data(using: .utf8)!
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
    startUpdate()
  }

  public func startUpdate() {
    let updateResult = session.syncResultTask(with: configuration.url)
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
    Self.updateQueue.asyncAfter(deadline: .now() + .seconds(3600), execute: startUpdate)
  }

}
