import Foundation

enum PanelSection: Hashable {
    case statistics
    case history
    case settings
    case help
}

@MainActor
final class PanelRouter: ObservableObject {
    @Published private(set) var activeSection: PanelSection = .statistics

    func show(_ section: PanelSection) {
        activeSection = section
    }
}
