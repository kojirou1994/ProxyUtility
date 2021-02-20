public struct SurgePolicyGroup: SurgeProxyGroupMember, LosslessStringConvertible {
  public init?(_: String) {
    return nil
  }

  public enum ProxyGroupType: String {
    case select
    case urltest = "url-test"
    case ssid
  }

  public var id: String

  var type: ProxyGroupType

  public var proxies: [String]

  public init(name: String, type: ProxyGroupType, proxies: [String]) {
    id = name
    self.type = type
    if proxies.count > 0 {
      self.proxies = proxies
    } else {
      self.proxies = ["DIRECT"]
    }
  }

  public var description: String {
    switch type {
    case .select:
      return "\(id) = \(type.rawValue), \(proxies.joined(separator: ", "))"
    case .ssid:
      return "\(id) = \(type.rawValue), default = \(proxies[0]), cellular = \(proxies[1])"
    case .urltest:
      return "\(id) = \(type.rawValue), \(proxies.joined(separator: ", ")), url = http://www.google.com/generate_204"
    }
  }

  public mutating func append(_ new: SurgeProxyGroupMember) {
    proxies.append(new.id)
  }

  public mutating func remove(_ member: SurgeProxyGroupMember) {
    while let index = proxies.firstIndex(of: member.id) {
      proxies.remove(at: index)
    }
  }
}
