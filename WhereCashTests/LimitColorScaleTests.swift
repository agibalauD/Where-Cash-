import XCTest
@testable import WhereCash

final class LimitColorScaleTests: XCTestCase {
    func testUsesExpectedAnchorColors() {
        let start = LimitColorScale.components(for: 0)
        let thirty = LimitColorScale.components(for: 0.3)
        let fifty = LimitColorScale.components(for: 0.5)
        let eighty = LimitColorScale.components(for: 0.8)

        XCTAssertEqual(start.red, 0.345, accuracy: 0.001)
        XCTAssertEqual(thirty.blue, 1.0, accuracy: 0.001)
        XCTAssertEqual(fifty.red, 1.0, accuracy: 0.001)
        XCTAssertEqual(fifty.green, 0.8, accuracy: 0.001)
        XCTAssertEqual(eighty.green, 0.231, accuracy: 0.001)
    }

    func testCapsColorAtRedAfterEightyPercent() {
        XCTAssertEqual(
            LimitColorScale.components(for: 0.8),
            LimitColorScale.components(for: 1.4)
        )
    }
}
