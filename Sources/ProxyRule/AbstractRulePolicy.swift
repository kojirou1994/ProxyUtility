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
  /// select from proxy ip groups 
  case selectIpRegion

  public var id: Self { self }

  public var description: String {
    rawValue
  }
}
