import SwiftData
import SwiftUI

struct ExpenseEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var exchangeRateService: ExchangeRateService

    let expense: ExpenseRecord

    @State private var amountText: String
    @State private var category: ExpenseCategory
    @State private var currency: CurrencyCode
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(expense: ExpenseRecord) {
        self.expense = expense
        _amountText = State(initialValue: CurrencyAmountFormatter.editString(minorUnits: expense.amountMinor))
        _category = State(initialValue: expense.category)
        _currency = State(initialValue: expense.currency)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Изменить расход")
                .font(.title2.bold())

            Form {
                TextField("Сумма", text: $amountText)
                    .onChange(of: amountText) { _, newValue in
                        let sanitized = AmountParser.sanitized(newValue)
                        if sanitized != newValue { amountText = sanitized }
                    }

                Picker("Категория", selection: $category) {
                    ForEach(ExpenseCategory.spendingCases) { item in
                        Text(item.title).tag(item)
                    }
                }

                Picker("Валюта", selection: $currency) {
                    ForEach(CurrencyCode.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }

                LabeledContent("Дата") {
                    Text(expense.createdAt.formatted(.dateTime.day().month(.wide).year()))
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Отмена") { dismiss() }
                Button("Сохранить") {
                    Task { await save() }
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
                .disabled(AmountParser.minorUnits(from: amountText) == nil || isSaving)
            }
        }
        .padding(20)
        .frame(width: 430)
        .alert("Не удалось сохранить изменения", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Неизвестная ошибка")
        }
    }

    @MainActor
    private func save() async {
        guard let amountMinor = AmountParser.minorUnits(from: amountText) else { return }
        isSaving = true
        defer { isSaving = false }

        if expense.bynPerUSD == nil {
            await exchangeRateService.refreshIfNeeded()
            if let quote = exchangeRateService.currentQuote {
                expense.bynPerUSD = quote.rate
                expense.rateDate = quote.date
                expense.usedStaleRate = quote.isStale
            }
        }

        expense.amountMinor = amountMinor
        expense.category = category
        expense.currency = currency

        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
