import Foundation

enum AppSettingKeys {
    static let lastCurrency = "lastCurrency"
    static let showSecondaryCurrency = "showSecondaryCurrency"
    static let telegramOwnerUserID = "telegramOwnerUserID"
    static let telegramChatID = "telegramChatID"
    static let telegramLastUpdateID = "telegramLastUpdateID"
    static let telegramBotUsername = "telegramBotUsername"
    static let monthlyLimitMinor = "monthlyLimitMinor"
    static let monthlyLimitCurrency = "monthlyLimitCurrency"
    // The persisted key stays singular for compatibility with versions up to 1.6.
    // Its value now contains one or two comma-separated goal identifiers.
    static let selectedSavingsGoalIDs = "selectedSavingsGoalID"
    static let analyticsStartTimestamp = "analyticsStartTimestamp"
}
