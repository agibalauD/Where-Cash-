import XCTest
@testable import WhereCash

final class AnalyticsPeriodTests: XCTestCase {
    func testIncludesAllDatesBeforeFirstReset() {
        XCTAssertTrue(
            AnalyticsPeriod.includes(
                Date(timeIntervalSince1970: 100),
                startTimestamp: 0
            )
        )
    }

    func testArchivesOnlyDatesBeforeReset() {
        let resetTimestamp = 1_000.0

        XCTAssertTrue(
            AnalyticsPeriod.isArchived(
                Date(timeIntervalSince1970: 999),
                startTimestamp: resetTimestamp
            )
        )
        XCTAssertFalse(
            AnalyticsPeriod.isArchived(
                Date(timeIntervalSince1970: 1_000),
                startTimestamp: resetTimestamp
            )
        )
        XCTAssertTrue(
            AnalyticsPeriod.includes(
                Date(timeIntervalSince1970: 1_001),
                startTimestamp: resetTimestamp
            )
        )
    }
}
