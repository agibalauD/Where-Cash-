import XCTest
@testable import WhereCash

final class ExpenseCalculatorTests: XCTestCase {
    func testConvertsUSDToBYN() {
        let expense = ExpenseRecord(
            amountMinor: 1_000,
            currency: .usd,
            category: .food,
            bynPerUSD: 3.2,
            rateDate: Date(),
            usedStaleRate: false
        )

        XCTAssertEqual(ExpenseCalculator.convertedMinor(expense, to: .byn), 3_200)
    }

    func testConvertsBYNToUSD() {
        let expense = ExpenseRecord(
            amountMinor: 3_200,
            currency: .byn,
            category: .transport,
            bynPerUSD: 3.2,
            rateDate: Date(),
            usedStaleRate: false
        )

        XCTAssertEqual(ExpenseCalculator.convertedMinor(expense, to: .usd), 1_000)
    }

    func testReturnsNilWhenConversionRateIsMissing() {
        let expense = ExpenseRecord(
            amountMinor: 1_000,
            currency: .usd,
            category: .purchases,
            bynPerUSD: nil,
            rateDate: nil,
            usedStaleRate: false
        )

        XCTAssertNil(ExpenseCalculator.total(for: [expense], in: .byn))
        XCTAssertEqual(ExpenseCalculator.total(for: [expense], in: .usd), 1_000)
    }

    func testBuildsTotalsForEveryCategory() {
        let expense = ExpenseRecord(
            amountMinor: 2_500,
            currency: .byn,
            category: .food,
            bynPerUSD: 3.2,
            rateDate: Date(),
            usedStaleRate: false
        )
        let totals = ExpenseCalculator.categoryTotals(for: [expense], in: .byn)

        XCTAssertEqual(totals.count, 5)
        XCTAssertEqual(totals.first(where: { $0.category == .food })?.amountMinor, 2_500)
        XCTAssertEqual(totals.first(where: { $0.category == .transport })?.amountMinor, 0)
        XCTAssertEqual(totals.first(where: { $0.category == .other })?.amountMinor, 0)
    }
}
