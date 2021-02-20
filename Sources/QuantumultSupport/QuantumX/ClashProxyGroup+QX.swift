import ClashSupport

extension ClashConfig {
  public var policyQXLines: String {
    var lines = [String]()
    proxyGroups?.forEach { proxyGroup in
      var parts = [String]()
      switch proxyGroup.type {
      case .select:
        parts.append("static=\(proxyGroup.name)")
        parts.append(contentsOf: proxyGroup.proxies)
      case .fallback:
        parts.append("available=\(proxyGroup.name)")
        parts.append(contentsOf: proxyGroup.proxies)
      case .urlTest:
        parts.append("url-latency-benchmark=\(proxyGroup.name)")
        parts.append(contentsOf: proxyGroup.proxies)
      default:
        return
      }
      lines.append(parts.joined(separator: ", "))
    }
    return lines.joined(separator: "\n")
  }
}
