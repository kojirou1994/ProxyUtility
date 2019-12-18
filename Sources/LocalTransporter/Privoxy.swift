import Foundation

public enum LocalHttpProxyService {
    @available(*, unavailable)
    case polipo
    
    case privoxy
}

public protocol LocalSocks5ToHttpProxy {
    init(socks5Port: Int, httpPort: Int)
}

internal func terminate(process: Process) {
    #if os(macOS)
    if process.isRunning {
        process.terminate()
    }
    #else
    kill(process.processIdentifier, SIGTERM)
    #endif
}

public final class Privoxy: LocalSocks5ToHttpProxy {
    
    private let process: Process
    
    public init(socks5Port: Int, httpPort: Int) {
//        #if DEBUG
        process = Process()
//        Log.info("Debug mode so not launch")
//        #else
//        process = try! AnyExecutable(executableName: "privoxy", arguments: ["--no-daemon", try TempConfigManager.shared.savePrivoxy(socks5Port: socks5Port, httpPort: httpPort).path]).generateProcess()
        #if os(macOS)
        process.standardError = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        #endif
        try! process.run()
//        #endif
    }
    
    deinit {
        terminate(process: process)
    }
}

@available(*, unavailable)
public final class Polipo: LocalSocks5ToHttpProxy {
    
    private let process: Process
    
    public init(socks5Port: Int, httpPort: Int) {
        #if DEBUG
        process = Process()
//        Log.info("Debug mode so not launch")
        #else
        process = .init()
            /*
            try! AnyExecutable(executableName: "polipo", arguments: [
            "socksParentProxy=127.0.0.1:\(socks5Port)",
            "proxyAddress=0.0.0.0",
            "proxyPort=\(httpPort)"]).generateProcess()
        */
        process.standardError = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        try! process.run()
        #endif
    }
    
    deinit {
        terminate(process: process)
    }
}
