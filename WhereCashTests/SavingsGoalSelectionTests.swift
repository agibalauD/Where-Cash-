import XCTest
@testable import WhereCash

final class SavingsGoalSelectionTests: XCTestCase {
    private let firstID = UUID(uuidString: "0F501825-970E-4A78-9943-8BD88E506B86")!
    private let secondID = UUID(uuidString: "172FFB8D-CB63-4E26-A0AE-2AA17135671D")!
    private let thirdID = UUID(uuidString: "74A8C428-4D55-45F6-A365-551D29A31028")!

    func testReadsLegacySingleGoalValue() {
        XCTAssertEqual(
            SavingsGoalSelection.ids(from: firstID.uuidString),
            [firstID]
        )
    }

    func testStoresAndReadsTwoGoalsInOrder() {
        let storedValue = SavingsGoalSelection.storedValue(for: [secondID, firstID])

        XCTAssertEqual(
            SavingsGoalSelection.ids(from: storedValue),
            [secondID, firstID]
        )
    }

    func testLimitsSelectionToTwoUniqueGoals() {
        let storedValue = SavingsGoalSelection.storedValue(
            for: [firstID, firstID, secondID, thirdID]
        )

        XCTAssertEqual(
            SavingsGoalSelection.ids(from: storedValue),
            [firstID, secondID]
        )
    }
}
