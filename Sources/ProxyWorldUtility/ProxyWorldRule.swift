import Foundation
import ProxyRule

public struct ProxyWorldRule: Codable, Equatable, Identifiable {

  public enum RuleType: String, Codable, Equatable, Identifiable, CaseIterable {
    case raw
    case file
    case providerURL
    public var id: Self {self}
  }

  public var id: UUID
  public let type: RuleType
  public let value: String

  public init(id: UUID? = nil, type: RuleType, value: String) {
    self.id = id ?? .init()
    self.type = type
    self.value = value
  }

  public init(rule: Rule) {
    self.type = .raw
    self.value = rule.description
    id = .init()
  }

  public var rules: [Rule] {
    switch type {
    case .raw:
      if let v = Rule.parse(value, allowEmptyPolicy: true) {
        return [v]
      } else {
        return []
      }
    case .file:
      return autoreleasepool {
        (try? String(contentsOfFile: value).split(separator: "\n")
          .compactMap{Rule.parse($0, allowEmptyPolicy: true)}) ?? []
      }
    case .providerURL: return []
    }
  }
}

@available(*, deprecated, renamed: "AbstractRulePolicy")
public typealias CustomRuleCategory = AbstractRulePolicy
