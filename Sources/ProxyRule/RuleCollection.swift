public struct RuleCollection: Codable {
  public init(name: String, description: String, rules: [RuleInfo], recommendedPolicy: AbstractRulePolicy) {
    self.name = name
    self.description = description
    self.rules = rules
    self.recommendedPolicy = recommendedPolicy
  }

  public var name: String
  public var description: String
  public var rules: [RuleInfo]
  public var recommendedPolicy: AbstractRulePolicy
}
