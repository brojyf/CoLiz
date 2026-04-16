//
//  AuthTokens.swift
//  CoList
//
//  Created by 江逸帆 on 2/10/26.
//

import Foundation

struct AuthTokens: Sendable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int64
    let refreshToken: String
}

// Make Codable conformance explicitly nonisolated so it can be used off the main actor.
nonisolated extension AuthTokens: Codable {}

extension AuthTokens {
    nonisolated static func mock() -> Self {
        .init(
            accessToken: "mock-access-token",
            tokenType: "Bearer",
            expiresIn: 3600,
            refreshToken: "mock-refresh-token"
        )
    }
}
