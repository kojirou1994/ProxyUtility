import Foundation
import ProxyRule

public struct ProxyWorldRuleGroup: Codable, Equatable, Identifiable {

  public let id: UUID
  public var name: String
  public var policy: AbstractRulePolicy
  public var nodes: [ProxyWorldRule]

  public init(name: String = "", category: AbstractRulePolicy = .direct, nodes: [ProxyWorldRule] = []) {
    self.name = name
    self.policy = category
    self.nodes = nodes
    id = .init()
  }
  //    func generateRules() -> [Rule] {
  //        var rules = nodes.flatMap {$0.rules}
  //        switch category {
  //        case .direct, .reject:
  //            for i in rules.indices {
  //                rules[i].policy = category.defaultPolicy
  //            }
  //            return rules
  //        default:
  //            return rules
  //        }
  //    }
}
