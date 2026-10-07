import SwiftData
import SwiftUI

private enum ExpenseEntryDestination: Hashable {
    case expense(ExpenseCategory)
    case savings(goalID: UUID)
}

struct ExpenseEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var exchangeRateService: ExchangeRateService
    @Query(sort: \SavingsGoal.createdAt) private var savingsGoals: [SavingsGoal]
    @AppStorage(AppSettingKeys.lastCurrency) private var lastCurrencyRaw = CurrencyCode.byn.rawValue
    @AppStorage(AppSettingKeys.selectedSavingsGoalIDs) private var selectedSavingsGoalIDsRaw = ""

    @State private var amountText = ""
    @State private var selectedDestination: ExpenseEntryDestination?
    @State private var selectedCurrency: CurrencyCode = .byn
    @State private var isSaving = false
    @State private var errorMessage: String?

    let onAdded: () -> Void

    private var parsedAmount: Int64? {
        AmountParser.minorUnits(from: amountText)
    }

    private var selectedSavingsGoals: [SavingsGoal] {
        SavingsGoalSelection.ids(from: selectedSavingsGoalIDsRaw).compactMap { id in
            savingsGoals.first { $0.id == id }
        }
    }

    private var selectedGoalIsMissing: Bool {
        guard case let .savings(goalID) = selectedDestination else { return false }
        return !selectedSavingsGoals.contains { $0.id == goalID }
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
                Picker("Категория", selection: $selectedDestination) {
                    Text("Выберите категорию").tag(nil as ExpenseEntryDestination?)
                    ForEach(ExpenseCategory.spendingCases) { category in
                        Label(category.title, systemImage: category.symbolName)
                            .tag(ExpenseEntryDestination.expense(category) as ExpenseEntryDestination?)
                    }
                    ForEach(selectedSavingsGoals, id: \.id) { goal in
                        Label("Накопления — \(goal.name)", systemImage: "target")
                            .tag(ExpenseEntryDestination.savings(goalID: goal.id) as ExpenseEntryDestination?)
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
                .disabled(parsedAmount == nil || selectedDestination == nil || selectedGoalIsMissing || isSaving)
            }
            if selectedGoalIsMissing {
                Label("Эта цель больше не выбрана в настройках", systemImage: "exclamationmark.circle")
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
        guard let amountMinor = parsedAmount, let selectedDestination else { return }
        isSaving = true
        defer { isSaving = false }

        await exchangeRateService.refreshIfNeeded()
        let quote = exchangeRateService.currentQuote
        switch selectedDestination {
        case let .savings(goalID):
            guard let goal = selectedSavingsGoals.first(where: { $0.id == goalID }) else {
                errorMessage = "Выбранная цель больше не доступна. Выберите её заново."
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
        case let .expense(category):
            let expense = ExpenseRecord(
                amountMinor: amountMinor,
                currency: selectedCurrency,
                category: category,
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
        selectedDestination = nil
        onAdded()
    }
}
