//
//  AuthRefresher.swift
//  CoList
//
//  Created by 江逸帆 on 2/11/26.
//

import Foundation
import Combine

struct RefreshRequest: Sendable {
    let deviceId: String
    let refreshToken: String
}

// Make Codable conformance explicitly nonisolated so it can be used off the main actor.
nonisolated extension RefreshRequest: Codable {}

protocol AuthRefresher: Sendable {
    func refresh(_ rtk: String, _ did: String) async throws -> AuthTokens
}

final class DefaultAuthRefresher: AuthRefresher, @unchecked Sendable {
    private let client: BaseClient
    init(c: BaseClient) {
        self.client = c
    }
    
    func refresh(_ rtk: String, _ did: String) async throws -> AuthTokens {
        let body = RefreshRequest(deviceId: did, refreshToken: rtk)
        let req: AnyPublisher<AuthTokens, NetworkError> = client.perform(
            "POST",
            API.Auth.refresh,
            b: body
        )
        for try await tokens in req.values {
            return tokens
        }
        throw NetworkError.unknown
    }
}
