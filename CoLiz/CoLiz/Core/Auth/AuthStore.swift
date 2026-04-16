//
//  AuthStore.swift
//  CoList
//
//  Created by 江逸帆 on 2/10/26.
//

import Foundation

protocol AuthStore: Sendable {
    nonisolated func getDeviceID() -> String
    nonisolated func loadTokens() -> AuthTokens?
    nonisolated func saveTokens(_ tokens: AuthTokens)
    nonisolated func clearTokens()
}

struct DefaultAuthStore: AuthStore {
    private let key = "com.colist.auth.tokens"
    nonisolated init() {}

    nonisolated func getDeviceID() -> String {
        return KeychainUtil.getDeviceID()
    }
    
    nonisolated func loadTokens() -> AuthTokens? {
        return KeychainUtil.get(AuthTokens.self, forKey: key)
    }

    nonisolated func saveTokens(_ tokens: AuthTokens) {
        KeychainUtil.set(tokens, forKey: key)
    }

    nonisolated func clearTokens() {
        KeychainUtil.delete(key: key)
    }
}
