import Foundation

enum CurrencyCode: String, CaseIterable, Codable, Identifiable {
    case byn = "BYN"
    case usd = "USD"

    var id: String { rawValue }

    var other: CurrencyCode {
        self == .byn ? .usd : .byn
    }
}
