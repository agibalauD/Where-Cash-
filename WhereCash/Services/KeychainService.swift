import Foundation
import Security

enum KeychainService {
    private static let service = Bundle.main.bundleIdentifier ?? "com.wherecash.desktop"
    private static let telegramTokenAccount = "telegramBotToken"

    static func telegramBotToken() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: telegramTokenAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError(status: status) }
        guard let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }

        // Upgrade tokens created by earlier builds without exposing or
        // replacing their value. This keeps an existing user's token on this
        // unlocked Mac only as soon as the updated application starts.
        let accessQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: telegramTokenAccount
        ]
        let accessAttributes: [String: Any] = [
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let accessStatus = SecItemUpdate(accessQuery as CFDictionary, accessAttributes as CFDictionary)
        guard accessStatus == errSecSuccess else { throw KeychainError(status: accessStatus) }

        return token
    }

    static func saveTelegramBotToken(_ token: String) throws {
        let tokenData = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: telegramTokenAccount
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: tokenData,
            // Keep the bot token encrypted by Keychain, available only while
            // this Mac is unlocked, and never migrate it to another device.
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else { throw KeychainError(status: updateStatus) }

        var newItem = query
        attributes.forEach { newItem[$0.key] = $0.value }
        let addStatus = SecItemAdd(newItem as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw KeychainError(status: addStatus) }
    }

    static func deleteTelegramBotToken() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: telegramTokenAccount
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }
}

enum KeychainError: LocalizedError {
    case invalidData
    case system(OSStatus)

    init(status: OSStatus) {
        self = .system(status)
    }

    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Не удалось прочитать токен из Keychain."
        case let .system(status):
            let message = SecCopyErrorMessageString(status, nil) as String?
            return message ?? "Ошибка Keychain: \(status)"
        }
    }
}
