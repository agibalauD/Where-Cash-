import SwiftUI

enum ExpenseCategory: String, CaseIterable, Codable, Identifiable {
    case food
    case transport
    case entertainment
    case purchases
    case other
    case savings

    static var spendingCases: [ExpenseCategory] {
        [.food, .transport, .entertainment, .purchases, .other]
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .food: "Еда"
        case .transport: "Транспорт"
        case .entertainment: "Развлечения"
        case .purchases: "Покупки"
        case .other: "Прочие расходы"
        case .savings: "Накопления"
        }
    }

    var color: Color {
        switch self {
        case .food: .green
        case .transport: .blue
        case .entertainment: .purple
        case .purchases: .orange
        case .other: .pink
        case .savings: .green
        }
    }

    var symbolName: String {
        switch self {
        case .food: "fork.knife"
        case .transport: "car.fill"
        case .entertainment: "gamecontroller.fill"
        case .purchases: "bag.fill"
        case .other: "ellipsis.circle.fill"
        case .savings: "target"
        }
    }
}
