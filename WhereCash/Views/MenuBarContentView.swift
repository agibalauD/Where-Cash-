import SwiftData
import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject private var exchangeRateService: ExchangeRateService
    @Query(sort: \ExpenseRecord.createdAt, order: .reverse) private var expenses: [ExpenseRecord]
    @Query(sort: \SavingsGoal.createdAt) private var savingsGoals: [SavingsGoal]
    @Query(sort: \SavingsContribution.createdAt, order: .reverse) private var savingsContributions: [SavingsContribution]
    @AppStorage(AppSettingKeys.lastCurrency) private var lastCurrencyRaw = CurrencyCode.byn.rawValue
    @AppStorage(AppSettingKeys.showSecondaryCurrency) private var showSecondaryCurrency = true
    @AppStorage(AppSettingKeys.monthlyLimitMinor) private var monthlyLimitMinorRaw = ""
    @AppStorage(AppSettingKeys.monthlyLimitCurrency) private var monthlyLimitCurrencyRaw = CurrencyCode.byn.rawValue
    @AppStorage(AppSettingKeys.selectedSavingsGoalID) private var selectedSavingsGoalIDRaw = ""
    @AppStorage(AppSettingKeys.analyticsStartTimestamp) private var analyticsStartTimestamp = 0.0

    @ObservedObject var router: PanelRouter
    @State private var selectedMonth = MonthUtilities.startOfMonth(for: Date())

    private var primaryCurrency: CurrencyCode {
        CurrencyCode(rawValue: lastCurrencyRaw) ?? .byn
    }

    private var monthlyExpenses: [ExpenseRecord] {
        expenses.filter {
            ExpenseCategory.spendingCases.contains($0.category)
                && MonthUtilities.contains($0.createdAt, inMonth: selectedMonth)
                && AnalyticsPeriod.includes($0.createdAt, startTimestamp: analyticsStartTimestamp)
        }
    }

    private var monthlyLimitMinor: Int64? {
        Int64(monthlyLimitMinorRaw)
    }

    private var monthlyLimitCurrency: CurrencyCode {
        CurrencyCode(rawValue: monthlyLimitCurrencyRaw) ?? .byn
    }

    private var selectedSavingsGoal: SavingsGoal? {
        guard let id = UUID(uuidString: selectedSavingsGoalIDRaw) else { return nil }
        return savingsGoals.first { $0.id == id }
    }

    var body: some View {
        ZStack {
            switch router.activeSection {
            case .statistics:
                statisticsContent
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            case .history:
                HistoryView {
                    show(.statistics)
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            case .settings:
                SettingsView(
                    onBack: { show(.statistics) },
                    onAnalyticsReset: {
                        selectedMonth = MonthUtilities.startOfMonth(for: Date())
                        show(.statistics)
                    }
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            case .help:
                HelpView {
                    show(.statistics)
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(width: 420, height: 680)
        .clipped()
        .task {
            while !Task.isCancelled {
                await exchangeRateService.refreshIfNeeded()
                try? await Task.sleep(nanoseconds: 15 * 60 * 1_000_000_000)
            }
        }
    }

    private var statisticsContent: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Label("WhereCash", systemImage: "banknote.fill")
                        .font(.title3.bold())
                        .foregroundStyle(.cyan)
                    Spacer(minLength: 4)
                    RateStatusView()
                    Button {
                        show(.history)
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .buttonStyle(.borderless)
                    .help("История")
                    .accessibilityLabel("История")

                    Button {
                        show(.settings)
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .buttonStyle(.borderless)
                    .help("Настройки")
                    .accessibilityLabel("Настройки")
                }

                Divider()
                MonthNavigatorView(selectedMonth: $selectedMonth)

                StatisticsView(
                    expenses: monthlyExpenses,
                    selectedMonth: selectedMonth,
                    primaryCurrency: primaryCurrency,
                    showSecondaryCurrency: showSecondaryCurrency,
                    monthlyLimitMinor: monthlyLimitMinor,
                    monthlyLimitCurrency: monthlyLimitCurrency,
                    selectedSavingsGoal: selectedSavingsGoal,
                    savingsContributions: savingsContributions
                )
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 10)
            .frame(maxHeight: .infinity, alignment: .top)

            Divider()

            ExpenseEntryView {
                withAnimation(.easeInOut(duration: 0.35)) {
                    selectedMonth = MonthUtilities.startOfMonth(for: Date())
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(.background)
        }
    }

    private func show(_ section: PanelSection) {
        withAnimation(.easeInOut(duration: 0.28)) {
            router.show(section)
        }
    }
}
