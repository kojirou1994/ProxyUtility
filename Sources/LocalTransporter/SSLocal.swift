import Dispatch
import Foundation
import ProxyUtility
import ProxyProtocol
import Executable
import KwiftExtension

public class ProxyLocalClient {
    
    public let id: String
    
    public let serverIp: String
    
    public let country: String
    
    public let localPort: Int
    
    public let type: LocalType
    
    private let process: Process
    
    private let httpProxy: LocalSocks5ToHttpProxy?
    
    public private(set) var latency: ProxyLatency
    
    public func resetLatency() { latency = .untested }
    
    public func testLatency(url: URL = URL.init(string: "https://www.google.com")!) {
        latency = try! .test(socks5Port: localPort, method: .urlsession)
    }
    
    public init(proxy: ComplexProxyProtocol, http: LocalHttpProxyService?, serverIp: String, country: String) {
        self.serverIp = serverIp
        self.country = country
        type = proxy.localType
        latency = .untested
//        Log.info("Starting SSLocal \(proxy.id)...")
        id = proxy.id
        localPort = proxy.localPort
        process = try! AnyExecutable(executableName: proxy.localExecutable, arguments: proxy.localArguments(configPath: TempConfigManager.shared.save(proxy).path)).generateProcess()
        #if os(macOS)
        process.standardError = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        #endif
        try! process.run()
        
        switch http {
//        case .polipo:
//            httpProxy = Polipo.init(socks5Port: proxy.localPort, httpPort: proxy.localPort+600)
        case .privoxy?:
            httpProxy = Privoxy.init(socks5Port: proxy.localPort, httpPort: proxy.localPort+600)
        case .none:
            httpProxy = nil
        }
    }
    
    deinit {
        terminate(process: process)
    }
}


