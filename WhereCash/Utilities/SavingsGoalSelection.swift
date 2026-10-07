import Foundation

enum SavingsGoalSelection {
    static let maximumCount = 2

    static func ids(from storedValue: String) -> [UUID] {
        var result: [UUID] = []

        for component in storedValue.split(separator: ",") {
            guard let id = UUID(uuidString: String(component)),
                  !result.contains(id) else { continue }
            result.append(id)
            if result.count == maximumCount { break }
        }

        return result
    }

    static func storedValue(for ids: [UUID]) -> String {
        var uniqueIDs: [UUID] = []
        for id in ids where !uniqueIDs.contains(id) {
            uniqueIDs.append(id)
            if uniqueIDs.count == maximumCount { break }
        }
        return uniqueIDs.map(\.uuidString).joined(separator: ",")
    }
}
