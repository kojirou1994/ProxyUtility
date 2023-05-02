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
import SystemPackage

enum ConfigFormat: String, ExpressibleByArgument, CaseIterable {
  case clash
  case qx
  case qxServer
  case qxFilter
}

struct GroupNameGenerateOptions: ParsableArguments {
  @Option
  var ruleGroupName: String = "[RULE] %s"

  @Option
  var urlTestGroupName: String = "[BEST] %s"

  @Option
  var fallbackGroupName: String = "[FALLBACK] %s"
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

  @Argument
  var configPath: FilePath

  @Argument
  var outputPath: FilePath

  func run() async throws {
    let outputFD = try FileDescriptor.open(outputPath, .writeOnly, options: overwrite ? [.create, .truncate] : [.create, .exclusiveCreate], permissions: .fileDefault)
    defer { try? outputFD.close() }

    let manager = try Manager(configPath: configPath)

    try await manager.refresh()

    let clashConfig = await manager.generateClash(
      baseConfig: ClashConfig(mode: .rule),
      mode: .rule,
//      tailDirectRules: Rule.normalLanRules,
      ruleGroupPrefix: "[RULE] ",
      urlTestGroupPrefix: "[BEST] ",
      fallbackGroupPrefix: "[FALLBACK] ") { _ in nil }

    let outputString: String
    switch format {
    case .clash:
      outputString = try YAMLEncoder().encode(clashConfig)
    case .qx:
      outputString = clashConfig.quantumultXConfig
    case .qxServer:
      outputString = clashConfig.serverLocalQXLines
    case .qxFilter:
      outputString = clashConfig.filterLocalQXLines
    }

    print("Writing...")
    try outputFD.writeAll(outputString.utf8)
  }
}
