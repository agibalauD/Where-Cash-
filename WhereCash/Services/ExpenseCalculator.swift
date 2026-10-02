import Foundation

struct CategoryTotal: Identifiable {
    let category: ExpenseCategory
    let amountMinor: Int64?

    var id: ExpenseCategory { category }
}

enum ExpenseCalculator {
    static func convertedMinor(_ expense: ExpenseRecord, to target: CurrencyCode) -> Int64? {
        guard expense.currency != target else { return expense.amountMinor }
        guard let rate = expense.bynPerUSD, rate > 0 else { return nil }

        let sourceMajor = Double(expense.amountMinor) / 100
        let convertedMajor = expense.currency == .usd ? sourceMajor * rate : sourceMajor / rate
        let convertedMinor = (convertedMajor * 100).rounded()
        guard convertedMinor.isFinite,
              convertedMinor >= 0,
              convertedMinor <= Double(Int64.max) else { return nil }
        return Int64(convertedMinor)
    }

    static func total(for expenses: [ExpenseRecord], in currency: CurrencyCode) -> Int64? {
        var result: Int64 = 0
        for expense in expenses {
            guard let value = convertedMinor(expense, to: currency) else { return nil }
            let (sum, overflowed) = result.addingReportingOverflow(value)
            guard !overflowed else { return nil }
            result = sum
        }
        return result
    }

    static func categoryTotals(for expenses: [ExpenseRecord], in currency: CurrencyCode) -> [CategoryTotal] {
        ExpenseCategory.spendingCases.map { category in
            CategoryTotal(
                category: category,
                amountMinor: total(for: expenses.filter { $0.category == category }, in: currency)
            )
        }
    }
}
