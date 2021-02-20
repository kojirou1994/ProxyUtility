import Foundation

enum SurgeConfigParser {
  static func parse(full: String) -> (String, SurgeProxyType, [String])? {
    guard let separator = full.firstIndex(of: "=") else {
      return nil
    }
    let id = full[..<full.index(before: separator)].replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: ",", with: "_")
    let proxyDescription = full[full.index(after: separator)...]
    let arguments = proxyDescription.components(separatedBy: ",").map({ $0.trimmingCharacters(in: .whitespaces) })
    if id.isEmpty || arguments.count == 0 || id.contains("账号") {
      return nil
    }
    guard let type = SurgeProxyType(rawValue: arguments[0]) else {
      return nil
    }

    return (id, type, Array(arguments[1...]))
  }
}
