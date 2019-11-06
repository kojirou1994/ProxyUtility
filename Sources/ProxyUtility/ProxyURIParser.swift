import Foundation
import ShadowsocksProtocol
import V2RayProtocol

// https://shadowsocks.org/en/spec/SIP002-URI-Scheme.html

public struct ProxyURIParser {
//    public static func parse(_ data: Data) -> Shadowsocks? {
//        guard let string = String(data: data, encoding: .utf8) else {
//            return nil
//        }
//        return ProxyURIParser.parse(uri: string)
//    }

    public static func parse(uri: String) -> ProxyConfig? {
        guard let url = URLComponents(string: uri) else {
            return nil
        }
        if url.scheme == "ss" {
            if let host = url.host,
                let decodedString = host.base64URLDecoded {
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
                guard let port = Int(part2[1]) else {
                    return nil
                }
                return .ss(.local(id: "", server: String(host), serverPort: port,
                                    password: String(password), method: method, plugin: nil))
            } else {
                // ss scheme
                // SS-URI = ss://" userinfo "@" hostname ":" port [ "/" ] [ "?" plugin ] [ "#" tag ]
                // userinfo = websafe-base64-encode-utf8(method  ":" password)

                guard let userinfo = url.user?.base64URLDecoded,
                    let host = url.host, let port = url.port else {
                    return nil
                }
                let parts = userinfo.split(separator: ":")
                guard let method = ShadowsocksEnryptMethod.init(rawValue: String(parts[0])) else {
                    return nil
                }
                let password = parts[1]

//                let (plugin, plugin_opts): (String, String)
                let plugin: ShadowsocksPlugin?
                if let pluginParts = url.queryItems?["plugin"]?.removingPercentEncoding?.split(separator: ";", maxSplits: 1) {
                    let pluginName = String(pluginParts[0])
                    plugin = ShadowsocksPlugin.init(type: .local, plugin: pluginName, pluginOpts: pluginParts[1])
                } else {
                    plugin = nil
                }
                return .ss(.local(id: url.fragment?.replacingOccurrences(of: "\n", with: "") ?? String(host), server: String(host), serverPort: port, password: String(password), method: method, plugin: plugin))
            }
        } else if url.scheme == "ssr", let host = url.host, let content = host.base64URLDecoded {
            // ssr://base64(host:port:protocol:method:obfs:base64pass/?obfsparam=base64param&protoparam=base64param&remarks=base64remarks&group=base64group&udpport=0&uot=0)
            let parts = content.split(separator: "/")
            let part1 = parts[0].split(separator: ":")
            guard part1.count == 6 else {
//                Log.debug("Invalid uri: \(content)")
                return nil
            }
            let host = String(part1[0])
            let protoc = String(part1[2])
            guard let method = ShadowsocksEnryptMethod.init(rawValue: String(part1[3])) else {
                return nil
            }
            let obfs = String(part1[4])
            let password = String(part1[5]).base64URLDecoded!

            guard let port = Int(part1[1]) else {
//                Log.debug("Invalid port: \(part1[1]) from uri: \(content)")
                return nil
            }
            if parts.count > 1, let part2 = URLComponents(string: String(parts[1])) {
                let obfsparam = part2.queryItems?["obfsparam"]?.base64URLDecoded
                let protoparam = part2.queryItems?["protoparam"]?.base64URLDecoded
                let remarks = part2.queryItems?["remarks"]?.base64URLDecoded?.replacingOccurrences(of: "\n", with: "") ?? host
                let group = part2.queryItems?["group"]?.base64URLDecoded
//                let udpport = part2.queryItems?["udpport"]
//                let uot = part2.queryItems?["uot"]

                return .ssr(.init(id: remarks, group: group, server: host, server_port: port, password: password, method: method, protocol: protoc, proto_param: protoparam, obfs: obfs, obfs_param: obfsparam))
            } else {
                return .ssr(.init(id: host, server: host, server_port: port, password: password, method: method, protocol: protoc, obfs: obfs))
            }
        } else if url.scheme == "vmess", let host = url.host, let content = host.base64URLDecoded {
            return try? .vmess(JSONDecoder().decode(VMess.self, from: Data(content.utf8)))
        } else {
            return nil
        }
    }

    public static func parse(subsription data: Data) -> [ProxyConfig] {
        if let decodedData = Data(base64Encoded: data),
            let decodedString = String(data: decodedData,
                                       encoding: .utf8) {
            // official SSR sub
            let parsed = decodedString
                .components(separatedBy: .newlines)
                .compactMap(ProxyURIParser.parse)
            return parsed
        }
        if let encodedString = String(data: data, encoding: .utf8),
            let decodedData = Data(base64URLEncoded: encodedString),
            let decodedString = String(data: decodedData,
                                       encoding: .utf8) {
            // official SSR sub
            let parsed = decodedString
                .components(separatedBy: .newlines)
                .compactMap(ProxyURIParser.parse)
            return parsed
        }
        if let str = String(data: data, encoding: .utf8) {
            // plain SS sub
            let lines = str.components(separatedBy: .whitespacesAndNewlines)
            let parsed = lines.compactMap(ProxyURIParser.parse)
            return parsed
        }
        return []
    }
}

extension Array where Element == URLQueryItem {
    subscript(_ name: String) -> String? {
        return first { $0.name == name }?.value
    }
}
