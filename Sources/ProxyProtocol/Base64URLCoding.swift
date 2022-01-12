import Foundation
@_exported import ExtrasBase64

extension String {

  @inlinable
  public var base64URLDecoded: [UInt8]? {
    try? Base64.decode(string: self, options: [.base64UrlAlphabet, .omitPaddingCharacter])
  }

}
