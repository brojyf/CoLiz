//
//  KeychainUtil.swift
//  CoList
//
//  Created by 江逸帆 on 2/10/26.
//

import Foundation
import Security

enum KeychainUtil {
    nonisolated private static let service = "com.colist.keychain.default"
    nonisolated private static let deviceIDKey = "com.colist.keychain.device_id"
    nonisolated private static let accessibility = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

    nonisolated private static func itemQuery(key: String, service: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }
    
    // MARK: - Private methods
    nonisolated private static func save<T: Codable>(_ value: T, key: String, service: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }

        var addQuery = itemQuery(key: key, service: service)
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = accessibility

        SecItemDelete(itemQuery(key: key, service: service) as CFDictionary)
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    nonisolated private static func load<T: Codable>(key: String, as type: T.Type, service: String) -> T? {
        var query = itemQuery(key: key, service: service)
        query[kSecReturnData as String] = true
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard
            status == errSecSuccess,
            let item = result as? [String: Any],
            let data = item[kSecValueData as String] as? Data,
            let value = try? JSONDecoder().decode(T.self, from: data)
        else {
            return nil
        }

        // Rewrite legacy entries so existing installs are upgraded to ThisDeviceOnly.
        if let storedAccessibility = item[kSecAttrAccessible as String] {
            let storedAccessibilityValue = String(describing: storedAccessibility)
            let expectedAccessibilityValue = String(describing: accessibility)
            if storedAccessibilityValue != expectedAccessibilityValue {
                save(value, key: key, service: service)
            }
        }

        return value
    }

    // MARK: - Public methods
    nonisolated static func getDeviceID() -> String {
        if let id = load(key: deviceIDKey, as: String.self, service: service) {
            return id
        }
        let newID = UUID().uuidString.lowercased()
        save(newID, key: deviceIDKey, service: service)
        return newID
    }

    /// For external business use
    nonisolated static func set<T: Codable>(_ value: T, forKey key: String) {
        let service = "com.colist.keychain.default"
        save(value, key: key, service: service)
    }

    nonisolated static func get<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        let service = "com.colist.keychain.default"
        return load(key: key, as: type, service: service)
    }
    
    nonisolated static func delete(key: String) {
        let service = "com.colist.keychain.default"
        SecItemDelete(itemQuery(key: key, service: service) as CFDictionary)
    }
}
