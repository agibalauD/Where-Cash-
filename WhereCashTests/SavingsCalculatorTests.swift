import XCTest
import SwiftData
@testable import WhereCash

final class SavingsCalculatorTests: XCTestCase {
    func testTotalsContributionsInGoalCurrency() {
        let goal = SavingsGoal(name: "Отпуск", targetMinor: 100_000, currency: .byn)
        let contributions = [
            SavingsContribution(
                goalID: goal.id,
                amountMinor: 10_000,
                currency: .byn,
                bynPerUSD: nil,
                rateDate: nil,
                usedStaleRate: false
            ),
            SavingsContribution(
                goalID: goal.id,
                amountMinor: 1_000,
                currency: .usd,
                bynPerUSD: 3.2,
                rateDate: Date(),
                usedStaleRate: false
            )
        ]

        XCTAssertEqual(SavingsCalculator.total(for: contributions, goal: goal), 13_200)
    }

    func testIgnoresContributionsForAnotherGoal() {
        let goal = SavingsGoal(name: "Ноутбук", targetMinor: 50_000, currency: .usd)
        let contribution = SavingsContribution(
            goalID: UUID(),
            amountMinor: 5_000,
            currency: .usd,
            bynPerUSD: nil,
            rateDate: nil,
            usedStaleRate: false
        )

        XCTAssertEqual(SavingsCalculator.total(for: [contribution], goal: goal), 0)
    }

    func testReturnsNilWhenCrossCurrencyRateIsMissing() {
        let goal = SavingsGoal(name: "Резерв", targetMinor: 100_000, currency: .byn)
        let contribution = SavingsContribution(
            goalID: goal.id,
            amountMinor: 1_000,
            currency: .usd,
            bynPerUSD: nil,
            rateDate: nil,
            usedStaleRate: false
        )

        XCTAssertNil(SavingsCalculator.total(for: [contribution], goal: goal))
    }

    func testContributionCanBeDeletedFromPersistentHistory() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: SavingsGoal.self,
            SavingsContribution.self,
            configurations: configuration
        )
        let context = ModelContext(container)
        let goal = SavingsGoal(name: "Резерв", targetMinor: 100_000, currency: .byn)
        let contribution = SavingsContribution(
            goalID: goal.id,
            amountMinor: 5_000,
            currency: .byn,
            bynPerUSD: nil,
            rateDate: nil,
            usedStaleRate: false
        )

        context.insert(goal)
        context.insert(contribution)
        try context.save()

        context.delete(contribution)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<SavingsContribution>())
        XCTAssertTrue(remaining.isEmpty)
    }
}
