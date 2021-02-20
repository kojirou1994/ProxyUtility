import Foundation

public struct SurgeDirectProxy {
  public var id: String

  public static let direct = SurgeDirectProxy(alias: "DIRECT")

  public init(alias: String) {
    id = alias
  }
}

extension SurgeDirectProxy: SurgeProxy {
  public init?(_ description: String) {
    guard let parsed = SurgeConfigParser.parse(full: description),
          parsed.1 == .direct,
          parsed.2.count == 0 else {
      return nil
    }
    id = parsed.0
  }

  public var type: SurgeProxyType {
    .direct
  }
}
