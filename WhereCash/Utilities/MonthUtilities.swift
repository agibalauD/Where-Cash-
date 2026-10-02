import Foundation

enum MonthUtilities {
    static func startOfMonth(for date: Date, calendar: Calendar = .current) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    static func previousMonth(from date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .month, value: -1, to: startOfMonth(for: date, calendar: calendar)) ?? date
    }

    static func nextMonth(from date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .month, value: 1, to: startOfMonth(for: date, calendar: calendar)) ?? date
    }

    static func isCurrentMonth(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        calendar.isDate(date, equalTo: now, toGranularity: .month)
    }

    static func canMoveToNextMonth(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        nextMonth(from: date, calendar: calendar) <= startOfMonth(for: now, calendar: calendar)
    }

    static func contains(_ date: Date, inMonth month: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(date, equalTo: month, toGranularity: .month)
    }

    static func title(for month: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: month).capitalized
    }

    static func dayCountValue(for month: Date, now: Date = Date(), calendar: Calendar = .current) -> Int {
        if isCurrentMonth(month, now: now, calendar: calendar) {
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
            let nextMonthStart = nextMonth(from: month, calendar: calendar)
            return max(0, calendar.dateComponents([.day], from: tomorrow, to: nextMonthStart).day ?? 0)
        }
        return calendar.range(of: .day, in: .month, for: month)?.count ?? 0
    }

    static func dayCountCaption(for month: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        isCurrentMonth(month, now: now, calendar: calendar) ? "до конца месяца" : "дней в месяце"
    }
}
