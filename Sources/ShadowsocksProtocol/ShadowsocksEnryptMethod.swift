public enum ShadowsocksEnryptMethod: String, Codable, CaseIterable, CustomStringConvertible {
    case rc4_md5 = "rc4-md5"
    case aes_128_gcm = "aes-128-gcm"
    case aes_192_gcm = "aes-192-gcm"
    case aes_256_gcm = "aes-256-gcm"
    case aes_128_cfb = "aes-128-cfb"
    case aes_192_cfb = "aes-192-cfb"
    case aes_256_cfb = "aes-256-cfb"
    case aes_128_ctr = "aes-128-ctr"
    case aes_192_ctr = "aes-192-ctr"
    case aes_256_ctr = "aes-256-ctr"
    case camellia_128_cfb = "camellia-128-cfb"
    case camellia_192_cfb = "camellia-192-cfb"
    case camellia_256_cfb = "camellia-256-cfb"
    case bf_cfb = "bf-cfb"
    case chacha20_ietf_poly1305 = "chacha20-ietf-poly1305"
    case xchacha20_ietf_poly1305 = "xchacha20-ietf-poly1305"
    case salsa20 = "salsa20"
    case chacha20 = "chacha20"
    case chacha20_ietf = "chacha20-ietf"
    
    public var description: String {
        return rawValue
    }
}
