//
//  TokenProvider.swift
//  CoList
//
//  Created by 江逸帆 on 2/10/26.
//

import Foundation

protocol TokenProvider: Sendable {
    func getTokenType() async throws -> String?
    func getValidATK() async throws -> String?
    func forceRefreshATK() async throws -> String?
    func setTokens(_ tokens: AuthTokens) async
    func signOut() async
}

actor DefaultTokenProvider: TokenProvider {
    private let store: any AuthStore
    private let refresher: any AuthRefresher
    private let refreshSkew: TimeInterval
    private let now: @Sendable () -> Date
    
    private var tokens: AuthTokens?
    private var issuedAt: Date?
    private var refreshTask: Task<AuthTokens, Error>?
    
    init(
        store: any AuthStore,
        refresher: any AuthRefresher,
        refreshSkew: TimeInterval = 60,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.store = store
        self.refresher = refresher
        self.refreshSkew = refreshSkew
        self.now = now

        self.tokens = store.loadTokens()
        self.issuedAt = self.tokens == nil ? nil : now()
    }
    
    func getTokenType() async throws -> String? {
        guard let tokens else { return nil }
        return tokens.tokenType
    }
    
    func getValidATK() async throws -> String? {
        guard tokens != nil else { return nil }
        let refreshed = try await refreshIfNeeded()
        return refreshed.accessToken
    }
    
    func forceRefreshATK() async throws -> String? {
        guard tokens != nil else { return nil }
        let refreshed = try await refreshIfNeeded(force: true)
        return refreshed.accessToken
    }

    func setTokens(_ tokens: AuthTokens) async {
        applyRefreshed(tokens)
    }

    func signOut() async {
        refreshTask?.cancel()
        tokens = nil
        issuedAt = nil
        refreshTask = nil
        store.clearTokens()
    }
    
    private func isExpired(_ tokens: AuthTokens) -> Bool {
        guard let issuedAt else { return true }
        let expiresAt = issuedAt.addingTimeInterval(TimeInterval(tokens.expiresIn))
        return now().addingTimeInterval(refreshSkew) >= expiresAt
    }
    
    private func applyRefreshed(_ t: AuthTokens) {
        tokens = t
        issuedAt = now()
        store.saveTokens(t)
    }
    
    // Refreshes tokens directly without expiry checks.
    private func awaitRefresh(_ task: Task<AuthTokens, Error>) async throws -> AuthTokens {
        do { return try await task.value }
        catch { throw NetworkError.unauthorized }
    }

    private func refresh() async throws -> AuthTokens {
        if let refreshTask { return try await awaitRefresh(refreshTask) }
        guard let cur = tokens else { throw NetworkError.unauthorized}

        let task = Task<AuthTokens, Error> { [refresher, store] in
            try await refresher.refresh(cur.refreshToken, store.getDeviceID())
        }
        refreshTask = task
        defer { refreshTask = nil }

        let refreshed = try await awaitRefresh(task)
        applyRefreshed(refreshed)
        return refreshed
    }

    private func refreshIfNeeded(force: Bool = false) async throws -> AuthTokens {
        guard let cur = tokens else {
            throw NetworkError.unauthorized
        }
        
        if !force, !isExpired(cur) {
            return cur
        }

        return try await refresh()
    }
}
