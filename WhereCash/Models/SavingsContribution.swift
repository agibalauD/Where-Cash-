import Foundation
import SwiftData

@Model
final class SavingsContribution {
    @Attribute(.unique) var id: UUID
    var goalID: UUID
    var amountMinor: Int64
    var currencyRaw: String
    var createdAt: Date
    var bynPerUSD: Double?
    var rateDate: Date?
    var usedStaleRate: Bool

    init(
        id: UUID = UUID(),
        goalID: UUID,
        amountMinor: Int64,
        currency: CurrencyCode,
        createdAt: Date = Date(),
        bynPerUSD: Double?,
        rateDate: Date?,
        usedStaleRate: Bool
    ) {
        self.id = id
        self.goalID = goalID
        self.amountMinor = amountMinor
        self.currencyRaw = currency.rawValue
        self.createdAt = createdAt
        self.bynPerUSD = bynPerUSD
        self.rateDate = rateDate
        self.usedStaleRate = usedStaleRate
    }

    var currency: CurrencyCode {
        get { CurrencyCode(rawValue: currencyRaw) ?? .byn }
        set { currencyRaw = newValue.rawValue }
    }
}
