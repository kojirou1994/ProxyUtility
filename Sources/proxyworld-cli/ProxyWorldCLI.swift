import Foundation
import ProxyWorldUtility
import KwiftExtension
import ProxySubscription
import ProxyUtility
import URLFileManager
import ClashSupport
import ProxyRule
import Yams
import ArgumentParser
import QuantumultSupport
import Precondition

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
