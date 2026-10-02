import SwiftData
import SwiftUI

struct ExpenseEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var exchangeRateService: ExchangeRateService
    @Query(sort: \SavingsGoal.createdAt) private var savingsGoals: [SavingsGoal]
    @AppStorage(AppSettingKeys.lastCurrency) private var lastCurrencyRaw = CurrencyCode.byn.rawValue
    @AppStorage(AppSettingKeys.selectedSavingsGoalID) private var selectedSavingsGoalIDRaw = ""

    @State private var amountText = ""
    @State private var selectedCategory: ExpenseCategory?
    @State private var selectedCurrency: CurrencyCode = .byn
    @State private var isSaving = false
    @State private var errorMessage: String?

    let onAdded: () -> Void

    private var parsedAmount: Int64? {
        AmountParser.minorUnits(from: amountText)
    }

    private var selectedSavingsGoal: SavingsGoal? {
        guard let id = UUID(uuidString: selectedSavingsGoalIDRaw) else { return nil }
        return savingsGoals.first { $0.id == id }
    }

    private var savingsGoalIsMissing: Bool {
        selectedCategory == .savings && selectedSavingsGoal == nil
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                TextField("Сумма", text: $amountText)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: amountText) { _, newValue in
                        let sanitized = AmountParser.sanitized(newValue)
                        if sanitized != newValue { amountText = sanitized }
                    }

                Picker("Валюта", selection: $selectedCurrency) {
                    ForEach(CurrencyCode.allCases) { currency in
                        Text(currency.rawValue).tag(currency)
                    }
                }
                .labelsHidden()
                .frame(width: 82)
            }

            HStack(spacing: 8) {
                Picker("Категория", selection: $selectedCategory) {
                    Text("Выберите категорию").tag(nil as ExpenseCategory?)
                    ForEach(ExpenseCategory.allCases) { category in
                        Label(category.title, systemImage: category.symbolName)
                            .tag(category as ExpenseCategory?)
                    }
                }
                .labelsHidden()

                Button {
                    Task { await addExpense() }
                } label: {
                    if isSaving {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Добавить", systemImage: "plus")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
                .disabled(parsedAmount == nil || selectedCategory == nil || savingsGoalIsMissing || isSaving)
            }
            if savingsGoalIsMissing {
                Label("Выберите цель накоплений в настройках", systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .onAppear {
            selectedCurrency = CurrencyCode(rawValue: lastCurrencyRaw) ?? .byn
        }
        .alert("Не удалось сохранить операцию", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Неизвестная ошибка")
        }
    }

    @MainActor
    private func addExpense() async {
        guard let amountMinor = parsedAmount, let selectedCategory else { return }
        isSaving = true
        defer { isSaving = false }

        await exchangeRateService.refreshIfNeeded()
        let quote = exchangeRateService.currentQuote
        if selectedCategory == .savings {
            guard let goal = selectedSavingsGoal else {
                errorMessage = "Сначала выберите цель накоплений в настройках."
                return
            }
            guard selectedCurrency == goal.currency || quote != nil else {
                errorMessage = "Для пополнения в другой валюте нужен актуальный или сохранённый курс."
                return
            }

            let contribution = SavingsContribution(
                goalID: goal.id,
                amountMinor: amountMinor,
                currency: selectedCurrency,
                bynPerUSD: quote?.rate,
                rateDate: quote?.date,
                usedStaleRate: quote?.isStale ?? false
            )
            modelContext.insert(contribution)
            do {
                try finishSaving()
            } catch {
                modelContext.delete(contribution)
                errorMessage = error.localizedDescription
            }
        } else {
            let expense = ExpenseRecord(
                amountMinor: amountMinor,
                currency: selectedCurrency,
                category: selectedCategory,
                bynPerUSD: quote?.rate,
                rateDate: quote?.date,
                usedStaleRate: quote?.isStale ?? false
            )
            modelContext.insert(expense)
            do {
                try finishSaving()
            } catch {
                modelContext.delete(expense)
                errorMessage = error.localizedDescription
            }
        }
    }

    private func finishSaving() throws {
        try modelContext.save()
        lastCurrencyRaw = selectedCurrency.rawValue
        amountText = ""
        selectedCategory = nil
        onAdded()
    }
}
