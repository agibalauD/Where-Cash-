import Foundation

struct TelegramUser: Decodable {
    let id: Int64
    let isBot: Bool
    let firstName: String
    let username: String?

    enum CodingKeys: String, CodingKey {
        case id
        case isBot = "is_bot"
        case firstName = "first_name"
        case username
    }
}

struct TelegramChat: Decodable {
    let id: Int64
    let type: String
}

struct TelegramMessage: Decodable {
    let messageID: Int64
    let from: TelegramUser?
    let chat: TelegramChat
    let text: String?

    enum CodingKeys: String, CodingKey {
        case messageID = "message_id"
        case from
        case chat
        case text
    }
}

struct TelegramCallbackQuery: Decodable {
    let id: String
    let from: TelegramUser
    let message: TelegramMessage?
    let data: String?
}

struct TelegramUpdate: Decodable {
    let updateID: Int64
    let message: TelegramMessage?
    let callbackQuery: TelegramCallbackQuery?

    enum CodingKeys: String, CodingKey {
        case updateID = "update_id"
        case message
        case callbackQuery = "callback_query"
    }
}

struct TelegramInlineButton: Encodable {
    let text: String
    let callbackData: String

    enum CodingKeys: String, CodingKey {
        case text
        case callbackData = "callback_data"
    }
}

struct TelegramInlineKeyboard: Encodable {
    let inlineKeyboard: [[TelegramInlineButton]]

    enum CodingKeys: String, CodingKey {
        case inlineKeyboard = "inline_keyboard"
    }
}

struct TelegramReplyKeyboardButton: Encodable {
    let text: String
}

struct TelegramReplyKeyboard: Encodable {
    let keyboard: [[TelegramReplyKeyboardButton]]
    let resizeKeyboard: Bool
    let isPersistent: Bool

    enum CodingKeys: String, CodingKey {
        case keyboard
        case resizeKeyboard = "resize_keyboard"
        case isPersistent = "is_persistent"
    }
}

struct TelegramBotCommand: Encodable {
    let command: String
    let description: String
}

struct TelegramAPIClient: Sendable {
    let token: String

    func getMe() async throws -> TelegramUser {
        try await request("getMe", body: EmptyRequest())
    }

    func deleteWebhook() async throws {
        let _: Bool = try await request("deleteWebhook", body: DeleteWebhookRequest(dropPendingUpdates: false))
    }

    func getUpdates(offset: Int64?) async throws -> [TelegramUpdate] {
        try await request(
            "getUpdates",
            body: GetUpdatesRequest(
                offset: offset,
                timeout: 25,
                allowedUpdates: ["message", "callback_query"]
            )
        )
    }

    func sendMessage(
        chatID: Int64,
        text: String,
        keyboard: TelegramInlineKeyboard? = nil
    ) async throws {
        let _: TelegramMessage = try await request(
            "sendMessage",
            body: SendMessageRequest(chatID: chatID, text: text, replyMarkup: keyboard)
        )
    }

    func sendMessage(
        chatID: Int64,
        text: String,
        replyKeyboard: TelegramReplyKeyboard
    ) async throws {
        let _: TelegramMessage = try await request(
            "sendMessage",
            body: SendReplyKeyboardMessageRequest(
                chatID: chatID,
                text: text,
                replyMarkup: replyKeyboard
            )
        )
    }

    func sendPhoto(
        chatID: Int64,
        pngData: Data,
        caption: String
    ) async throws {
        let boundary = "WhereCash-\(UUID().uuidString)"
        var body = Data()
        body.appendMultipartField(name: "chat_id", value: String(chatID), boundary: boundary)
        body.appendMultipartField(name: "caption", value: caption, boundary: boundary)
        body.appendMultipartFile(
            name: "photo",
            filename: "wherecash-statistics.png",
            mimeType: "image/png",
            data: pngData,
            boundary: boundary
        )
        body.appendUTF8("--\(boundary)--\r\n")

        let _: TelegramMessage = try await multipartRequest(
            "sendPhoto",
            body: body,
            boundary: boundary
        )
    }

    func setMyCommands(_ commands: [TelegramBotCommand]) async throws {
        let _: Bool = try await request(
            "setMyCommands",
            body: SetMyCommandsRequest(commands: commands)
        )
    }

    func answerCallbackQuery(
        id: String,
        text: String? = nil,
        showAlert: Bool = false
    ) async throws {
        let _: Bool = try await request(
            "answerCallbackQuery",
            body: AnswerCallbackRequest(callbackQueryID: id, text: text, showAlert: showAlert)
        )
    }

    private func request<Response: Decodable, Body: Encodable>(
        _ method: String,
        body: Body
    ) async throws -> Response {
        guard let url = URL(string: "https://api.telegram.org/bot\(token)/\(method)") else {
            throw TelegramAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw TelegramAPIError.invalidResponse
        }

        let envelope = try JSONDecoder().decode(TelegramResponse<Response>.self, from: data)
        guard envelope.ok, let result = envelope.result else {
            throw TelegramAPIError.api(envelope.description ?? "Telegram вернул ошибку")
        }
        return result
    }

    private func multipartRequest<Response: Decodable>(
        _ method: String,
        body: Data,
        boundary: String
    ) async throws -> Response {
        guard let url = URL(string: "https://api.telegram.org/bot\(token)/\(method)") else {
            throw TelegramAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw TelegramAPIError.invalidResponse
        }

        let envelope = try JSONDecoder().decode(TelegramResponse<Response>.self, from: data)
        guard envelope.ok, let result = envelope.result else {
            throw TelegramAPIError.api(envelope.description ?? "Telegram вернул ошибку")
        }
        return result
    }
}

private struct TelegramResponse<Result: Decodable>: Decodable {
    let ok: Bool
    let result: Result?
    let description: String?
}

private struct EmptyRequest: Encodable {}

private struct DeleteWebhookRequest: Encodable {
    let dropPendingUpdates: Bool

    enum CodingKeys: String, CodingKey {
        case dropPendingUpdates = "drop_pending_updates"
    }
}

private struct GetUpdatesRequest: Encodable {
    let offset: Int64?
    let timeout: Int
    let allowedUpdates: [String]

    enum CodingKeys: String, CodingKey {
        case offset
        case timeout
        case allowedUpdates = "allowed_updates"
    }
}

private struct SendMessageRequest: Encodable {
    let chatID: Int64
    let text: String
    let replyMarkup: TelegramInlineKeyboard?

    enum CodingKeys: String, CodingKey {
        case chatID = "chat_id"
        case text
        case replyMarkup = "reply_markup"
    }
}

private struct SendReplyKeyboardMessageRequest: Encodable {
    let chatID: Int64
    let text: String
    let replyMarkup: TelegramReplyKeyboard

    enum CodingKeys: String, CodingKey {
        case chatID = "chat_id"
        case text
        case replyMarkup = "reply_markup"
    }
}

private struct SetMyCommandsRequest: Encodable {
    let commands: [TelegramBotCommand]
}

private struct AnswerCallbackRequest: Encodable {
    let callbackQueryID: String
    let text: String?
    let showAlert: Bool

    enum CodingKeys: String, CodingKey {
        case callbackQueryID = "callback_query_id"
        case text
        case showAlert = "show_alert"
    }
}

enum TelegramAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case api(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Некорректный адрес Telegram Bot API."
        case .invalidResponse:
            return "Telegram вернул некорректный ответ."
        case let .api(message):
            return message
        }
    }
}

private extension Data {
    mutating func appendUTF8(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }

    mutating func appendMultipartField(name: String, value: String, boundary: String) {
        appendUTF8("--\(boundary)\r\n")
        appendUTF8("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        appendUTF8("\(value)\r\n")
    }

    mutating func appendMultipartFile(
        name: String,
        filename: String,
        mimeType: String,
        data: Data,
        boundary: String
    ) {
        appendUTF8("--\(boundary)\r\n")
        appendUTF8("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        appendUTF8("Content-Type: \(mimeType)\r\n\r\n")
        append(data)
        appendUTF8("\r\n")
    }
}
