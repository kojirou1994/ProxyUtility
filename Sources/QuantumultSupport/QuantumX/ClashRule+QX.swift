import ClashSupport
import ProxyRule

extension ClashConfig {
  public var filterLocalQXLines: String {
    let parsedRules = (rules ?? []).compactMap { ruleString -> [String]? in
      if let rule = Rule.parse(ruleString) {
        return rule.generateConfigLines(for: .quantumult)
      } else {
        print("Invalid rule line: \(ruleString), submit it.")
        return nil
      }
    }.joined()
    
    return parsedRules.joined(separator: "\n")
  }
}
