import Foundation
import ProxyProtocol
import ShadowsocksProtocol
import V2RayProtocol
import ClashSupport

// https://shadowsocks.org/en/spec/SIP002-URI-Scheme.html

public struct ProxyURIParser {

  // TODO: provide extra info: server name if none, is udp enabled by default
  public static func parse(uri: String) -> ProxyConfig? {
    // ss or ssr or trojan
    if let url = URLComponents(string: uri) {
      if url.scheme == "ss" {
        if let host = url.host,
          let decodedString = try? host.base64decoded(options: .base64UrlAlphabet).utf8String
        {
          // legacy ss scheme
          // ss://method:password@host:port

          let parts = decodedString.split(separator: "@")
          let part1 = parts[0].split(separator: ":")
          let part2 = parts[1].split(separator: ":")
          guard let method = ShadowsocksEnryptMethod.init(rawValue: String(part1[0])) else {
            return nil
          }
          let password = part1[1]
          let host = part2[0]
          guard let port = Int(part2[1]) else { return nil }
          return .ss(
            .local(
              id: "", server: String(host), serverPort: port, password: String(password),
              method: method, mode: .both, plugin: nil))
        } else {
          // ss scheme
          // SS-URI = ss://" userinfo "@" hostname ":" port [ "/" ] [ "?" plugin ] [ "#" tag ]
          // userinfo = websafe-base64-encode-utf8(method  ":" password)

          guard let user = url.user,
            let userinfo = try? user.base64decoded(options: .base64UrlAlphabet).utf8String,
            let host = url.host, let port = url.port
          else { return nil }
          let parts = userinfo.split(separator: ":")
          guard let method = ShadowsocksEnryptMethod(rawValue: String(parts[0])) else {
            return nil
          }
          let password = parts[1]

          let plugin: ShadowsocksPlugin?
          if let pluginParts = url.queryItems?["plugin"]?.removingPercentEncoding?.split(
            separator: ";", maxSplits: 1) {
            let pluginName = String(pluginParts[0])
            plugin = ShadowsocksPlugin(
              type: .local, plugin: pluginName, pluginOpts: pluginParts[1])
          } else {
            plugin = nil
          }
          return .ss(
            .local(
              id: url.fragment?.replacingOccurrences(of: "\n", with: "") ?? String(host),
              server: String(host), serverPort: port, password: String(password), method: method,
              mode: .both, plugin: plugin))
        }
      } else if url.scheme == "ssr", let host = url.host,
        let content = host.base64URLDecoded?.utf8String {
        // ssr://base64(host:port:protocol:method:obfs:base64pass/?obfsparam=base64param&protoparam=base64param&remarks=base64remarks&group=base64group&udpport=0&uot=0)
        let parts = content.split(separator: "/")
        let leftParts = parts[0].split(separator: ":").map(String.init)
        guard leftParts.count == 6 else {
          return nil
        }
        let host = leftParts[0]

        guard let method = ShadowsocksEnryptMethod(rawValue: leftParts[3]),
              let obfs = ShadowsocksRConfig.Obfs(rawValue: leftParts[4]),
              let protoc = ShadowsocksRConfig.Protocols(rawValue: leftParts[2]),
              let password = leftParts[5].base64URLDecoded?.utf8String else {
          return nil
        }

        guard let port = Int(leftParts[1]) else {
          return nil
        }

        if parts.count > 1, let part2 = URLComponents(string: String(parts[1])) {
          let queryItems = part2.queryItems ?? []
          let obfsparam = queryItems["obfsparam"]?.base64URLDecoded?.utf8String
          let protoparam = queryItems["protoparam"]?.base64URLDecoded?.utf8String
          let remarks = queryItems["remarks"]?.base64URLDecoded?.utf8String.replacingOccurrences(
            of: "\n", with: "")
          let group = queryItems["group"]?.base64URLDecoded?.utf8String
          //                let udpport = part2.queryItems?["udpport"]
          //                let uot = part2.queryItems?["uot"]

          return .ssr(
            .init(
              id: remarks ?? host, group: group, server: host, server_port: port,
              password: password, method: method, protocol: protoc, proto_param: protoparam,
              obfs: obfs, obfs_param: obfsparam))
        } else {
          return .ssr(
            .init(
              id: host, server: host, server_port: port, password: password, method: method,
              protocol: protoc, obfs: obfs))
        }
      } else if url.scheme == "trojan",
                let host = url.host, let port = url.port,
                let password = url.user {
        // trojan://password@host:port?allowInsecure=[bool]&peer=[string]&sni=[string][ "#" tag ]
        let sni = url.queryItems?.first(where: { $0.name == "sni "})?.value
        let allowInsecure = url.queryItems?.first(where: { $0.name == "allowInsecure"})?.value
        assert(allowInsecure == "0" || allowInsecure == "1")
        let node = ClashProxy.Trojan.init(name: url.fragment ?? host, server: host, port: port, password: password, udp: nil, sni: sni, alpn: nil, skipCertVerify: allowInsecure == "1", network: nil, grpcOptions: nil, wsOptions: nil)
        return .clash(.trojan(node))
      }
    }
    if uri.starts(with: "vmess://"), case let body = String(uri.dropFirst(8)),
       let content = try? Base64.decode(string: body, options: [.omitPaddingCharacter]) {
      do {
        return try .vmess(JSONDecoder().kwiftDecode(from: content))
      } catch {
        #if DEBUG
        print("Failed to decode vmess, error: \(error)")
        #endif
        return nil
      }
    }
    return nil
  }

  public static func parse(subsription data: Data) -> [ProxyConfig] {
    let decodedString: String
    if let parsed = try? Base64.decode(bytes: data, options: [.omitPaddingCharacter]).utf8String {
      // official SSR sub
      decodedString = parsed
    } else if let parsed = try? Base64.decode(bytes: data, options: [.omitPaddingCharacter, .base64UrlAlphabet]).utf8String {
      // official SSR sub
      decodedString = parsed
    } else {
      // plain SS sub
      decodedString = data.utf8String
    }
    return decodedString
      .components(separatedBy: .newlines)
      .compactMap { ProxyURIParser.parse(uri: $0) }
  }
}

extension Array where Element == URLQueryItem {
  @inlinable subscript(_ name: String) -> String? { first { $0.name == name }?.value }
}
