import XCTest
@testable import LeetCodeLearner

@MainActor
final class NetworkMonitorTests: XCTestCase {

    func testNetworkMonitor_defaultsToConnected() {
        let monitor = NetworkMonitor()
        XCTAssertTrue(monitor.isConnected,
            "NetworkMonitor should default to connected on initialization")
    }
}
