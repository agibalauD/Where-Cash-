import Foundation

enum AmountParser {
    static func sanitized(_ input: String) -> String {
        var result = ""
        var hasSeparator = false
        var fractionDigits = 0

        for character in input {
            if character.isNumber {
                if hasSeparator {
                    guard fractionDigits < 2 else { continue }
                    fractionDigits += 1
                }
                result.append(character)
            } else if (character == "," || character == ".") && !hasSeparator {
                if result.isEmpty { result = "0" }
                result.append(",")
                hasSeparator = true
            }
        }

        return result
    }

    static func minorUnits(from input: String) -> Int64? {
        let normalized = input.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        let parts = normalized.split(separator: ".", omittingEmptySubsequences: false)

        guard !normalized.isEmpty, parts.count <= 2 else { return nil }
        guard !parts[0].isEmpty, parts[0].allSatisfy(\.isNumber) else { return nil }

        let fractional = parts.count == 2 ? String(parts[1]) : ""
        guard fractional.count <= 2, fractional.allSatisfy(\.isNumber) else { return nil }
        guard let whole = Int64(parts[0]) else { return nil }

        let paddedFraction = fractional.padding(toLength: 2, withPad: "0", startingAt: 0)
        let fraction = Int64(paddedFraction) ?? 0
        let (scaledWhole, overflowed) = whole.multipliedReportingOverflow(by: 100)
        guard !overflowed else { return nil }
        let (minor, additionOverflowed) = scaledWhole.addingReportingOverflow(fraction)
        guard !additionOverflowed, minor > 0 else { return nil }
        return minor
    }
}

enum CurrencyAmountFormatter {
    static func string(minorUnits: Int64, currency: CurrencyCode) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ru_BY")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = " "
        let value = NSDecimalNumber(value: minorUnits).dividing(by: 100)
        return "\(formatter.string(from: value) ?? "0,00") \(currency.rawValue)"
    }

    static func editString(minorUnits: Int64) -> String {
        let whole = minorUnits / 100
        let fraction = minorUnits % 100
        return "\(whole),\(String(format: "%02lld", fraction))"
    }
}
