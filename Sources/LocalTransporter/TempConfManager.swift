import Foundation
import ProxyProtocol
import URLFileManager

public class TempConfigManager {
  public static let shared = TempConfigManager()
  
  static let tmpDir = URL(fileURLWithPath: ProcessInfo.processInfo.environment["TMPDIR"] ?? NSTemporaryDirectory()).appendingPathComponent("SSManger")
  
  private init() {
    if URLFileManager.default.fileExistance(at: TempConfigManager.tmpDir) == .directory {
      return
    }
    do {
      try FileManager.default.createDirectory(atPath: TempConfigManager.tmpDir.path, withIntermediateDirectories: false, attributes: nil)
    } catch {
      print("Can't create temp dir at: \(TempConfigManager.tmpDir)")
      exit(1)
    }
  }
  
  func save(_ config: ComplexProxyProtocol) throws -> URL {
    let target = TempConfigManager.tmpDir.appendingPathComponent("\(UUID().uuidString).txt")
    try config.jsonConfig.write(to: target)
    return target
  }
  
  //    func saveSS(config: ComplexProxyProtocol) throws -> String {
  //        let target = "\(TempConfigManager.tmpDir)/\(config.localPort)_\(config.id.safeFilename()).conf"
  //        try config.jsonConfig.write(to: URL(fileURLWithPath: target))
  //        return target
  //    }
  
  func savePrivoxy(socks5Port: Int, httpPort: Int) throws -> URL {
    let target = TempConfigManager.tmpDir.appendingPathComponent("\(UUID().uuidString).txt")
    try """
        listen-address  0.0.0.0:\(httpPort)
        forward-socks5 /  127.0.0.1:\(socks5Port) .
        """.write(to: target, atomically: true, encoding: .utf8)
    return target
  }
}
