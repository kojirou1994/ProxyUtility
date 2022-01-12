import ClashSupport

extension ClashConfig {
  public var serverLocalQXLines: String {
    proxies?.map(\.quantumXLine).joined(separator: "\n") ?? ""
  }
}

extension ClashProxy {
  
  public var quantumXLine: String {
    let prefix: String
    var parameters = [String : String]()
    let serverPort = server + ":" + port.description

    var line: String {
      var result = "\(prefix)=\(serverPort)"
      parameters.forEach { (key, value) in
        result.append(", \(key)=\(value)")
      }
      result.append(", tag=\(name)")
      return result
    }

    switch self {
    case .http(let http):
      /*
       # Optional field tls13 is only for http over-tls=true
       ;http=example.com:80,fast-open=false, udp-relay=false, tag=http-01
       ;http=example.com:80, username=name, password=pwd, fast-open=false, udp-relay=false, tag=http-02
       ;http=example.com:443, username=name, password=pwd, over-tls=true, tls-host=example.com, tls-verification=true, fast-open=false, udp-relay=false, tag=http-tls-01
       ;http=example.com:443, username=name, password=pwd, over-tls=true, tls-host=example.com, tls-verification=true, tls13=true, fast-open=false, udp-relay=false, tag=http-tls-02
       */
      prefix = "http"
      parameters["username"] = http.username
      parameters["password"] = http.password
      parameters["over-tls"] = http.isTLSEnabled.description
      parameters["tls-verification"] = (http.isCertVerificationEnabled).description
    case .vmess(let vmess):
      /*
       # Optional field tls13 is only for vmess obfs=over-tls and obfs=wss
       ;vmess=example.com:80, method=none, password=23ad6b10-8d1a-40f7-8ad0-e3e35cd32291, fast-open=false, udp-relay=false, tag=vmess-01
       ;vmess=example.com:80, method=aes-128-gcm, password=23ad6b10-8d1a-40f7-8ad0-e3e35cd32291, fast-open=false, udp-relay=false, tag=vmess-02
       ;vmess=example.com:443, method=none, password=23ad6b10-8d1a-40f7-8ad0-e3e35cd32291, obfs=over-tls, fast-open=false, udp-relay=false, tag=vmess-tls-01
       ;vmess=192.168.1.1:443, method=none, password=23ad6b10-8d1a-40f7-8ad0-e3e35cd32291, obfs=over-tls, obfs-host=example.com, fast-open=false, udp-relay=false, tag=vmess-tls-02
       ;vmess=192.168.1.1:443, method=none, password=23ad6b10-8d1a-40f7-8ad0-e3e35cd32291, obfs=over-tls, obfs-host=example.com, tls13=true, fast-open=false, udp-relay=false, tag=vmess-tls-03
       ;vmess=example.com:80, method=chacha20-poly1305, password=23ad6b10-8d1a-40f7-8ad0-e3e35cd32291, obfs=ws, obfs-uri=/ws, fast-open=false, udp-relay=false, tag=vmess-ws-01
       ;vmess=192.168.1.1:80, method=chacha20-poly1305, password=23ad6b10-8d1a-40f7-8ad0-e3e35cd32291, obfs=ws, obfs-host=example.com, obfs-uri=/ws, fast-open=false, udp-relay=false, tag=vmess-ws-02
       ;vmess=example.com:443, method=chacha20-poly1305, password=23ad6b10-8d1a-40f7-8ad0-e3e35cd32291, obfs=wss, obfs-uri=/ws, fast-open=false, udp-relay=false, tag=vmess-ws-tls-01
       ;vmess=192.168.1.1:443, method=chacha20-poly1305, password=23ad6b10-8d1a-40f7-8ad0-e3e35cd32291, obfs=wss, obfs-host=example.com, obfs-uri=/ws, fast-open=false, udp-relay=false, tag=vmess-ws-tls-02
       ;vmess=192.168.1.1:443, method=chacha20-poly1305, password=23ad6b10-8d1a-40f7-8ad0-e3e35cd32291, obfs=wss, obfs-host=example.com, obfs-uri=/ws, tls13=true, fast-open=false, udp-relay=false, tag=vmess-ws-tls-03
       */
      prefix = "vmess"
      let method: VMess.Cipher
      switch vmess.cipher {
      case .auto:
        method = .chacha20_poly1305
      default:
        method = vmess.cipher
      }
      parameters["method"] = method.rawValue
      parameters["password"] = vmess.uuid
      parameters["udp-relay"] = vmess.isUDPEnabled.description
      if let network = vmess.network {
        switch network {
        case .http:
          parameters["obfs"] = nil
        case .ws:
          parameters["obfs"] = "ws"
        default: fatalError("what?")
        }
        parameters["obfs-host"] = vmess.wsOptions?.headers?.host
        parameters["obfs-uri"] = vmess.wsOptions?.path
      }
    default:
      return "Unsupported or not implemented: \(self)"
        .components(separatedBy: .newlines)
        .map {";" + $0}.joined(separator: "\n")
    }

    return line
  }
}
