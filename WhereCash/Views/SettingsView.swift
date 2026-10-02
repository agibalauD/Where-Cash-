import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var exchangeRateService: ExchangeRateService
    @EnvironmentObject private var telegramBotService: TelegramBotService
    @Query(sort: \SavingsGoal.createdAt) private var savingsGoals: [SavingsGoal]
    @Query(sort: \SavingsContribution.createdAt, order: .reverse) private var savingsContributions: [SavingsContribution]
    @AppStorage(AppSettingKeys.showSecondaryCurrency) private var showSecondaryCurrency = true
    @AppStorage(AppSettingKeys.lastCurrency) private var lastCurrencyRaw = CurrencyCode.byn.rawValue
    @AppStorage(AppSettingKeys.monthlyLimitMinor) private var monthlyLimitMinorRaw = ""
    @AppStorage(AppSettingKeys.monthlyLimitCurrency) private var monthlyLimitCurrencyRaw = CurrencyCode.byn.rawValue
    @AppStorage(AppSettingKeys.selectedSavingsGoalID) private var selectedSavingsGoalIDRaw = ""
    @AppStorage(AppSettingKeys.analyticsStartTimestamp) private var analyticsStartTimestamp = 0.0

    @State private var launchAtLogin = false
    @State private var limitAmountText = ""
    @State private var limitCurrency: CurrencyCode = .byn
    @State private var showCreateGoal = false
    @State private var goalToEdit: SavingsGoal?
    @State private var goalToDelete: SavingsGoal?
    @State private var showGoalDeleteConfirmation = false
    @State private var telegramToken = ""
    @State private var showTelegramDisconnectConfirmation = false
    @State private var showAnalyticsResetConfirmation = false
    @State private var errorMessage: String?

    let onBack: () -> Void
    let onAnalyticsReset: () -> Void

    private var primaryCurrency: CurrencyCode {
        CurrencyCode(rawValue: lastCurrencyRaw) ?? .byn
    }

    private var configuredLimitMinor: Int64? {
        Int64(monthlyLimitMinorRaw)
    }

    private var selectedSavingsGoalID: UUID? {
        UUID(uuidString: selectedSavingsGoalIDRaw)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: onBack) {
                    Label("Назад", systemImage: "chevron.left")
                }
                .buttonStyle(.plain)
                Spacer()
                Text("Настройки")
                    .font(.title3.bold())
                Spacer()
                Color.clear.frame(width: 52, height: 1)
            }
            .padding(.horizontal)

            Form {
                Section("Отображение") {
                    LabeledContent("Основная валюта", value: primaryCurrency.rawValue)
                    Toggle("Показывать вторую валюту", isOn: $showSecondaryCurrency)
                }

                Section("Период статистики") {
                    if let startDate = AnalyticsPeriod.startDate(from: analyticsStartTimestamp) {
                        LabeledContent(
                            "Текущий период",
                            value: startDate.formatted(date: .abbreviated, time: .shortened)
                        )
                    } else {
                        LabeledContent("Текущий период", value: "Вся история")
                    }

                    Button(role: .destructive) {
                        showAnalyticsResetConfirmation = true
                    } label: {
                        Label("Начать учёт заново", systemImage: "arrow.counterclockwise")
                    }

                    Text("Расходы останутся в истории как архив. Накопления и прогресс целей не изменятся.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Лимит расходов") {
                    HStack {
                        TextField("Сумма", text: $limitAmountText)
                            .onChange(of: limitAmountText) { _, newValue in
                                let sanitized = AmountParser.sanitized(newValue)
                                if sanitized != newValue { limitAmountText = sanitized }
                            }

                        Picker("Валюта", selection: $limitCurrency) {
                            ForEach(CurrencyCode.allCases) { currency in
                                Text(currency.rawValue).tag(currency)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 82)
                    }

                    HStack {
                        Button("Сохранить лимит", action: saveLimit)
                            .disabled(AmountParser.minorUnits(from: limitAmountText) == nil)
                        if configuredLimitMinor != nil {
                            Button("Убрать", role: .destructive, action: clearLimit)
                        }
                    }

                    Text("Лимит повторяется каждый месяц и не включает накопления.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Накопления") {
                    Button {
                        showCreateGoal = true
                    } label: {
                        Label("Создать цель", systemImage: "plus")
                    }

                    if savingsGoals.isEmpty {
                        Text("Создайте цель, затем отметьте её для показа и пополнения.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(savingsGoals, id: \.id) { goal in
                        savingsGoalRow(goal)
                    }
                }

                Section("Приложение") {
                    Toggle("Запускать после входа в macOS", isOn: Binding(
                        get: { launchAtLogin },
                        set: updateLaunchAtLogin
                    ))
                }

                Section("Telegram") {
                    if telegramBotService.isConfigured {
                        LabeledContent(
                            "Бот",
                            value: telegramBotService.botUsername.map { "@\($0)" } ?? "Подключён"
                        )
                        LabeledContent("Статус", value: telegramBotService.connectionStatus)

                        if telegramBotService.isPaired {
                            Label("Аккаунт владельца привязан", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else if let pairingCode = telegramBotService.pairingCode {
                            Text("Отправьте боту команду:")
                                .foregroundStyle(.secondary)
                            Text("/start \(pairingCode)")
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                            Button("Создать новый код") {
                                telegramBotService.regeneratePairingCode()
                            }
                        }

                        Button("Отключить бота", role: .destructive) {
                            showTelegramDisconnectConfirmation = true
                        }
                    } else {
                        SecureField("Токен от @BotFather", text: $telegramToken)
                            .textContentType(.password)

                        Button {
                            Task {
                                await telegramBotService.connect(token: telegramToken)
                                if telegramBotService.isConfigured {
                                    telegramToken = ""
                                }
                            }
                        } label: {
                            if telegramBotService.isConnecting {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("Подключить бота")
                            }
                        }
                        .disabled(
                            telegramToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                || telegramBotService.isConnecting
                        )
                    }

                    if let telegramError = telegramBotService.lastError {
                        Text(telegramError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Text("Бот работает локально, пока WhereCash запущен. Токен хранится в Keychain.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Курс НБ РБ") {
                    if let rate = exchangeRateService.latestRate {
                        LabeledContent("1 USD", value: String(format: "%.4f BYN", rate))
                        if let rateDate = exchangeRateService.rateDate {
                            LabeledContent("Дата", value: rateDate.formatted(date: .long, time: .omitted))
                        }
                    } else {
                        Text("Курс ещё не загружен")
                            .foregroundStyle(.secondary)
                    }

                    Button("Обновить курс") {
                        Task { await exchangeRateService.refreshIfNeeded(force: true) }
                    }
                    .disabled(exchangeRateService.isLoading)
                }
            }
            .formStyle(.grouped)
        }
        .padding(.vertical)
        .frame(width: 420, height: 680)
        .onAppear {
            launchAtLogin = LaunchAtLoginService.isEnabled
            loadLimitEditor()
        }
        .alert("Не удалось изменить автозапуск", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Неизвестная ошибка")
        }
        .confirmationDialog(
            "Отключить Telegram-бота?",
            isPresented: $showTelegramDisconnectConfirmation,
            titleVisibility: .visible
        ) {
            Button("Отключить", role: .destructive) {
                telegramBotService.disconnect()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Токен будет удалён из Keychain, а привязку аккаунта потребуется выполнить заново.")
        }
        .sheet(isPresented: $showCreateGoal) {
            SavingsGoalEditorView(goal: nil, hasContributions: false)
        }
        .sheet(item: $goalToEdit) { goal in
            SavingsGoalEditorView(
                goal: goal,
                hasContributions: savingsContributions.contains { $0.goalID == goal.id }
            )
        }
        .confirmationDialog(
            "Удалить цель?",
            isPresented: $showGoalDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Удалить цель и её пополнения", role: .destructive) {
                deleteSelectedGoal()
            }
            Button("Отмена", role: .cancel) { goalToDelete = nil }
        } message: {
            Text("История пополнений этой цели также будет удалена. Действие нельзя отменить.")
        }
        .overlay {
            if showAnalyticsResetConfirmation {
                analyticsResetOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(.easeInOut(duration: 0.16), value: showAnalyticsResetConfirmation)
    }

    private var analyticsResetOverlay: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    showAnalyticsResetConfirmation = false
                }

            VStack(spacing: 14) {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)

                Text("Начать новый период?")
                    .font(.headline)

                Text("Текущая аналитика обнулится. Все прежние расходы останутся в истории с отметкой «Архив», а накопления сохранятся.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 10) {
                    Button("Отмена") {
                        showAnalyticsResetConfirmation = false
                    }
                    .keyboardShortcut(.cancelAction)

                    Button("Начать заново", role: .destructive) {
                        resetAnalytics()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
            }
            .padding(22)
            .frame(maxWidth: 320)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .shadow(radius: 18, y: 8)
        }
    }

    @ViewBuilder
    private func savingsGoalRow(_ goal: SavingsGoal) -> some View {
        let relatedContributions = savingsContributions.filter { $0.goalID == goal.id }
        let currentMinor = SavingsCalculator.total(for: relatedContributions, goal: goal)
        let isCompleted = currentMinor.map { $0 >= goal.targetMinor } ?? false
        let isSelected = selectedSavingsGoalID == goal.id

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Button {
                    selectedSavingsGoalIDRaw = isSelected ? "" : goal.id.uuidString
                } label: {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .foregroundStyle(isSelected ? .cyan : .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isSelected ? "Не показывать цель" : "Показывать цель")

                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.name)
                        .font(.headline)
                    if isCompleted {
                        Label("Цель достигнута", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                Spacer()

                Button {
                    goalToEdit = goal
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)

                Button(role: .destructive) {
                    goalToDelete = goal
                    showGoalDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }

            SavingsProgressBar(
                currentMinor: currentMinor,
                targetMinor: goal.targetMinor,
                currency: goal.currency
            )
        }
        .padding(.vertical, 4)
    }

    private func loadLimitEditor() {
        if let limit = configuredLimitMinor {
            limitAmountText = CurrencyAmountFormatter.editString(minorUnits: limit)
        }
        limitCurrency = CurrencyCode(rawValue: monthlyLimitCurrencyRaw) ?? .byn
    }

    private func saveLimit() {
        guard let limitMinor = AmountParser.minorUnits(from: limitAmountText) else { return }
        monthlyLimitMinorRaw = String(limitMinor)
        monthlyLimitCurrencyRaw = limitCurrency.rawValue
    }

    private func clearLimit() {
        monthlyLimitMinorRaw = ""
        limitAmountText = ""
    }

    private func resetAnalytics() {
        showAnalyticsResetConfirmation = false
        analyticsStartTimestamp = Date().timeIntervalSince1970
        onAnalyticsReset()
    }

    private func deleteSelectedGoal() {
        guard let goalToDelete else { return }
        for contribution in savingsContributions where contribution.goalID == goalToDelete.id {
            modelContext.delete(contribution)
        }
        modelContext.delete(goalToDelete)

        if selectedSavingsGoalID == goalToDelete.id {
            selectedSavingsGoalIDRaw = ""
        }

        do {
            try modelContext.save()
            self.goalToDelete = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateLaunchAtLogin(_ newValue: Bool) {
        do {
            try LaunchAtLoginService.setEnabled(newValue)
            launchAtLogin = LaunchAtLoginService.isEnabled
        } catch {
            launchAtLogin = LaunchAtLoginService.isEnabled
            errorMessage = error.localizedDescription
        }
    }
}
