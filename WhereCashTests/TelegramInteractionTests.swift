import XCTest
@testable import WhereCash

final class TelegramInteractionTests: XCTestCase {
    func testCurrencyCallbackRoundTrip() {
        let value = TelegramCallbackData.currency(sessionID: "ABC123", currency: .byn)
        XCTAssertEqual(TelegramCallbackData(rawValue: value.rawValue), value)
    }

    func testCategoryCallbackRoundTrip() {
        let value = TelegramCallbackData.category(sessionID: "ABC123", category: .other)
        XCTAssertEqual(TelegramCallbackData(rawValue: value.rawValue), value)
    }

    func testSavingsCategoryCallbackRoundTrip() {
        let value = TelegramCallbackData.category(sessionID: "SAVE123", category: .savings)
        XCTAssertEqual(TelegramCallbackData(rawValue: value.rawValue), value)
    }

    func testSavingsGoalCallbackRoundTrip() {
        let goalID = UUID(uuidString: "0F501825-970E-4A78-9943-8BD88E506B86")!
        let value = TelegramCallbackData.savingsGoal(sessionID: "SAVE123", goalID: goalID)
        XCTAssertEqual(TelegramCallbackData(rawValue: value.rawValue), value)
    }

    func testStatisticsCallbackRoundTrip() {
        let value = TelegramCallbackData.statistics
        XCTAssertEqual(TelegramCallbackData(rawValue: value.rawValue), value)
    }

    func testStatisticsCaptionContainsCurrentTotalsWithoutMonthNavigation() {
        let snapshot = makeStatisticsSnapshot()

        let caption = TelegramStatisticsText.caption(for: snapshot)

        XCTAssertTrue(caption.contains("Октябрь 2026"))
        XCTAssertTrue(caption.contains("125,00 BYN"))
        XCTAssertTrue(caption.contains("Лимит"))
        XCTAssertFalse(caption.contains("Сентябрь"))
        XCTAssertFalse(caption.contains("В другой валюте"))
    }

    @MainActor
    func testStatisticsRendererCreatesPNG() {
        let data = TelegramStatisticsRenderer.pngData(for: makeStatisticsSnapshot())

        XCTAssertNotNil(data)
        XCTAssertTrue(data?.starts(with: [0x89, 0x50, 0x4E, 0x47]) == true)
    }

    func testPersistentMainReplyKeyboardEncoding() throws {
        let keyboard = TelegramReplyKeyboard(
            keyboard: [[
                TelegramReplyKeyboardButton(text: "Добавить"),
                TelegramReplyKeyboardButton(text: "Статистика")
            ]],
            resizeKeyboard: true,
            isPersistent: true
        )

        let data = try JSONEncoder().encode(keyboard)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let rows = try XCTUnwrap(json["keyboard"] as? [[[String: String]]])

        XCTAssertEqual(rows.first?.map { $0["text"] }, ["Добавить", "Статистика"])
        XCTAssertEqual(json["resize_keyboard"] as? Bool, true)
        XCTAssertEqual(json["is_persistent"] as? Bool, true)
    }

    func testRejectsInvalidCallbackData() {
        XCTAssertNil(TelegramCallbackData(rawValue: "currency::BYN"))
        XCTAssertNil(TelegramCallbackData(rawValue: "category:ABC123:unknown"))
        XCTAssertNil(TelegramCallbackData(rawValue: "unexpected:ABC123:BYN"))
        XCTAssertNil(TelegramCallbackData(rawValue: "statistics:previous"))
    }

    private func makeStatisticsSnapshot() -> TelegramStatisticsSnapshot {
        TelegramStatisticsSnapshot(
            monthTitle: "Октябрь 2026",
            daysRemaining: 28,
            primaryCurrency: .byn,
            showSecondaryCurrency: false,
            primaryTotal: 12_500,
            secondaryTotal: 4_000,
            categoryTotals: ExpenseCategory.spendingCases.map {
                CategoryTotal(category: $0, amountMinor: $0 == .food ? 12_500 : 0)
            },
            limitMinor: 20_000,
            limitCurrency: .byn,
            limitSpentMinor: 12_500,
            savings: []
        )
    }
}
