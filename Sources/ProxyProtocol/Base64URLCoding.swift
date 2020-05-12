import Foundation
@_exported import Base64Kit

public extension Base64 {

  static func decodeAutoPadding<Buffer: Collection>(encoded: Buffer, options: DecodingOptions = [])
    throws -> [UInt8] where Buffer.Element == UInt8
  {
    let extraCount = encoded.count % 4
    if extraCount == 0 {
      return try decode(encoded: encoded, options: options)
    } else {
      let paddingCount = 4 - extraCount
      var data = Array(encoded)
      data.reserveCapacity(data.capacity - paddingCount)
      (0..<paddingCount).forEach { _ in data.append(UInt8(ascii: "=")) }
      return try decode(encoded: data, options: options)
    }
  }

  @inlinable
  static func decodeAutoPadding(encoded: String, options: DecodingOptions = []) throws -> [UInt8] {
    try decodeAutoPadding(encoded: encoded.utf8, options: options)
  }
}

extension String {

  @inlinable
  public var base64URLDecoded: [UInt8]? {
    try? Base64.decodeAutoPadding(encoded: self, options: .base64UrlAlphabet)
  }

}
