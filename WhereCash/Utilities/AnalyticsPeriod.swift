import Foundation

enum AnalyticsPeriod {
    static func startDate(from timestamp: Double) -> Date? {
        guard timestamp.isFinite, timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    static func includes(_ date: Date, startTimestamp: Double) -> Bool {
        guard let startDate = startDate(from: startTimestamp) else { return true }
        return date >= startDate
    }

    static func isArchived(_ date: Date, startTimestamp: Double) -> Bool {
        !includes(date, startTimestamp: startTimestamp)
    }
}
