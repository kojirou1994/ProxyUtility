import SystemPackage
import ArgumentParser

extension FilePath: ExpressibleByArgument {
  public init?(argument: String) {
    self.init(argument)
  }
}
