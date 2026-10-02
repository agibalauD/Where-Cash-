import Charts
import SwiftUI

struct StatisticsView: View {
    let expenses: [ExpenseRecord]
    let selectedMonth: Date
    let primaryCurrency: CurrencyCode
    let showSecondaryCurrency: Bool
    let monthlyLimitMinor: Int64?
    let monthlyLimitCurrency: CurrencyCode
    let selectedSavingsGoal: SavingsGoal?
    let savingsContributions: [SavingsContribution]

    @State private var animatedAmounts: [ExpenseCategory: Int64] = [:]
    @State private var initialAnimationTask: Task<Void, Never>?

    private var categoryTotals: [CategoryTotal] {
        ExpenseCalculator.categoryTotals(for: expenses, in: primaryCurrency)
    }

    private var primaryTotal: Int64? {
        ExpenseCalculator.total(for: expenses, in: primaryCurrency)
    }

    private var secondaryTotal: Int64? {
        ExpenseCalculator.total(for: expenses, in: primaryCurrency.other)
    }

    private var chartIsAvailable: Bool {
        categoryTotals.allSatisfy { $0.amountMinor != nil }
    }

    private var chartHasValues: Bool {
        categoryTotals.compactMap(\.amountMinor).contains { $0 > 0 }
    }

    private var limitSpentMinor: Int64? {
        guard monthlyLimitMinor != nil else { return nil }
        return ExpenseCalculator.total(for: expenses, in: monthlyLimitCurrency)
    }

    private var limitRatio: Double? {
        guard let monthlyLimitMinor,
              monthlyLimitMinor > 0,
              let limitSpentMinor else { return nil }
        return max(Double(limitSpentMinor) / Double(monthlyLimitMinor), 0)
    }

    private var activeSavingsTotal: Int64? {
        guard let selectedSavingsGoal else { return nil }
        return SavingsCalculator.total(for: savingsContributions, goal: selectedSavingsGoal)
    }

    private var animationKey: String {
        let values = categoryTotals.map { "\($0.category.rawValue):\($0.amountMinor ?? -1)" }.joined(separator: "|")
        return "\(selectedMonth.timeIntervalSinceReferenceDate)|\(primaryCurrency.rawValue)|\(values)"
    }

    var body: some View {
        VStack(spacing: 9) {
            ZStack {
                Circle()
                    .stroke(.secondary.opacity(0.16), lineWidth: 9)

                if let limitRatio {
                    Circle()
                        .trim(from: 0, to: min(limitRatio, 1))
                        .stroke(
                            LimitColorScale.components(for: limitRatio).color,
                            style: StrokeStyle(lineWidth: 9, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.65, dampingFraction: 0.84), value: limitRatio)
                }

                if monthlyLimitMinor != nil {
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.65), radius: 2)
                        .offset(y: -80)
                        .accessibilityLabel("Месячный лимит")
                }

                if chartIsAvailable && chartHasValues {
                    Chart(ExpenseCategory.spendingCases) { category in
                        SectorMark(
                            angle: .value("Сумма", animatedAmounts[category] ?? 0),
                            innerRadius: .ratio(0.76),
                            angularInset: 1.5
                        )
                        .cornerRadius(3)
                        .foregroundStyle(category.color)
                    }
                    .padding(15)
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
                } else {
                    Circle()
                        .stroke(.secondary.opacity(0.2), lineWidth: 22)
                        .padding(26)
                        .transition(.opacity)
                }

                VStack(spacing: 2) {
                    Text("\(MonthUtilities.dayCountValue(for: selectedMonth))")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                        .animation(.snappy(duration: 0.4), value: selectedMonth)
                    Text(MonthUtilities.dayCountCaption(for: selectedMonth))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(width: 110)
            }
            .frame(height: 174)

            limitSummary

            VStack(spacing: 4) {
                Text(primaryTotal.map { CurrencyAmountFormatter.string(minorUnits: $0, currency: primaryCurrency) } ?? "Курс недоступен")
                    .font(.title2.bold())
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.4), value: primaryTotal)

                if showSecondaryCurrency {
                    Text(secondaryTotal.map { CurrencyAmountFormatter.string(minorUnits: $0, currency: primaryCurrency.other) } ?? "Курс недоступен")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .animation(.snappy(duration: 0.4), value: secondaryTotal)
                }
            }

            savingsSummary

            VStack(spacing: 5) {
                ForEach(categoryTotals) { item in
                    HStack {
                        Circle()
                            .fill(item.category.color)
                            .frame(width: 10, height: 10)
                        Text(item.category.title)
                        Spacer()
                        Text(item.amountMinor.map {
                            CurrencyAmountFormatter.string(minorUnits: $0, currency: primaryCurrency)
                        } ?? "—")
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.snappy(duration: 0.4), value: item.amountMinor)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showSecondaryCurrency)
        .onAppear(perform: animateChart)
        .onChange(of: animationKey) { _, _ in
            animateChart()
        }
        .onDisappear {
            initialAnimationTask?.cancel()
        }
    }

    private func animateChart() {
        let target = Dictionary(uniqueKeysWithValues: categoryTotals.compactMap { item in
            item.amountMinor.map { (item.category, $0) }
        })

        initialAnimationTask?.cancel()

        if animatedAmounts.isEmpty {
            animatedAmounts = Dictionary(
                uniqueKeysWithValues: ExpenseCategory.spendingCases.map { ($0, 0) }
            )
            initialAnimationTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 70_000_000)
                guard !Task.isCancelled else { return }
                applyAnimatedAmounts(target)
            }
        } else {
            applyAnimatedAmounts(target)
        }
    }

    private func applyAnimatedAmounts(_ target: [ExpenseCategory: Int64]) {
        let changedCategories = ExpenseCategory.spendingCases.filter {
            animatedAmounts[$0, default: 0] != target[$0, default: 0]
        }

        guard !changedCategories.isEmpty else { return }

        withAnimation(.spring(response: 0.7, dampingFraction: 0.82)) {
            for category in changedCategories {
                animatedAmounts[category] = target[category, default: 0]
            }
        }
    }

    @ViewBuilder
    private var limitSummary: some View {
        if let monthlyLimitMinor {
            if let limitSpentMinor {
                if limitSpentMinor > monthlyLimitMinor {
                    Text("Превышение \(CurrencyAmountFormatter.string(minorUnits: limitSpentMinor - monthlyLimitMinor, currency: monthlyLimitCurrency))")
                        .font(.callout.bold())
                        .foregroundStyle(.red)
                        .contentTransition(.numericText())
                } else {
                    Text("\(CurrencyAmountFormatter.string(minorUnits: limitSpentMinor, currency: monthlyLimitCurrency)) из \(CurrencyAmountFormatter.string(minorUnits: monthlyLimitMinor, currency: monthlyLimitCurrency))")
                        .font(.callout.monospacedDigit())
                        .contentTransition(.numericText())
                }
            } else {
                Text("Лимит: курс недоступен")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        } else {
            Label("Настройте месячный лимит", systemImage: "slider.horizontal.3")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var savingsSummary: some View {
        if let selectedSavingsGoal {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Label(selectedSavingsGoal.name, systemImage: "target")
                        .font(.headline)
                    Spacer()
                    if let activeSavingsTotal,
                       activeSavingsTotal >= selectedSavingsGoal.targetMinor {
                        Text("Цель достигнута")
                            .font(.caption.bold())
                            .foregroundStyle(.green)
                    }
                }

                SavingsProgressBar(
                    currentMinor: activeSavingsTotal,
                    targetMinor: selectedSavingsGoal.targetMinor,
                    currency: selectedSavingsGoal.currency
                )
            }
        } else {
            VStack(alignment: .leading, spacing: 7) {
                ProgressView(value: 0)
                    .tint(.green)
                Label("Выберите цель накоплений в настройках", systemImage: "target")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
