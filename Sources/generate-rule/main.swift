import Yams
import ProxyRule
import Foundation
import KwiftExtension

let dstDir = URL(fileURLWithPath: #filePath)
  .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
  .appendingPathComponent("Rules")

try? FileManager.default.removeItem(at: dstDir)
try FileManager.default.createDirectory(at: dstDir, withIntermediateDirectories: true, attributes: nil)

let encoder = YAMLEncoder()

func write(rule: RuleProvider) throws {
  try encoder.encode(rule).write(to: dstDir.appendingPathComponent(rule.name.safeFilename()).appendingPathExtension("yaml"), atomically: true, encoding: .utf8)
}

try [nintendo, privateTracker, lan, apple].forEach(write(rule:))
