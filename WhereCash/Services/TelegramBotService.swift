import Foundation
import SwiftData

enum TelegramCallbackData: Equatable {
    case currency(sessionID: String, currency: CurrencyCode)
    case category(sessionID: String, category: ExpenseCategory)
    case statistics

    var rawValue: String {
        switch self {
        case let .currency(sessionID, currency):
            return "currency:\(sessionID):\(currency.rawValue)"
        case let .category(sessionID, category):
            return "category:\(sessionID):\(category.rawValue)"
        case .statistics:
            return "statistics:current"
        }
    }

    init?(rawValue: String) {
        let components = rawValue.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        if components == ["statistics", "current"] {
            self = .statistics
            return
        }
        guard components.count == 3, !components[1].isEmpty else { return nil }

        switch components[0] {
        case "currency":
            guard let currency = CurrencyCode(rawValue: components[2]) else { return nil }
            self = .currency(sessionID: components[1], currency: currency)
        case "category":
            guard let category = ExpenseCategory(rawValue: components[2]) else { return nil }
            self = .category(sessionID: components[1], category: category)
        default:
            return nil
        }
    }
}

@MainActor
final class TelegramBotService: ObservableObject {
    @Published private(set) var isConfigured = false
    @Published private(set) var isPaired = false
    @Published private(set) var isConnecting = false
    @Published private(set) var connectionStatus = "Не настроен"
    @Published private(set) var botUsername: String?
    @Published private(set) var pairingCode: String?
    @Published private(set) var lastError: String?

    private struct PendingExpense {
        let sessionID: String
        let amountMinor: Int64
        var currency: CurrencyCode?
    }

    private let modelContext: ModelContext
    private let exchangeRateService: ExchangeRateService
    private let defaults: UserDefaults
    private var token: String?
    private var ownerUserID: Int64?
    private var ownerChatID: Int64?
    private var lastUpdateID: Int64?
    private var pendingExpense: PendingExpense?
    private var pollingTask: Task<Void, Never>?

    init(
        modelContainer: ModelContainer,
        exchangeRateService: ExchangeRateService,
        defaults: UserDefaults = .standard
    ) {
        modelContext = modelContainer.mainContext
        self.exchangeRateService = exchangeRateService
        self.defaults = defaults

        do {
            token = try KeychainService.telegramBotToken()
        } catch {
            lastError = error.localizedDescription
        }

        ownerUserID = Self.storedInt64(forKey: AppSettingKeys.telegramOwnerUserID, defaults: defaults)
        ownerChatID = Self.storedInt64(forKey: AppSettingKeys.telegramChatID, defaults: defaults)
        lastUpdateID = Self.storedInt64(forKey: AppSettingKeys.telegramLastUpdateID, defaults: defaults)
        botUsername = defaults.string(forKey: AppSettingKeys.telegramBotUsername)
        isConfigured = token != nil
        isPaired = ownerUserID != nil && ownerChatID != nil
        connectionStatus = isConfigured ? "Готов к запуску" : "Не настроен"

        if isConfigured && !isPaired {
            pairingCode = Self.makePairingCode()
        }
    }

    func start() {
        guard pollingTask == nil, let token else { return }
        pollingTask = Task { [weak self] in
            await self?.poll(token: token)
        }
    }

    func connect(token rawToken: String) async {
        let newToken = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newToken.isEmpty else {
            lastError = "Введите токен, полученный у @BotFather."
            return
        }

        pollingTask?.cancel()
        pollingTask = nil
        isConnecting = true
        connectionStatus = "Проверка токена…"
        lastError = nil

        do {
            let client = TelegramAPIClient(token: newToken)
            let bot = try await client.getMe()
            guard bot.isBot else { throw TelegramAPIError.api("Токен не принадлежит Telegram-боту.") }
            try await client.deleteWebhook()
            try? await client.setMyCommands(Self.botCommands)
            try KeychainService.saveTelegramBotToken(newToken)

            token = newToken
            botUsername = bot.username
            defaults.set(bot.username, forKey: AppSettingKeys.telegramBotUsername)
            isConfigured = true
            if !isPaired { pairingCode = Self.makePairingCode() }
            connectionStatus = isPaired ? "Подключён" : "Ожидает привязки"
            isConnecting = false
            start()
        } catch {
            isConnecting = false
            connectionStatus = "Ошибка подключения"
            lastError = Self.userFacingMessage(for: error)
        }
    }

    func disconnect() {
        pollingTask?.cancel()
        pollingTask = nil
        pendingExpense = nil
        lastError = nil

        do {
            try KeychainService.deleteTelegramBotToken()
        } catch {
            lastError = error.localizedDescription
        }

        token = nil
        ownerUserID = nil
        ownerChatID = nil
        lastUpdateID = nil
        botUsername = nil
        pairingCode = nil
        isConfigured = false
        isPaired = false
        isConnecting = false
        connectionStatus = "Не настроен"

        defaults.removeObject(forKey: AppSettingKeys.telegramOwnerUserID)
        defaults.removeObject(forKey: AppSettingKeys.telegramChatID)
        defaults.removeObject(forKey: AppSettingKeys.telegramLastUpdateID)
        defaults.removeObject(forKey: AppSettingKeys.telegramBotUsername)
    }

    func regeneratePairingCode() {
        guard isConfigured, !isPaired else { return }
        pairingCode = Self.makePairingCode()
    }

    private func poll(token: String) async {
        let client = TelegramAPIClient(token: token)
        var retryDelay: UInt64 = 1

        if botUsername == nil {
            do {
                let bot = try await client.getMe()
                botUsername = bot.username
                defaults.set(bot.username, forKey: AppSettingKeys.telegramBotUsername)
            } catch {
                lastError = Self.userFacingMessage(for: error)
            }
        }

        try? await client.setMyCommands(Self.botCommands)
        if isPaired, let ownerChatID {
            try? await client.sendMessage(
                chatID: ownerChatID,
                text: "WhereCash запущен. Выберите действие:",
                replyKeyboard: mainKeyboard()
            )
        }

        while !Task.isCancelled {
            do {
                connectionStatus = isPaired ? "Подключён" : "Ожидает привязки"
                let updates = try await client.getUpdates(offset: lastUpdateID.map { $0 + 1 })
                retryDelay = 1
                lastError = nil

                for update in updates {
                    if Task.isCancelled { return }
                    await handle(update, client: client)
                    lastUpdateID = update.updateID
                    defaults.set(update.updateID, forKey: AppSettingKeys.telegramLastUpdateID)
                }
            } catch {
                if Task.isCancelled { return }
                connectionStatus = "Повторное подключение…"
                lastError = Self.userFacingMessage(for: error)
                try? await Task.sleep(nanoseconds: retryDelay * 1_000_000_000)
                retryDelay = min(retryDelay * 2, 30)
            }
        }
    }

    private func handle(_ update: TelegramUpdate, client: TelegramAPIClient) async {
        if let message = update.message {
            await handle(message, client: client)
        } else if let callback = update.callbackQuery {
            await handle(callback, client: client)
        }
    }

    private func handle(_ message: TelegramMessage, client: TelegramAPIClient) async {
        guard message.chat.type == "private",
              let sender = message.from,
              !sender.isBot,
              let text = message.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return }

        if !isPaired {
            await handlePairing(text: text, sender: sender, chat: message.chat, client: client)
            return
        }

        guard sender.id == ownerUserID, message.chat.id == ownerChatID else {
            try? await client.sendMessage(chatID: message.chat.id, text: "Этот бот доступен только владельцу WhereCash.")
            return
        }

        if text.caseInsensitiveCompare(Self.addButtonTitle) == .orderedSame {
            pendingExpense = nil
            try? await client.sendMessage(
                chatID: message.chat.id,
                text: "Введите сумму, например 12,50:",
                replyKeyboard: mainKeyboard()
            )
            return
        }

        if text.caseInsensitiveCompare(Self.statisticsButtonTitle) == .orderedSame {
            await sendCurrentStatistics(chatID: message.chat.id, client: client)
            return
        }

        let command = Self.command(in: text)

        if command == "/cancel" {
            pendingExpense = nil
            try? await client.sendMessage(
                chatID: message.chat.id,
                text: "Добавление операции отменено. Отправьте новую сумму.",
                replyKeyboard: mainKeyboard()
            )
            return
        }

        if command == "/stats" {
            await sendCurrentStatistics(chatID: message.chat.id, client: client)
            return
        }

        if text.hasPrefix("/") {
            try? await client.sendMessage(
                chatID: message.chat.id,
                text: "Отправьте сумму, например 12,50. Для статистики используйте /stats, для отмены — /cancel.",
                replyKeyboard: mainKeyboard()
            )
            return
        }

        guard let amountMinor = AmountParser.minorUnits(from: text) else {
            try? await client.sendMessage(
                chatID: message.chat.id,
                text: "Не удалось распознать сумму. Используйте положительное число с максимум двумя знаками: 12,50."
            )
            return
        }

        let sessionID = String(UUID().uuidString.prefix(8)).uppercased()
        pendingExpense = PendingExpense(sessionID: sessionID, amountMinor: amountMinor, currency: nil)
        let keyboard = TelegramInlineKeyboard(inlineKeyboard: [[
            TelegramInlineButton(
                text: "BYN",
                callbackData: TelegramCallbackData.currency(sessionID: sessionID, currency: .byn).rawValue
            ),
            TelegramInlineButton(
                text: "USD",
                callbackData: TelegramCallbackData.currency(sessionID: sessionID, currency: .usd).rawValue
            )
        ]])
        try? await client.sendMessage(chatID: message.chat.id, text: "В какой валюте добавить сумму?", keyboard: keyboard)
    }

    private func handlePairing(
        text: String,
        sender: TelegramUser,
        chat: TelegramChat,
        client: TelegramAPIClient
    ) async {
        let parts = text.split(whereSeparator: \.isWhitespace).map(String.init)
        guard parts.count == 2,
              Self.command(in: parts[0]) == "/start",
              let pairingCode,
              parts[1].uppercased() == pairingCode else {
            try? await client.sendMessage(
                chatID: chat.id,
                text: "Откройте настройки WhereCash и отправьте команду привязки, показанную в разделе Telegram."
            )
            return
        }

        ownerUserID = sender.id
        ownerChatID = chat.id
        defaults.set(sender.id, forKey: AppSettingKeys.telegramOwnerUserID)
        defaults.set(chat.id, forKey: AppSettingKeys.telegramChatID)
        isPaired = true
        self.pairingCode = nil
        connectionStatus = "Подключён"
        try? await client.sendMessage(
            chatID: chat.id,
            text: "WhereCash подключён. Отправьте сумму, например 12,50, или откройте статистику текущего месяца.",
            replyKeyboard: mainKeyboard()
        )
    }

    private func handle(_ callback: TelegramCallbackQuery, client: TelegramAPIClient) async {
        guard isPaired,
              callback.from.id == ownerUserID,
              callback.message?.chat.id == ownerChatID,
              let rawData = callback.data,
              let action = TelegramCallbackData(rawValue: rawData) else {
            try? await client.answerCallbackQuery(
                id: callback.id,
                text: "Сессия устарела. Отправьте сумму снова.",
                showAlert: true
            )
            return
        }

        if action == .statistics {
            try? await client.answerCallbackQuery(id: callback.id, text: "Статистика за текущий месяц")
            await sendCurrentStatistics(
                chatID: callback.message?.chat.id ?? ownerChatID ?? 0,
                client: client
            )
            return
        }

        guard var pendingExpense else {
            try? await client.answerCallbackQuery(
                id: callback.id,
                text: "Сессия устарела. Отправьте сумму снова.",
                showAlert: true
            )
            return
        }

        switch action {
        case let .currency(sessionID, currency):
            guard sessionID == pendingExpense.sessionID else {
                try? await client.answerCallbackQuery(id: callback.id, text: "Сессия устарела.", showAlert: true)
                return
            }

            pendingExpense.currency = currency
            self.pendingExpense = pendingExpense
            try? await client.answerCallbackQuery(id: callback.id, text: currency.rawValue)
            try? await client.sendMessage(
                chatID: callback.message?.chat.id ?? ownerChatID ?? 0,
                text: "Выберите категорию:",
                keyboard: categoryKeyboard(sessionID: sessionID)
            )

        case let .category(sessionID, category):
            guard sessionID == pendingExpense.sessionID,
                  let currency = pendingExpense.currency else {
                try? await client.answerCallbackQuery(id: callback.id, text: "Сначала выберите валюту.", showAlert: true)
                return
            }

            try? await client.answerCallbackQuery(id: callback.id, text: category.title)
            await saveExpense(
                amountMinor: pendingExpense.amountMinor,
                currency: currency,
                category: category,
                chatID: callback.message?.chat.id ?? ownerChatID ?? 0,
                client: client
            )
        case .statistics:
            break
        }
    }

    private func categoryKeyboard(sessionID: String) -> TelegramInlineKeyboard {
        let buttons = ExpenseCategory.allCases.map { category in
            TelegramInlineButton(
                text: "\(Self.emoji(for: category)) \(category.title)",
                callbackData: TelegramCallbackData.category(sessionID: sessionID, category: category).rawValue
            )
        }
        return TelegramInlineKeyboard(inlineKeyboard: [
            Array(buttons.prefix(2)),
            Array(buttons.dropFirst(2).prefix(2)),
            Array(buttons.dropFirst(4))
        ])
    }

    private func mainKeyboard() -> TelegramReplyKeyboard {
        TelegramReplyKeyboard(
            keyboard: [[
                TelegramReplyKeyboardButton(text: Self.addButtonTitle),
                TelegramReplyKeyboardButton(text: Self.statisticsButtonTitle)
            ]],
            resizeKeyboard: true,
            isPersistent: true
        )
    }

    private func saveExpense(
        amountMinor: Int64,
        currency: CurrencyCode,
        category: ExpenseCategory,
        chatID: Int64,
        client: TelegramAPIClient
    ) async {
        await exchangeRateService.refreshIfNeeded()
        let quote = exchangeRateService.currentQuote

        if category == .savings {
            guard let goal = selectedSavingsGoal() else {
                pendingExpense = nil
                try? await client.sendMessage(
                    chatID: chatID,
                    text: "Пополнение не сохранено. Выберите цель накоплений в настройках WhereCash и отправьте сумму заново."
                )
                return
            }

            guard currency == goal.currency || quote != nil else {
                pendingExpense = nil
                try? await client.sendMessage(
                    chatID: chatID,
                    text: "Пополнение не сохранено: для другой валюты нужен актуальный или сохранённый курс."
                )
                return
            }

            let contribution = SavingsContribution(
                goalID: goal.id,
                amountMinor: amountMinor,
                currency: currency,
                bynPerUSD: quote?.rate,
                rateDate: quote?.date,
                usedStaleRate: quote?.isStale ?? false
            )
            modelContext.insert(contribution)
            do {
                try modelContext.save()
                defaults.set(currency.rawValue, forKey: AppSettingKeys.lastCurrency)
                pendingExpense = nil
                let amount = CurrencyAmountFormatter.string(minorUnits: amountMinor, currency: currency)
                try? await client.sendMessage(
                    chatID: chatID,
                    text: "Добавлено в цель «\(goal.name)»: \(amount).",
                    replyKeyboard: mainKeyboard()
                )
            } catch {
                modelContext.delete(contribution)
                pendingExpense = nil
                try? await client.sendMessage(chatID: chatID, text: "Не удалось сохранить пополнение в WhereCash.")
            }
            return
        }

        let expense = ExpenseRecord(
            amountMinor: amountMinor,
            currency: currency,
            category: category,
            bynPerUSD: quote?.rate,
            rateDate: quote?.date,
            usedStaleRate: quote?.isStale ?? false
        )

        modelContext.insert(expense)
        do {
            try modelContext.save()
            defaults.set(currency.rawValue, forKey: AppSettingKeys.lastCurrency)
            pendingExpense = nil
            let amount = CurrencyAmountFormatter.string(minorUnits: amountMinor, currency: currency)
            try? await client.sendMessage(
                chatID: chatID,
                text: "Добавлено: \(amount) — \(category.title).",
                replyKeyboard: mainKeyboard()
            )
        } catch {
            modelContext.delete(expense)
            try? await client.sendMessage(chatID: chatID, text: "Не удалось сохранить расход в WhereCash.")
        }
    }

    private func selectedSavingsGoal() -> SavingsGoal? {
        guard let rawID = defaults.string(forKey: AppSettingKeys.selectedSavingsGoalID),
              let id = UUID(uuidString: rawID),
              let goals = try? modelContext.fetch(FetchDescriptor<SavingsGoal>()) else { return nil }
        return goals.first { $0.id == id }
    }

    private func sendCurrentStatistics(chatID: Int64, client: TelegramAPIClient) async {
        do {
            let snapshot = try currentStatisticsSnapshot()
            guard let pngData = TelegramStatisticsRenderer.pngData(for: snapshot) else {
                throw TelegramStatisticsError.renderingFailed
            }
            try await client.sendPhoto(
                chatID: chatID,
                pngData: pngData,
                caption: TelegramStatisticsText.caption(for: snapshot)
            )
        } catch {
            try? await client.sendMessage(
                chatID: chatID,
                text: "Не удалось сформировать статистику текущего месяца. Попробуйте ещё раз."
            )
        }
    }

    private func currentStatisticsSnapshot(now: Date = Date()) throws -> TelegramStatisticsSnapshot {
        let allExpenses = try modelContext.fetch(FetchDescriptor<ExpenseRecord>())
        let expenses = allExpenses.filter {
            MonthUtilities.contains($0.createdAt, inMonth: now) && ExpenseCategory.spendingCases.contains($0.category)
        }

        let primaryCurrency = defaults.string(forKey: AppSettingKeys.lastCurrency)
            .flatMap(CurrencyCode.init(rawValue:)) ?? .byn
        let showSecondaryCurrency = defaults.object(forKey: AppSettingKeys.showSecondaryCurrency) == nil
            ? true
            : defaults.bool(forKey: AppSettingKeys.showSecondaryCurrency)

        let limitMinor = defaults.string(forKey: AppSettingKeys.monthlyLimitMinor)
            .flatMap(Int64.init)
            .flatMap { $0 > 0 ? $0 : nil }
        let limitCurrency = defaults.string(forKey: AppSettingKeys.monthlyLimitCurrency)
            .flatMap(CurrencyCode.init(rawValue:)) ?? .byn
        let limitSpentMinor = limitMinor == nil
            ? nil
            : ExpenseCalculator.total(for: expenses, in: limitCurrency)

        let savingsStatistic: TelegramSavingsStatistic?
        if let goal = selectedSavingsGoal() {
            let contributions = try modelContext.fetch(FetchDescriptor<SavingsContribution>())
            savingsStatistic = TelegramSavingsStatistic(
                name: goal.name,
                currentMinor: SavingsCalculator.total(for: contributions, goal: goal),
                targetMinor: goal.targetMinor,
                currency: goal.currency
            )
        } else {
            savingsStatistic = nil
        }

        return TelegramStatisticsSnapshot(
            monthTitle: MonthUtilities.title(for: now),
            daysRemaining: MonthUtilities.dayCountValue(for: now, now: now),
            primaryCurrency: primaryCurrency,
            showSecondaryCurrency: showSecondaryCurrency,
            primaryTotal: ExpenseCalculator.total(for: expenses, in: primaryCurrency),
            secondaryTotal: ExpenseCalculator.total(for: expenses, in: primaryCurrency.other),
            categoryTotals: ExpenseCalculator.categoryTotals(for: expenses, in: primaryCurrency),
            limitMinor: limitMinor,
            limitCurrency: limitCurrency,
            limitSpentMinor: limitSpentMinor,
            savings: savingsStatistic
        )
    }

    private static func command(in text: String) -> String? {
        guard let first = text.split(whereSeparator: \.isWhitespace).first else { return nil }
        return first.split(separator: "@").first.map(String.init)?.lowercased()
    }

    private static func storedInt64(forKey key: String, defaults: UserDefaults) -> Int64? {
        guard let number = defaults.object(forKey: key) as? NSNumber else { return nil }
        return number.int64Value
    }

    private static func makePairingCode() -> String {
        String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8)).uppercased()
    }

    private static let botCommands = [
        TelegramBotCommand(command: "stats", description: "Статистика текущего месяца"),
        TelegramBotCommand(command: "cancel", description: "Отменить добавление операции")
    ]

    private static let addButtonTitle = "Добавить"
    private static let statisticsButtonTitle = "Статистика"

    private static func emoji(for category: ExpenseCategory) -> String {
        switch category {
        case .food: "🍽"
        case .transport: "🚕"
        case .entertainment: "🎮"
        case .purchases: "🛍"
        case .other: "📦"
        case .savings: "🎯"
        }
    }

    private static func userFacingMessage(for error: Error) -> String {
        if let urlError = error as? URLError, urlError.code == .notConnectedToInternet {
            return "Нет подключения к интернету."
        }
        return error.localizedDescription
    }
}

private enum TelegramStatisticsError: Error {
    case renderingFailed
}
