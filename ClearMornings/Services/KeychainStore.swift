import Foundation
import Security

enum KeychainStore {
    static let service = "com.zzoutuo.ClearMornings"

    static func saveString(_ value: String, account: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func readString(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func deleteString(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    static func userId() -> String {
        if let existing = readString(account: "userId"), !existing.isEmpty {
            return existing
        }
        let id = UUID().uuidString
        saveString(id, account: "userId")
        return id
    }

    static var byoKey: String? {
        get { readString(account: "glm.byo.key") }
        set {
            if let v = newValue, !v.isEmpty {
                saveString(v, account: "glm.byo.key")
            } else {
                deleteString(account: "glm.byo.key")
            }
        }
    }
}
