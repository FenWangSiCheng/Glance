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
        let data = try encodedData(for: value)

        var query = baseQuery(for: key)
        query[kSecValueData as String] = data

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecDuplicateItem {
            try update(key: key, value: value)
        } else if status != errSecSuccess {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    static func update(key: String, value: String) throws {
        let data = try encodedData(for: value)
        let query = baseQuery(for: key)

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    static func get(key: String) -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
            let data = result as? Data,
            let value = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        return value
    }

    static func delete(key: String) throws {
        let status = SecItemDelete(baseQuery(for: key) as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private static func baseQuery(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
    }

    private static func encodedData(for value: String) throws -> Data {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        return data
    }
}

// MARK: - Unified Credentials Storage

struct Credentials: Codable {
    var backlogAPIKey: String = ""
    var openAIAPIKey: String = ""
    var redmineAPIKey: String = ""
    var emailPassword: String = ""
}

extension KeychainHelper {
    private static let credentialsKey = "credentials"

    static func getCredentials() -> Credentials {
        guard let jsonString = get(key: credentialsKey),
            let data = jsonString.data(using: .utf8)
        else {
            return Credentials()
        }
        do {
            return try JSONDecoder().decode(Credentials.self, from: data)
        } catch {
            print("❌ [KeychainHelper] Failed to decode credentials: \(error)")
            return Credentials()
        }
    }

    static func saveCredentials(_ credentials: Credentials) {
        do {
            let data = try JSONEncoder().encode(credentials)
            guard let jsonString = String(data: data, encoding: .utf8) else {
                print("❌ [KeychainHelper] Failed to encode credentials to string")
                return
            }
            try save(key: credentialsKey, value: jsonString)
        } catch {
            print("❌ [KeychainHelper] Failed to save credentials: \(error)")
        }
    }

    static func updateCredential(_ update: (inout Credentials) -> Void) {
        var credentials = getCredentials()
        update(&credentials)
        saveCredentials(credentials)
    }
}
