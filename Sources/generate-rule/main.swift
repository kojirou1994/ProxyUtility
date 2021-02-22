import Yams
import ProxyRule
import Foundation
import KwiftExtension

let dstDir = URL(fileURLWithPath: CommandLine.arguments[1])

try FileManager.default.createDirectory(at: dstDir, withIntermediateDirectories: true, attributes: nil)

let encoder = YAMLEncoder()

func write(ruleProvider: RuleProvider) throws {
  try ruleProvider.validate()
  let ruleFileURL = dstDir
    .appendingPathComponent(ruleProvider.name.safeFilename())
    .appendingPathExtension("yaml")
  try encoder.encode(ruleProvider).write(to: ruleFileURL, atomically: true, encoding: .utf8)
}

try [nintendo, privateTracker, lan, apple].forEach(write(ruleProvider:))
