//
//  AuthedClient.swift
//  CoList
//
//  Created by 江逸帆 on 2/10/26.
//

import Foundation
import Combine

// MARK: - AuthedClient (auth + refresh)
final class AuthedClient {
    private let base: BaseClient
    private let tp: any TokenProvider

    init(base: BaseClient = BaseClient(), tp: any TokenProvider) {
        self.base = base
        self.tp = tp
    }
    
    func get<T: Codable>(
        auth: Bool = true,
        u: URL,
        h: [String:String] = [:]
    ) -> AnyPublisher<T, NetworkError> {
        request(method: "GET", auth: auth, u: u, h: h, b: nil)
    }

    func post<T: Codable, B: Encodable>(
        auth: Bool = true,
        u: URL,
        h: [String:String] = [:],
        b: B
    ) -> AnyPublisher<T, NetworkError> {
        request(method: "POST", auth: auth, u: u, h: h, b: b)
    }

    func postVoid<B: Encodable>(
        auth: Bool = true,
        u: URL,
        h: [String:String] = [:],
        b: B
    ) -> AnyPublisher<Void, NetworkError> {
        requestVoid(method: "POST", auth: auth, u: u, h: h, b: b)
    }

    func patch<T: Codable, B: Encodable>(
        auth: Bool = true,
        u: URL,
        h: [String:String] = [:],
        b: B
    ) -> AnyPublisher<T, NetworkError> {
        request(method: "PATCH", auth: auth, u: u, h: h, b: b)
    }

    func delete<T: Codable, B: Encodable>(
        auth: Bool = true,
        u: URL,
        h: [String:String] = [:],
        b: B
    ) -> AnyPublisher<T, NetworkError> {
        request(method: "DELETE", auth: auth, u: u, h: h, b: b)
    }

    func delete<T: Codable>(
        auth: Bool = true,
        u: URL,
        h: [String:String] = [:]
    ) -> AnyPublisher<T, NetworkError> {
        request(method: "DELETE", auth: auth, u: u, h: h, b: nil)
    }

    private func refresh() -> AnyPublisher<Void, NetworkError> {
        Future<Void, NetworkError> { [tp] promise in
            Task {
                do {
                    let refreshed = try await tp.forceRefreshATK()
                    guard refreshed != nil else {
                        promise(.failure(.unauthorized))
                        return
                    }
                    promise(.success(()))
                } catch {
                    let mapped = NetworkError.map(error)
                    promise(.failure(mapped))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    private func request<T: Codable>(
        method: String,
        auth: Bool,
        u: URL,
        h: [String: String],
        b: Encodable?
    ) -> AnyPublisher<T, NetworkError> {
        let request = authorizedHeaders(auth: auth, h)
            .flatMap { [base] headers in
                base.perform(method, u, h: headers, b: b)
            }
            .catch { [weak self] error -> AnyPublisher<T, NetworkError> in
                guard auth, error.shouldAttemptTokenRefresh, let self else {
                    return Fail(error: error).eraseToAnyPublisher()
                }
                return self.refresh()
                    .flatMap { self.authorizedHeaders(auth: auth, h) }
                    .flatMap { [base] headers in
                        base.perform(method, u, h: headers, b: b)
                    }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()

        guard auth else { return request }

        return request
            .handleEvents(receiveCompletion: { completion in
                guard case let .failure(error) = completion else { return }
                guard error.shouldForceSignOut else { return }
                AuthEventBus.shared.events.send(.sessionExpired)
            })
            .eraseToAnyPublisher()
    }

    private func requestVoid(
        method: String,
        auth: Bool,
        u: URL,
        h: [String: String],
        b: Encodable?
    ) -> AnyPublisher<Void, NetworkError> {
        let request = authorizedHeaders(auth: auth, h)
            .flatMap { [base] headers in
                base.performVoid(method, u, h: headers, b: b)
            }
            .catch { [weak self] error -> AnyPublisher<Void, NetworkError> in
                guard auth, error.shouldAttemptTokenRefresh, let self else {
                    return Fail(error: error).eraseToAnyPublisher()
                }
                return self.refresh()
                    .flatMap { self.authorizedHeaders(auth: auth, h) }
                    .flatMap { [base] headers in
                        base.performVoid(method, u, h: headers, b: b)
                    }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()

        guard auth else { return request }

        return request
            .handleEvents(receiveCompletion: { completion in
                guard case let .failure(error) = completion else { return }
                guard error.shouldForceSignOut else { return }
                AuthEventBus.shared.events.send(.sessionExpired)
            })
            .eraseToAnyPublisher()
    }

    private func authorizedHeaders(
        auth: Bool,
        _ h: [String: String]
    ) -> AnyPublisher<[String: String], NetworkError> {
        guard auth else {
            return Just(h)
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
        }

        return Future<[String: String], NetworkError> { [tp] promise in
            Task {
                do {
                    guard let atk = try await tp.getValidATK() else {
                        promise(.failure(.unauthorized))
                        return
                    }
                    let tt = try await tp.getTokenType() ?? "Bearer"
                    var headers = h
                    headers["Authorization"] = "\(tt) \(atk)"
                    promise(.success(headers))
                } catch {
                    promise(.failure(NetworkError.map(error)))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}
