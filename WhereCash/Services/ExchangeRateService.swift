import Foundation

struct ExchangeRateQuote {
    let rate: Double
    let date: Date
    let isStale: Bool
}

@MainActor
final class ExchangeRateService: ObservableObject {
    @Published private(set) var latestRate: Double?
    @Published private(set) var rateDate: Date?
    @Published private(set) var isStale = false
    @Published private(set) var lastError: String?
    @Published private(set) var isLoading = false

    private enum Keys {
        static let rate = "cachedBYNPerUSD"
        static let date = "cachedBYNPerUSDDate"
    }

    private struct Response: Decodable {
        let date: String
        let officialRate: Double

        enum CodingKeys: String, CodingKey {
            case date = "Date"
            case officialRate = "Cur_OfficialRate"
        }
    }

    init(defaults: UserDefaults = .standard) {
        let cachedRate = defaults.double(forKey: Keys.rate)
        latestRate = cachedRate > 0 ? cachedRate : nil
        rateDate = defaults.object(forKey: Keys.date) as? Date
        if let rateDate {
            isStale = !Calendar.current.isDate(rateDate, inSameDayAs: Date())
        }
    }

    func refreshIfNeeded(force: Bool = false) async {
        if !force,
           latestRate != nil,
           let rateDate,
           Calendar.current.isDate(rateDate, inSameDayAs: Date()) {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let quote = try await fetchRate(on: Date())
            latestRate = quote.rate
            rateDate = quote.date
            isStale = false
            lastError = nil
            UserDefaults.standard.set(quote.rate, forKey: Keys.rate)
            UserDefaults.standard.set(quote.date, forKey: Keys.date)
        } catch {
            isStale = latestRate != nil
            lastError = "Не удалось обновить курс НБ РБ"
        }
    }

    var currentQuote: ExchangeRateQuote? {
        guard let latestRate, let rateDate else { return nil }
        return ExchangeRateQuote(rate: latestRate, date: rateDate, isStale: isStale)
    }

    private func fetchRate(on date: Date) async throws -> ExchangeRateQuote {
        var components = URLComponents(string: "https://api.nbrb.by/exrates/rates/USD")!
        let dayFormatter = DateFormatter()
        dayFormatter.calendar = Calendar(identifier: .gregorian)
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.dateFormat = "yyyy-MM-dd"
        components.queryItems = [
            URLQueryItem(name: "ondate", value: dayFormatter.string(from: date)),
            URLQueryItem(name: "parammode", value: "2")
        ]

        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        let responseDate = Self.parseDate(decoded.date) ?? date
        return ExchangeRateQuote(rate: decoded.officialRate, date: responseDate, isStale: false)
    }

    private static func parseDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.date(from: value)
    }
}
