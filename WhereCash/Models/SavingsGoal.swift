import Foundation
import SwiftData

@Model
final class SavingsGoal {
    @Attribute(.unique) var id: UUID
    var name: String
    var targetMinor: Int64
    var currencyRaw: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        targetMinor: Int64,
        currency: CurrencyCode,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.targetMinor = targetMinor
        self.currencyRaw = currency.rawValue
        self.createdAt = createdAt
    }

    var currency: CurrencyCode {
        get { CurrencyCode(rawValue: currencyRaw) ?? .byn }
        set { currencyRaw = newValue.rawValue }
    }
}
