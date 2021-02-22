public struct RuleProvider: Codable {
  public init(name: String, description: String, collections: [RuleCollection]) {
    self.name = name
    self.description = description
    self.collections = collections
  }

  public var name: String
  public var description: String
  public var collections: [RuleCollection]

  public func validate() throws {
    if name.isEmpty {
      throw RuleProviderError.emptyName
    }
    var collectionNames = Set<String>()
    for (index, collection) in collections.enumerated() {
      if collection.name.isEmpty {
        throw RuleProviderError.emptyCollectionName(index: index)
      }
      if !collectionNames.insert(collection.name).inserted {
        throw RuleProviderError.duplicateCollectionName(collection.name)
      }
    }
  }
}

public enum RuleProviderError: Error {
  case duplicateCollectionName(String)
  case emptyCollectionName(index: Int)
  case emptyName
}
