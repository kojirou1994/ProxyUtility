import Foundation
import ProxyRule

public struct RuleCollectionOverridePolicy: Codable, Equatable {
  public let name: String
  public let policy: AbstractRulePolicy
}

public struct ProxyWorldRuleSubscription: Codable, Equatable, Identifiable {
  public init(id: UUID = .init(), name: String, url: String, isLocalFile: Bool, overridePolicies: [RuleCollectionOverridePolicy]) {
    self.id = id
    self.name = name
    self.url = url
    self.isLocalFile = isLocalFile
    self.overridePolicies = overridePolicies
  }

  public let id: UUID
  public let name: String
  public let url: String
  public let isLocalFile: Bool
  public var overridePolicies: [RuleCollectionOverridePolicy]

  var overridePoliciesDictionary: [String : AbstractRulePolicy]? {
    if overridePolicies.isEmpty {
      return nil
    }
    var dic = [String : AbstractRulePolicy]()
    overridePolicies.forEach { dic[$0.name] = $0.policy }
    return dic
  }
}
