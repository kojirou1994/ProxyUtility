import Foundation
import KwiftExtension

public enum ProxyLatency: CustomStringConvertible {
  case untested
  case unavailable
  case available(speed: Double)

  public var description: String {
    switch self {
    case let .available(speed):
      return speed.description.prefix(4) + "s"
    case .unavailable:
      return "Unavailable"
    case .untested:
      return "Untested"
    }
  }

  public enum TestMethod {
    case curl
    case urlsession
  }

  public static func test(socks5Port: Int, method: TestMethod) throws -> ProxyLatency {
    switch method {
    case .curl:
      return .unavailable
    //            let result = try CurlLatencyTest(socks5Port: socks5Port)
    //                            .runAndCatch(checkNonZeroExitCode: true)
    //            let timeString = String(decoding: result.stdout, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    //
    //            if let time = TimeInterval(timeString) {
    //                return.available(speed: time)
    //            } else {
    //                return .unavailable
    //            }
    case .urlsession:
      #if os(macOS)
      let config = URLSessionConfiguration.ephemeral
      config.set(proxyInfo: .init(type: .socks5, host: "127.0.0.1", port: socks5Port))
      config.urlCache = nil
      let session = URLSession(configuration: config)
      let startDate = Date()
      let req = URLRequest(url: testURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
      _ = try session.syncResultTask(with: req).get()
      return .available(speed: Date().timeIntervalSince(startDate))
      #else
      return .untested
      #endif
    }
  }
}

let testURL = URL.init(string: "https://www.google.com")!

//public struct CurlLatencyTest: Executable {
//    public static let executableName = "curl"
//
//    public let arguments: [String]
//
//    public init(socks5Port: Int) {
//        arguments = [
////            "google.com/generate_204",
//            "https://www.google.com",
//            "-m", "2", "-s", "-w", "%{time_total}", "--socks5-hostname", "127.0.0.1:\(socks5Port)"]
//    }
//}
