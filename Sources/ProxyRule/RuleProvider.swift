public struct RuleProvider: Codable {
  public init(name: String, description: String, collections: [RuleCollection]) {
    self.name = name
    self.description = description
    self.collections = collections
  }

  public var name: String
  public var description: String
  public var collections: [RuleCollection]
}
