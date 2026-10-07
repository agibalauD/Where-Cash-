import AppKit
import Charts
import SwiftUI

struct TelegramSavingsStatistic {
    let name: String
    let currentMinor: Int64?
    let targetMinor: Int64
    let currency: CurrencyCode
}

struct TelegramStatisticsSnapshot {
    let monthTitle: String
    let daysRemaining: Int
    let primaryCurrency: CurrencyCode
    let showSecondaryCurrency: Bool
    let primaryTotal: Int64?
    let secondaryTotal: Int64?
    let categoryTotals: [CategoryTotal]
    let limitMinor: Int64?
    let limitCurrency: CurrencyCode
    let limitSpentMinor: Int64?
    let savings: [TelegramSavingsStatistic]
}

enum TelegramStatisticsText {
    static func caption(for snapshot: TelegramStatisticsSnapshot) -> String {
        var lines = [
            "📊 \(snapshot.monthTitle)",
            "",
            "Потрачено: \(amount(snapshot.primaryTotal, currency: snapshot.primaryCurrency))"
        ]

        if snapshot.showSecondaryCurrency {
            lines.append("В другой валюте: \(amount(snapshot.secondaryTotal, currency: snapshot.primaryCurrency.other))")
        }

        lines.append("")
        for item in snapshot.categoryTotals {
            lines.append(
                "\(categoryEmoji(item.category)) \(item.category.title) — \(amount(item.amountMinor, currency: snapshot.primaryCurrency))"
            )
        }

        lines.append("")
        lines.append(limitText(for: snapshot))
        lines.append(contentsOf: savingsText(for: snapshot.savings))
        return lines.joined(separator: "\n")
    }

    private static func limitText(for snapshot: TelegramStatisticsSnapshot) -> String {
        guard let limitMinor = snapshot.limitMinor else {
            return "⚪️ Лимит не настроен"
        }
        guard let spentMinor = snapshot.limitSpentMinor else {
            return "⚪️ Лимит: курс недоступен"
        }

        if spentMinor > limitMinor {
            return "🔴 Лимит: превышение \(CurrencyAmountFormatter.string(minorUnits: spentMinor - limitMinor, currency: snapshot.limitCurrency))"
        }
        return "⚪️ Лимит: \(CurrencyAmountFormatter.string(minorUnits: spentMinor, currency: snapshot.limitCurrency)) из \(CurrencyAmountFormatter.string(minorUnits: limitMinor, currency: snapshot.limitCurrency))"
    }

    private static func savingsText(for savings: [TelegramSavingsStatistic]) -> [String] {
        guard !savings.isEmpty else {
            return ["⚪️ Цели накоплений не выбраны"]
        }
        return savings.map {
            "🟢 Накопления «\($0.name)»: \(amount($0.currentMinor, currency: $0.currency)) из \(CurrencyAmountFormatter.string(minorUnits: $0.targetMinor, currency: $0.currency))"
        }
    }

    private static func amount(_ minor: Int64?, currency: CurrencyCode) -> String {
        minor.map { CurrencyAmountFormatter.string(minorUnits: $0, currency: currency) } ?? "курс недоступен"
    }

    private static func categoryEmoji(_ category: ExpenseCategory) -> String {
        switch category {
        case .food: "🟢"
        case .transport: "🔵"
        case .entertainment: "🟣"
        case .purchases: "🟠"
        case .other: "🩷"
        case .savings: "🟢"
        }
    }
}

@MainActor
enum TelegramStatisticsRenderer {
    static func pngData(for snapshot: TelegramStatisticsSnapshot) -> Data? {
        let renderer = ImageRenderer(
            content: TelegramStatisticsCard(snapshot: snapshot)
                .frame(width: 720, height: 980)
                .environment(\.colorScheme, .dark)
        )
        renderer.scale = 1

        guard let image = renderer.nsImage,
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
}

private struct TelegramStatisticsCard: View {
    let snapshot: TelegramStatisticsSnapshot

    private var chartItems: [CategoryTotal] {
        snapshot.categoryTotals.filter { ($0.amountMinor ?? 0) > 0 }
    }

    private var chartAvailable: Bool {
        snapshot.categoryTotals.allSatisfy { $0.amountMinor != nil }
    }

    private var limitRatio: Double? {
        guard let limitMinor = snapshot.limitMinor,
              limitMinor > 0,
              let spentMinor = snapshot.limitSpentMinor else { return nil }
        return max(Double(spentMinor) / Double(limitMinor), 0)
    }

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 6) {
                Text("WhereCash")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.cyan)
                Text(snapshot.monthTitle)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }

            ZStack {
                Circle()
                    .stroke(.white.opacity(0.12), lineWidth: 16)

                if let limitRatio {
                    Circle()
                        .trim(from: 0, to: min(limitRatio, 1))
                        .stroke(
                            LimitColorScale.components(for: limitRatio).color,
                            style: StrokeStyle(lineWidth: 16, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                }

                if snapshot.limitMinor != nil {
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.8), radius: 3)
                        .offset(y: -149)
                }

                if chartAvailable && !chartItems.isEmpty {
                    Chart(chartItems) { item in
                        SectorMark(
                            angle: .value("Сумма", item.amountMinor ?? 0),
                            innerRadius: .ratio(0.72),
                            angularInset: 2
                        )
                        .cornerRadius(5)
                        .foregroundStyle(item.category.color)
                    }
                    .padding(28)
                } else {
                    Circle()
                        .stroke(.white.opacity(0.14), lineWidth: 38)
                        .padding(49)
                }

                VStack(spacing: 3) {
                    Text("\(snapshot.daysRemaining)")
                        .font(.system(size: 54, weight: .bold, design: .rounded))
                    Text("до конца месяца")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white.opacity(0.62))
                }
            }
            .frame(width: 320, height: 320)

            VStack(spacing: 6) {
                Text(formatted(snapshot.primaryTotal, currency: snapshot.primaryCurrency))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                if snapshot.showSecondaryCurrency {
                    Text(formatted(snapshot.secondaryTotal, currency: snapshot.primaryCurrency.other))
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.62))
                }
            }

            limitRow
            savingsRow

            VStack(spacing: 12) {
                ForEach(snapshot.categoryTotals) { item in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(item.category.color)
                            .frame(width: 16, height: 16)
                        Text(item.category.title)
                            .font(.system(size: 19, weight: .medium))
                        Spacer()
                        Text(formatted(item.amountMinor, currency: snapshot.primaryCurrency))
                            .font(.system(size: 19, weight: .semibold, design: .rounded))
                    }
                }
            }
        }
        .foregroundStyle(.white)
        .padding(42)
        .background(Color(red: 0.075, green: 0.085, blue: 0.105))
    }

    @ViewBuilder
    private var limitRow: some View {
        if let limitMinor = snapshot.limitMinor {
            HStack {
                Image(systemName: "gauge.with.dots.needle.67percent")
                    .foregroundStyle(limitRatio.map { LimitColorScale.components(for: $0).color } ?? .secondary)
                if let spentMinor = snapshot.limitSpentMinor {
                    if spentMinor > limitMinor {
                        Text("Превышение \(CurrencyAmountFormatter.string(minorUnits: spentMinor - limitMinor, currency: snapshot.limitCurrency))")
                            .foregroundStyle(.red)
                    } else {
                        Text("\(CurrencyAmountFormatter.string(minorUnits: spentMinor, currency: snapshot.limitCurrency)) из \(CurrencyAmountFormatter.string(minorUnits: limitMinor, currency: snapshot.limitCurrency))")
                    }
                } else {
                    Text("Лимит: курс недоступен")
                }
            }
            .font(.system(size: 18, weight: .semibold))
        } else {
            Label("Месячный лимит не настроен", systemImage: "gauge.with.dots.needle.67percent")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    @ViewBuilder
    private var savingsRow: some View {
        if snapshot.savings.isEmpty {
            Label("Цели накоплений не выбраны", systemImage: "target")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(snapshot.savings.enumerated()), id: \.offset) { _, savings in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Label(savings.name, systemImage: "target")
                            Spacer()
                            Text("\(formatted(savings.currentMinor, currency: savings.currency)) из \(CurrencyAmountFormatter.string(minorUnits: savings.targetMinor, currency: savings.currency))")
                        }
                        .font(.system(size: 17, weight: .semibold))

                        ProgressView(
                            value: min(Double(savings.currentMinor ?? 0) / Double(max(savings.targetMinor, 1)), 1)
                        )
                        .tint(.green)
                    }
                }
            }
        }
    }

    private func formatted(_ amount: Int64?, currency: CurrencyCode) -> String {
        amount.map { CurrencyAmountFormatter.string(minorUnits: $0, currency: currency) } ?? "Курс недоступен"
    }
}
