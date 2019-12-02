import XCTest
@testable import ProxyUtility
@testable import ProxySubscription

final class ProxyUtilityTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        let url = URL(string: "https://dukousubscribe.club/link/2Vr7vaawFYhOkGQD?mu=3")!
        dump(ProxyURIParser.parse(subsription: try! Data(contentsOf: url)))
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
