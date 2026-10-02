import Foundation
import SwiftData

@Model
final class ExpenseRecord {
    @Attribute(.unique) var id: UUID
    var amountMinor: Int64
    var currencyRaw: String
    var categoryRaw: String
    var createdAt: Date
    var bynPerUSD: Double?
    var rateDate: Date?
    var usedStaleRate: Bool

    init(
        id: UUID = UUID(),
        amountMinor: Int64,
        currency: CurrencyCode,
        category: ExpenseCategory,
        createdAt: Date = Date(),
        bynPerUSD: Double?,
        rateDate: Date?,
        usedStaleRate: Bool
    ) {
        self.id = id
        self.amountMinor = amountMinor
        self.currencyRaw = currency.rawValue
        self.categoryRaw = category.rawValue
        self.createdAt = createdAt
        self.bynPerUSD = bynPerUSD
        self.rateDate = rateDate
        self.usedStaleRate = usedStaleRate
    }

    var currency: CurrencyCode {
        get { CurrencyCode(rawValue: currencyRaw) ?? .byn }
        set { currencyRaw = newValue.rawValue }
    }

    var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRaw) ?? .food }
        set { categoryRaw = newValue.rawValue }
    }
}
