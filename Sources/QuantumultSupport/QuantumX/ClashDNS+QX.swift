import ClashSupport

extension ClashConfig {

  var dnsQXLines: String {
    var lines = [String]()

    if dns?.ipv6 != true {
      lines.append("no-ipv6")
    }
    var allServers = dns?.nameserver ?? [] + (dns?.fallback ?? [])
    if allServers.isEmpty {
      allServers.append("223.5.5.5")
    }
    allServers.forEach { server in
      lines.append("server=\(server)")
    }

    hosts?.forEach { (host, address) in
      lines.append("address=\(host)/\(address)")
    }

    return lines.joined(separator: "\n")
  }
}
