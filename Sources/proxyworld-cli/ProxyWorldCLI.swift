import ArgumentParser

@main
struct ProxyWorldCLI: AsyncParsableCommand {
  static var configuration: CommandConfiguration {
    .init(
      commandName: "proxyworld-cli",
      version: "0.0.1",
      subcommands: [
        Generate.self,
        Daemon.self,
      ]
    )
  }
}
