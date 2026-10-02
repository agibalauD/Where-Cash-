import XCTest
@testable import WhereCash

final class AmountParserTests: XCTestCase {
    func testParsesCommaAndDot() {
        XCTAssertEqual(AmountParser.minorUnits(from: "12,50"), 1_250)
        XCTAssertEqual(AmountParser.minorUnits(from: "12.50"), 1_250)
        XCTAssertEqual(AmountParser.minorUnits(from: "12"), 1_200)
    }

    func testRejectsInvalidAndNonPositiveValues() {
        XCTAssertNil(AmountParser.minorUnits(from: ""))
        XCTAssertNil(AmountParser.minorUnits(from: "0"))
        XCTAssertNil(AmountParser.minorUnits(from: "-12"))
        XCTAssertNil(AmountParser.minorUnits(from: "12,345"))
        XCTAssertNil(AmountParser.minorUnits(from: "abc"))
    }

    func testSanitizesFreeText() {
        XCTAssertEqual(AmountParser.sanitized("abc12.345BYN"), "12,34")
        XCTAssertEqual(AmountParser.sanitized(",5"), "0,5")
    }
}
