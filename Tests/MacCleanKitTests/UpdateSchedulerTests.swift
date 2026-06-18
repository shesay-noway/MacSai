import XCTest
@testable import MacCleanKit

final class UpdateSchedulerTests: XCTestCase {

    // MARK: - isCheckDue

    func testCheckDueWhenNeverChecked() {
        XCTAssertTrue(UpdateScheduler.isCheckDue(now: Date(), lastCheck: nil, interval: 86_400))
    }

    func testCheckDueAfterInterval() {
        let now = Date(timeIntervalSinceReferenceDate: 200_000)
        let last = now.addingTimeInterval(-90_000) // older than 86_400
        XCTAssertTrue(UpdateScheduler.isCheckDue(now: now, lastCheck: last, interval: 86_400))
    }

    func testNotDueWithinInterval() {
        let now = Date(timeIntervalSinceReferenceDate: 200_000)
        let last = now.addingTimeInterval(-1_000)
        XCTAssertFalse(UpdateScheduler.isCheckDue(now: now, lastCheck: last, interval: 86_400))
    }

    func testDueAtExactInterval() {
        let now = Date(timeIntervalSinceReferenceDate: 200_000)
        let last = now.addingTimeInterval(-86_400)
        XCTAssertTrue(UpdateScheduler.isCheckDue(now: now, lastCheck: last, interval: 86_400))
    }
}
