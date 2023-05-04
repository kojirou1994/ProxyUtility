import Foundation
import ProxyWorldUtility
import KwiftExtension
import ProxySubscription
import ProxyUtility
import ClashSupport
import ProxyRule
import Yams
import ArgumentParser
import QuantumultSupport
import Precondition
import SystemPackage
import SystemUp
import TSCExecutableLauncher

enum ConfigFormat: String, ExpressibleByArgument, CaseIterable {
  case clash
  case qx
  case qxServer
  case qxFilter

  var fileExtension: String {
    switch self {
    case .clash: return "yaml"
    default: return "txt"
    }
  }
}

struct GroupNameGenerateOptions: ParsableArguments {
  @Option
  var ruleGroupName: String = "[RULE] %s"

  @Option
  var urlTestGroupName: String = "[BEST] %s"

  @Option
  var fallbackGroupName: String = "[FALLBACK] %s"

  func toInternal() throws -> ProxyWorldConfiguration.GenerateOptions {
    try .init(ruleGroupNameFormat: ruleGroupName, urlTestGroupNameFormat: urlTestGroupName, fallbackGroupNameFormat: fallbackGroupName)
  }
}

struct NetworkOptions: ParsableArguments {
  @Option
  var retryLimit: UInt = 2

  @Flag
  var tryDirect: Bool = true

  var toInternal: Manager.NetworkOptions {
    .init(retryLimit: retryLimit, tryDirectConnect: tryDirect)
  }
}

struct Generate: AsyncParsableCommand {

  @Option(name: .shortAndLong, help: "Available: \(ConfigFormat.allCases.map(\.rawValue).joined(separator: ", "))")
  var format: ConfigFormat

//  @Flag(name: [.customShort("c"), .customLong("continue")],help: "Continue on network error")
//  var continueOnError: Bool = false

  @Flag
  var overwrite: Bool = false

  @Flag(name: .shortAndLong)
  var verbose: Bool = false

  @OptionGroup(title: "NAME GENERATION")
  var options: GroupNameGenerateOptions

  @OptionGroup(title: "NETWORK")
  var networkOptions: NetworkOptions

  @Argument
  var configPath: FilePath

  @Argument(help: "Output root directory")
  var outputDirectory: FilePath

  func run() async throws {

    let manager = try Manager(configPath: configPath, networkOptions: networkOptions.toInternal, options: options.toInternal())

    _ = try await manager.updateCaches()

    var baseConfig = ClashConfig(mode: .rule)
    baseConfig.profile?.storeSelected = true

    let results = await manager.generateClashConfigs(baseConfig: baseConfig)

    let configEncoder = YAMLEncoder()
    configEncoder.options.allowUnicode = true
    configEncoder.options.sortKeys = true

    let test: Bool
    do {
      try Clash.validate()
      test = true
    } catch {
      test = false
    }

    for (instanceConfig, clashConfig) in results {

      let ouptutFilename = "\(instanceConfig.name.isEmpty ? instanceConfig.id.uuidString : instanceConfig.name).\(format.fileExtension)"
      let outputPath = outputDirectory.appending(ouptutFilename)

      print("Writing to file: \(outputPath)")

      do {

        let outputString: String
        switch format {
        case .clash:
          outputString = try configEncoder.encode(clashConfig)
        case .qx:
          outputString = clashConfig.quantumultXConfig
        case .qxServer:
          outputString = clashConfig.serverLocalQXLines
        case .qxFilter:
          outputString = clashConfig.filterLocalQXLines
        }

        let outputFD = try FileDescriptor.open(outputPath, .writeOnly, options: overwrite ? [.create, .truncate] : [.create, .exclusiveCreate], permissions: .fileDefault)
        try outputFD.closeAfter {
          _ = try outputFD.writeAll(outputString.utf8)
        }

        if test {
          print("Test config...")
          try Clash(configurationFile: outputPath.string, test: true)
            .launch(use: TSCExecutableLauncher(outputRedirection: .none), options: .init(checkNonZeroExitCode: false))
        }
      } catch {
        print("Write failed: \(error)")
        _ = FileSyscalls.unlink(.absolute(outputPath))
      }

      print()
    }


  }
}
