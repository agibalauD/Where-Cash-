import Foundation
import SwiftUI

struct LimitColorComponents: Equatable {
    let red: Double
    let green: Double
    let blue: Double

    var color: Color {
        Color(red: red, green: green, blue: blue)
    }
}

enum LimitColorScale {
    private static let indigo = LimitColorComponents(red: 0.345, green: 0.337, blue: 0.839)
    private static let blue = LimitColorComponents(red: 0.0, green: 0.478, blue: 1.0)
    private static let yellow = LimitColorComponents(red: 1.0, green: 0.8, blue: 0.0)
    private static let red = LimitColorComponents(red: 1.0, green: 0.231, blue: 0.188)

    static func components(for ratio: Double) -> LimitColorComponents {
        let value = max(0, ratio)
        switch value {
        case ..<0.3:
            return interpolate(from: indigo, to: blue, progress: value / 0.3)
        case ..<0.5:
            return interpolate(from: blue, to: yellow, progress: (value - 0.3) / 0.2)
        case ..<0.8:
            return interpolate(from: yellow, to: red, progress: (value - 0.5) / 0.3)
        default:
            return red
        }
    }

    private static func interpolate(
        from start: LimitColorComponents,
        to end: LimitColorComponents,
        progress: Double
    ) -> LimitColorComponents {
        let clamped = min(max(progress, 0), 1)
        return LimitColorComponents(
            red: start.red + (end.red - start.red) * clamped,
            green: start.green + (end.green - start.green) * clamped,
            blue: start.blue + (end.blue - start.blue) * clamped
        )
    }
}
