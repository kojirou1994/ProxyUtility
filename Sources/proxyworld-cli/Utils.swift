import SystemPackage
import ArgumentParser

#if compiler(>=6.0)
extension FilePath: @retroactive ExpressibleByArgument {
  public init?(argument: String) {
    self.init(argument)
  }
}
#else
extension FilePath: ExpressibleByArgument {
  public init?(argument: String) {
    self.init(argument)
  }
}
#endif
