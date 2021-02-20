public enum AbstractRulePolicy: String, Codable, Equatable, CaseIterable, Identifiable, CustomStringConvertible {

  /// direct access
  case direct
  /// use main proxy
  case proxy
  /// reject access
  case reject
  /// select from proxy groups
  case select
  /// select from every single proxies
  case selectProxy

  public var id: Self { self }

  public var description: String {
    rawValue
  }
}
