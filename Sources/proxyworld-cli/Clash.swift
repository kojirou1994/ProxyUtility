import ExecutableDescription

public struct Clash: Executable {
  public init(configurationDirectory: String? = nil, externalControllerAddress: String? = nil, externalUIDirectory: String? = nil, configurationFile: String? = nil, secret: String? = nil, test: Bool = false) {
    self.configurationDirectory = configurationDirectory
    self.externalControllerAddress = externalControllerAddress
    self.externalUIDirectory = externalUIDirectory
    self.configurationFile = configurationFile
    self.secret = secret
    self.test = test
  }

  public static var executableName: String { "clash" }

  public var configurationDirectory: String?

  /// override external controller address
  public var externalControllerAddress: String?

  /// override external ui directory
  public var externalUIDirectory: String?

  public var configurationFile: String?

  /// override secret for RESTful API
  public var secret: String?

  public var test: Bool

  public var arguments: [String] {
    var result = [String]()

    [
      (configurationDirectory, "-d"),
      (externalControllerAddress, "-ext-ctl"),
      (externalUIDirectory, "-ext-ui"),
      (configurationFile, "-f"),
      (secret, "-secret"),
    ].forEach { (value, name) in
      if let value {
        result.append(name)
        result.append(value)
      }
    }

    if test {
      result.append("-t")
    }

    return result
  }
}
