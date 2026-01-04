import Foundation
import Security

enum KeychainHelper {
    enum KeychainError: Error {
        case duplicateItem
        case itemNotFound
        case unexpectedStatus(OSStatus)
        case invalidData
    }

    private static let service = "com.glance.app"

    static func save(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecDuplicateItem {
            try update(key: key, value: value)
        } else if status != errSecSuccess {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    static func update(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    static func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    static func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}

extension KeychainHelper {
    enum Keys {
        static let backlogAPIKey = "backlog_api_key"
        static let openAIAPIKey = "openai_api_key"
        static let redmineAPIKey = "redmine_api_key"
        static let emailPassword = "email_password"
    }

    static var backlogAPIKey: String? {
        get { get(key: Keys.backlogAPIKey) }
        set {
            if let value = newValue {
                try? save(key: Keys.backlogAPIKey, value: value)
            } else {
                try? delete(key: Keys.backlogAPIKey)
            }
        }
    }

    static var openAIAPIKey: String? {
        get { get(key: Keys.openAIAPIKey) }
        set {
            if let value = newValue {
                try? save(key: Keys.openAIAPIKey, value: value)
            } else {
                try? delete(key: Keys.openAIAPIKey)
            }
        }
    }

    static var redmineAPIKey: String? {
        get { get(key: Keys.redmineAPIKey) }
        set {
            if let value = newValue {
                try? save(key: Keys.redmineAPIKey, value: value)
            } else {
                try? delete(key: Keys.redmineAPIKey)
            }
        }
    }

    static var emailPassword: String? {
        get { get(key: Keys.emailPassword) }
        set {
            if let value = newValue {
                try? save(key: Keys.emailPassword, value: value)
            } else {
                try? delete(key: Keys.emailPassword)
            }
        }
    }
}
