import SwiftData
import SwiftUI

struct SavingsGoalEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let goal: SavingsGoal?
    let hasContributions: Bool

    @State private var name: String
    @State private var targetText: String
    @State private var currency: CurrencyCode
    @State private var errorMessage: String?

    init(goal: SavingsGoal?, hasContributions: Bool) {
        self.goal = goal
        self.hasContributions = hasContributions
        _name = State(initialValue: goal?.name ?? "")
        _targetText = State(initialValue: goal.map {
            CurrencyAmountFormatter.editString(minorUnits: $0.targetMinor)
        } ?? "")
        _currency = State(initialValue: goal?.currency ?? .byn)
    }

    private var normalizedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(goal == nil ? "Новая цель" : "Изменить цель")
                .font(.title2.bold())

            Form {
                TextField("Название", text: $name)

                TextField("Цель", text: $targetText)
                    .onChange(of: targetText) { _, newValue in
                        let sanitized = AmountParser.sanitized(newValue)
                        if sanitized != newValue { targetText = sanitized }
                    }

                Picker("Валюта", selection: $currency) {
                    ForEach(CurrencyCode.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .disabled(hasContributions)

                if hasContributions {
                    Text("Валюту нельзя изменить после первого пополнения.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Отмена") { dismiss() }
                Button("Сохранить", action: save)
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
                    .disabled(normalizedName.isEmpty || AmountParser.minorUnits(from: targetText) == nil)
            }
        }
        .padding(20)
        .frame(width: 380)
        .alert("Не удалось сохранить цель", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Неизвестная ошибка")
        }
    }

    private func save() {
        guard let targetMinor = AmountParser.minorUnits(from: targetText),
              !normalizedName.isEmpty else { return }

        if let goal {
            goal.name = normalizedName
            goal.targetMinor = targetMinor
            if !hasContributions {
                goal.currency = currency
            }
        } else {
            modelContext.insert(SavingsGoal(
                name: normalizedName,
                targetMinor: targetMinor,
                currency: currency
            ))
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct SavingsProgressBar: View {
    let currentMinor: Int64?
    let targetMinor: Int64
    let currency: CurrencyCode

    private var progress: Double {
        guard let currentMinor, targetMinor > 0 else { return 0 }
        return min(max(Double(currentMinor) / Double(targetMinor), 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ProgressView(value: progress)
                .tint(.green)
                .animation(.spring(response: 0.55, dampingFraction: 0.85), value: progress)

            Text(summary)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
        }
    }

    private var summary: String {
        guard let currentMinor else { return "Курс недоступен" }
        return "\(CurrencyAmountFormatter.string(minorUnits: currentMinor, currency: currency)) из \(CurrencyAmountFormatter.string(minorUnits: targetMinor, currency: currency))"
    }
}
