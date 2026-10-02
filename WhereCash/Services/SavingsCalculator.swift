import Foundation

enum SavingsCalculator {
    static func convertedMinor(
        _ contribution: SavingsContribution,
        to target: CurrencyCode
    ) -> Int64? {
        guard contribution.currency != target else { return contribution.amountMinor }
        guard let rate = contribution.bynPerUSD, rate > 0 else { return nil }

        let sourceMajor = Double(contribution.amountMinor) / 100
        let convertedMajor = contribution.currency == .usd ? sourceMajor * rate : sourceMajor / rate
        let convertedMinor = (convertedMajor * 100).rounded()
        guard convertedMinor.isFinite,
              convertedMinor >= 0,
              convertedMinor <= Double(Int64.max) else { return nil }
        return Int64(convertedMinor)
    }

    static func total(
        for contributions: [SavingsContribution],
        goal: SavingsGoal
    ) -> Int64? {
        var result: Int64 = 0
        for contribution in contributions where contribution.goalID == goal.id {
            guard let value = convertedMinor(contribution, to: goal.currency) else { return nil }
            let (sum, overflowed) = result.addingReportingOverflow(value)
            guard !overflowed else { return nil }
            result = sum
        }
        return result
    }
}
