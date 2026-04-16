//
//  AuthEvents.swift
//  CoList
//

import Foundation
import Combine

enum AuthEvent {
    case sessionExpired
}

final class AuthEventBus {
    static let shared = AuthEventBus()

    let events = PassthroughSubject<AuthEvent, Never>()

    private init() {}
}
