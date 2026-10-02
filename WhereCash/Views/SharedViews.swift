import SwiftUI

struct MonthNavigatorView: View {
    @Binding var selectedMonth: Date

    var body: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.35)) {
                    selectedMonth = MonthUtilities.previousMonth(from: selectedMonth)
                }
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Предыдущий месяц")

            Spacer()

            Text(MonthUtilities.title(for: selectedMonth))
                .font(.headline)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.35)) {
                    selectedMonth = MonthUtilities.nextMonth(from: selectedMonth)
                }
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
            .disabled(!MonthUtilities.canMoveToNextMonth(selectedMonth))
            .accessibilityLabel("Следующий месяц")
        }
    }
}

struct RateStatusView: View {
    @EnvironmentObject private var exchangeRateService: ExchangeRateService

    var body: some View {
        if exchangeRateService.isStale, exchangeRateService.latestRate != nil {
            Label("Используется сохранённый курс", systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        } else if exchangeRateService.latestRate == nil, exchangeRateService.lastError != nil {
            Label("Курс недоступен", systemImage: "wifi.exclamationmark")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
