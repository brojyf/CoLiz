//
//  API.swift
//  CoList
//
//  Created by 江逸帆 on 2/11/26.
//

import Foundation

struct API {
    
    let dev = false
    
    nonisolated static let baseURL = URL(string: "http://localhost:8080/api")! // TODO: Replace with your actual domain when deploying

    nonisolated static var originURL: URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            preconditionFailure("Failed to derive origin URL")
        }
        components.path = ""
        components.query = nil
        components.fragment = nil
        guard let url = components.url else {
            preconditionFailure("Failed to build origin URL")
        }
        return url
    }

    nonisolated static func endpoint(
        _ template: String,
        pathParams: [String: CustomStringConvertible] = [:],
        query: [String: CustomStringConvertible?] = [:]
    ) -> URL {
        let resolvedPath = resolvePath(template, with: pathParams)
        let trimmedPath = resolvedPath.hasPrefix("/")
            ? String(resolvedPath.dropFirst())
            : resolvedPath

        var components = URLComponents(
            url: baseURL.appendingPathComponent(trimmedPath),
            resolvingAgainstBaseURL: false
        )!
        let queryItems = query.compactMap { key, value -> URLQueryItem? in
            guard let value else { return nil }
            return URLQueryItem(name: key, value: String(describing: value))
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            preconditionFailure("Failed to build URL for template: \(template)")
        }
        return url
    }

    nonisolated private static func resolvePath(
        _ template: String,
        with pathParams: [String: CustomStringConvertible]
    ) -> String {
        pathParams.reduce(template) { current, pair in
            let encodedValue = String(describing: pair.value)
                .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
                ?? String(describing: pair.value)
            return current.replacingOccurrences(of: "{\(pair.key)}", with: encodedValue)
        }
    }

    enum Auth {
        nonisolated static var requestCode: URL { endpoint("/auth/request-otp") }
        nonisolated static var verifyCode: URL { endpoint("/auth/verify-otp") }
        nonisolated static var createAccount: URL { endpoint("/auth/register") }
        nonisolated static var resetPassword: URL { endpoint("/auth/reset-password") }
        nonisolated static var changePassword: URL { endpoint("/auth/change-password") }
        nonisolated static var login: URL { endpoint("/auth/login") }
        nonisolated static var refresh: URL { endpoint("/auth/refresh") }
    }

    enum Groups {
        nonisolated static var `default`: URL { endpoint("/groups") }
        nonisolated static func detail(groupID: String) -> URL {
            endpoint("/groups/{groupId}", pathParams: ["groupId": groupID])
        }
        nonisolated static func update(groupID: String) -> URL {
            endpoint("/groups/{groupId}", pathParams: ["groupId": groupID])
        }
        nonisolated static func delete(groupID: String) -> URL {
            endpoint("/groups/{groupId}", pathParams: ["groupId": groupID])
        }
        nonisolated static func invite(groupID: String) -> URL {
            endpoint("/groups/{groupId}/invite", pathParams: ["groupId": groupID])
        }
        nonisolated static func leave(groupID: String) -> URL {
            endpoint("/groups/{groupId}/leave", pathParams: ["groupId": groupID])
        }
        nonisolated static func avatar(groupID: String) -> URL {
            endpoint("/groups/{groupId}/avatar", pathParams: ["groupId": groupID])
        }
        nonisolated static func avatar(groupID: String, version: UInt32) -> URL {
            endpoint("/groups/{groupId}/avatar", pathParams: ["groupId": groupID], query: ["version": version])
        }
    }

    enum Expenses {
        nonisolated static var `default`: URL { endpoint("/expenses/overview") }
        nonisolated static func create(groupID: String) -> URL {
            endpoint("/groups/{groupId}/expenses", pathParams: ["groupId": groupID])
        }
        nonisolated static func detail(groupID: String) -> URL {
            endpoint("/groups/{groupId}/expenses", pathParams: ["groupId": groupID])
        }
        nonisolated static func transactionPlan(groupID: String) -> URL {
            endpoint("/groups/{groupId}/transactions/plan", pathParams: ["groupId": groupID])
        }
        nonisolated static func applyTransactionPlan(groupID: String) -> URL {
            endpoint("/groups/{groupId}/transactions/apply", pathParams: ["groupId": groupID])
        }
        nonisolated static func transaction(groupID: String) -> URL {
            endpoint("/groups/{groupId}/transaction", pathParams: ["groupId": groupID])
        }
        nonisolated static func item(expenseID: String) -> URL {
            endpoint("/expenses/{expenseId}", pathParams: ["expenseId": expenseID])
        }
        nonisolated static func update(expenseID: String) -> URL {
            endpoint("/expenses/{expenseId}", pathParams: ["expenseId": expenseID])
        }
        nonisolated static func delete(expenseID: String) -> URL {
            endpoint("/expenses/{expenseId}", pathParams: ["expenseId": expenseID])
        }
    }

    enum Friends {
        nonisolated static var `default`: URL { endpoint("/friends") }
        nonisolated static func detail(userID: String) -> URL {
            endpoint("/friends/{userId}", pathParams: ["userId": userID])
        }
    }

    enum Users {
        nonisolated static var me: URL { endpoint("/users/me") }
        nonisolated static var meAvatar: URL { endpoint("/users/me/avatar") }
        nonisolated static var meDeviceToken: URL { endpoint("/users/me/device-token") }
        nonisolated static func avatar(userID: String, version: UInt32) -> URL {
            endpoint("/users/{userId}/avatar", pathParams: ["userId": userID], query: ["version": version])
        }
        nonisolated static func searchByEmail(email: String) -> URL {
            endpoint("/users/search", query: ["email": email])
        }
    }

    enum FriendRequests {
        nonisolated static var `default`: URL {
            endpoint("/friend-requests")
        }
        nonisolated static func accept(requestID: String) -> URL {
            endpoint("/friend-requests/{requestId}/accept", pathParams: ["requestId": requestID])
        }
        nonisolated static func reject(requestID: String) -> URL {
            endpoint("/friend-requests/{requestId}/decline", pathParams: ["requestId": requestID])
        }
        nonisolated static func cancel(requestID: String) -> URL {
            endpoint("/friend-requests/{requestId}/cancel", pathParams: ["requestId": requestID])
        }
    }

    enum Todos {
        nonisolated static var `default`: URL { endpoint("/todos") }
        nonisolated static func group(groupId: String) -> URL {
            endpoint("/groups/{groupId}/todos", pathParams: ["groupId": groupId])
        }
        nonisolated static func create(groupId: String) -> URL {
            endpoint("/groups/{groupId}/todos", pathParams: ["groupId": groupId])
        }
        nonisolated static func delete(todoId: String) -> URL {
            endpoint("/todos/{todoId}", pathParams: ["todoId": todoId])
        }
        nonisolated static func update(todoId: String) -> URL {
            endpoint("/todos/{todoId}", pathParams: ["todoId": todoId])
        }
        nonisolated static func mark(todoId: String) -> URL {
            endpoint("/todos/{todoId}/mark", pathParams: ["todoId": todoId])
        }
    }
}
