//
//  CredentialStore.swift
//  BorrowBuddy
//

import Foundation
import Security

struct StoredCredentials: Equatable {
    let email: String
    let password: String
}

enum CredentialStore {
    private static let service = "com.toolpool.BorrowBuddy.credentials"
    private static let account = "faceIDLogin"
    private static let faceIDEnabledKey = "faceIDEnabled"

    static var isFaceIDEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: faceIDEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: faceIDEnabledKey) }
    }

    static var hasStoredCredentials: Bool {
        load() != nil
    }

    static func save(_ credentials: StoredCredentials) {
        delete()
        let payload = "\(credentials.email)\n\(credentials.password)".data(using: .utf8) ?? Data()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: payload,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load() -> StoredCredentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        let parts = string.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        return StoredCredentials(email: String(parts[0]), password: String(parts[1]))
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
