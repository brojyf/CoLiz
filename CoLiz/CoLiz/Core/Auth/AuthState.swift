//
//  AuthState.swift
//  CoList
//
//  Created by 江逸帆 on 2/11/26.
//

import Foundation
import Combine

enum AuthState {
    case idle
    case signedIn
    case signedOut
}

@MainActor
final class AuthStateStore: ObservableObject {
    @Published private(set) var state: AuthState = .idle

    private let tokenProvider: any TokenProvider
    private var didBootstrap = false
    private var cancellables = Set<AnyCancellable>()

    init(tp: any TokenProvider, initialState: AuthState? = nil) {
        self.tokenProvider = tp
        observeAuthEvents()
        if let initialState {
            self.state = initialState
            self.didBootstrap = true
        } else {
            Task { await bootstrap() }
        }
    }

    func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true

        do {
            let atk = try await tokenProvider.forceRefreshATK()
            state = (atk == nil) ? .signedOut : .signedIn
        } catch {
            await tokenProvider.signOut()
            state = .signedOut
        }
    }

    func markSignedIn() {
        state = .signedIn
    }

    func signOut() {
        Task {
            await tokenProvider.signOut()
            await MainActor.run { self.state = .signedOut }
        }
    }

    private func observeAuthEvents() {
        AuthEventBus.shared.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self else { return }
                switch event {
                case .sessionExpired:
                    if self.state != .signedOut {
                        self.signOut()
                    }
                }
            }
            .store(in: &cancellables)
    }
}
