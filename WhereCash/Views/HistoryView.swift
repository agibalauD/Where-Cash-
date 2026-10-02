import SwiftData
import SwiftUI

private enum HistorySection: String, CaseIterable, Identifiable {
    case expenses = "Расходы"
    case savings = "Накопления"

    var id: String { rawValue }
}

private enum HistoryDeleteTarget {
    case expense(UUID)
    case contribution(UUID)

    var title: String {
        switch self {
        case .expense:
            "Удалить расход?"
        case .contribution:
            "Удалить пополнение?"
        }
    }

    var message: String {
        switch self {
        case .expense:
            "Это действие нельзя отменить."
        case .contribution:
            "Прогресс цели будет пересчитан. Действие нельзя отменить."
        }
    }
}

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExpenseRecord.createdAt, order: .reverse) private var expenses: [ExpenseRecord]
    @Query(sort: \SavingsGoal.createdAt) private var savingsGoals: [SavingsGoal]
    @Query(sort: \SavingsContribution.createdAt, order: .reverse) private var savingsContributions: [SavingsContribution]
    @AppStorage(AppSettingKeys.analyticsStartTimestamp) private var analyticsStartTimestamp = 0.0

    @State private var activeSection: HistorySection = .expenses
    @State private var selectedMonth = MonthUtilities.startOfMonth(for: Date())
    @State private var expenseToEdit: ExpenseRecord?
    @State private var deleteTarget: HistoryDeleteTarget?
    @State private var errorMessage: String?

    let onBack: () -> Void

    private var monthlyExpenses: [ExpenseRecord] {
        expenses.filter {
            ExpenseCategory.spendingCases.contains($0.category)
                && MonthUtilities.contains($0.createdAt, inMonth: selectedMonth)
        }
    }

    private var monthlyContributions: [SavingsContribution] {
        savingsContributions.filter { MonthUtilities.contains($0.createdAt, inMonth: selectedMonth) }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: onBack) {
                    Label("Назад", systemImage: "chevron.left")
                }
                .buttonStyle(.plain)
                Spacer()
                Text("История")
                    .font(.title3.bold())
                Spacer()
                Color.clear.frame(width: 52, height: 1)
            }
            .padding(.horizontal)

            Picker("Раздел истории", selection: $activeSection) {
                ForEach(HistorySection.allCases) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            MonthNavigatorView(selectedMonth: $selectedMonth)
                .padding(.horizontal)

            if activeSection == .expenses && monthlyExpenses.isEmpty {
                ContentUnavailableView(
                    "Нет расходов",
                    systemImage: "tray",
                    description: Text("В выбранном месяце ещё нет операций")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if activeSection == .savings && monthlyContributions.isEmpty {
                ContentUnavailableView(
                    "Нет пополнений",
                    systemImage: "target",
                    description: Text("В выбранном месяце накопления не пополнялись")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if activeSection == .expenses {
                List(monthlyExpenses) { expense in
                    HStack(spacing: 12) {
                        Image(systemName: expense.category.symbolName)
                            .foregroundStyle(expense.category.color)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(expense.category.title)
                                .font(.headline)
                            Text(expense.createdAt.formatted(.dateTime.day().month(.wide).year()))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if AnalyticsPeriod.isArchived(
                                expense.createdAt,
                                startTimestamp: analyticsStartTimestamp
                            ) {
                                Label("Архив", systemImage: "archivebox")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Text(CurrencyAmountFormatter.string(minorUnits: expense.amountMinor, currency: expense.currency))
                            .font(.callout.monospacedDigit())

                        Button {
                            expenseToEdit = expense
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Изменить")

                        Button(role: .destructive) {
                            deleteTarget = .expense(expense.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Удалить")
                    }
                    .padding(.vertical, 4)
                }
            } else {
                List(monthlyContributions) { contribution in
                    HStack(spacing: 12) {
                        Image(systemName: "target")
                            .foregroundStyle(.green)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(goalName(for: contribution.goalID))
                                .font(.headline)
                            Text(contribution.createdAt.formatted(.dateTime.day().month(.wide).year()))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(CurrencyAmountFormatter.string(
                            minorUnits: contribution.amountMinor,
                            currency: contribution.currency
                        ))
                        .font(.callout.monospacedDigit())

                        Button(role: .destructive) {
                            deleteTarget = .contribution(contribution.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Удалить пополнение")
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(.vertical)
        .frame(width: 420, height: 680, alignment: .top)
        .sheet(item: $expenseToEdit) { expense in
            ExpenseEditView(expense: expense)
        }
        .overlay {
            if let deleteTarget {
                deleteConfirmationOverlay(for: deleteTarget)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(.easeInOut(duration: 0.16), value: deleteTarget != nil)
        .alert("Ошибка", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Неизвестная ошибка")
        }
    }

    private func goalName(for id: UUID) -> String {
        savingsGoals.first(where: { $0.id == id })?.name ?? "Удалённая цель"
    }

    private func deleteConfirmationOverlay(for target: HistoryDeleteTarget) -> some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    deleteTarget = nil
                }

            VStack(spacing: 14) {
                Image(systemName: "trash.fill")
                    .font(.title2)
                    .foregroundStyle(.red)

                Text(target.title)
                    .font(.headline)

                Text(target.message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 10) {
                    Button("Отмена") {
                        deleteTarget = nil
                    }
                    .keyboardShortcut(.cancelAction)

                    Button("Удалить", role: .destructive) {
                        deleteSelectedItem()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
            .padding(22)
            .frame(maxWidth: 300)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .shadow(radius: 18, y: 8)
        }
    }

    private func deleteSelectedItem() {
        guard let target = deleteTarget else { return }

        // Remove the inline confirmation before mutating SwiftData. Keeping an
        // @Model instance in view state while deleting it can leave the view
        // hierarchy attached to an invalid object.
        deleteTarget = nil

        switch target {
        case let .expense(id):
            guard let expense = expenses.first(where: { $0.id == id }) else { return }
            modelContext.delete(expense)
        case let .contribution(id):
            guard let contribution = savingsContributions.first(where: { $0.id == id }) else { return }
            modelContext.delete(contribution)
        }

        do {
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
