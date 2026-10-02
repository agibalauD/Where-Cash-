import XCTest
@testable import WhereCash

final class MonthUtilitiesTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testCurrentMonthCountsFullDaysAfterToday() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 1))!
        XCTAssertEqual(MonthUtilities.dayCountValue(for: now, now: now, calendar: calendar), 30)

        let lastDay = calendar.date(from: DateComponents(year: 2026, month: 10, day: 31))!
        XCTAssertEqual(MonthUtilities.dayCountValue(for: lastDay, now: lastDay, calendar: calendar), 0)
    }

    func testPastLeapFebruaryShowsMonthLength() {
        let month = calendar.date(from: DateComponents(year: 2024, month: 2, day: 1))!
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 1))!
        XCTAssertEqual(MonthUtilities.dayCountValue(for: month, now: now, calendar: calendar), 29)
    }

    func testCannotNavigateIntoFutureMonth() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 1))!
        XCTAssertFalse(MonthUtilities.canMoveToNextMonth(now, now: now, calendar: calendar))

        let previous = MonthUtilities.previousMonth(from: now, calendar: calendar)
        XCTAssertTrue(MonthUtilities.canMoveToNextMonth(previous, now: now, calendar: calendar))
    }
}
