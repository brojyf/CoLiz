//
//  LoginVM.swift
//  CoList
//
//  Created by 江逸帆 on 2/14/26.
//

import Foundation
import Combine
import UIKit

enum AuthCodeScene: String {
    case signup
    case reset
}

@MainActor
final class LoginVM: ObservableObject {
    @Published private(set) var isLoading = false

    private let service: AuthService
    private let tokenProvider: any TokenProvider
    private let authState: AuthStateStore
    private let presenter: ErrorPresenter
    private var bag = Set<AnyCancellable>()
    private var codeId: String?
    private var ticketId: String?

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    init(
        s: AuthService,
        tp: any TokenProvider,
        auth: AuthStateStore,
        ep: ErrorPresenter
    ) {
        self.service = s
        self.tokenProvider = tp
        self.authState = auth
        self.presenter = ep
    }

    func prepareForLoginEntry() {
        cancelActiveRequests()
        dismissKeyboard()
        isLoading = false
        resetSignUpFlow()
    }

    func startSignUpFlow() {
        resetSignUpFlow()
    }

    func startResetPasswordFlow() {
        resetSignUpFlow()
    }

    func login(email: String, password: String) {
        guard !isLoading else { return }
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty, !password.isEmpty else {
            presenter.show("Please enter email and password.")
            return
        }
        if UITestConfig.mocksAuthSuccess {
            completeAuth(.mock())
            return
        }

        isLoading = true
        service.login(email: email, password: password)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoading = false
                guard case let .failure(error) = completion else { return }
                self.handle(error, unauthorizedMessage: "Invalid email or password.")
            } receiveValue: { [weak self] tokens in
                guard let self else { return }
                self.completeAuth(tokens)
            }
            .store(in: &bag)
    }

    func requestSignUpCode(
        email: String,
        onSuccess: @escaping @MainActor () -> Void
    ) {
        requestCode(email: email, scene: .signup, onSuccess: onSuccess)
    }

    func requestResetCode(
        email: String,
        onSuccess: @escaping @MainActor () -> Void
    ) {
        requestCode(email: email, scene: .reset, onSuccess: onSuccess)
    }

    private func requestCode(
        email: String,
        scene: AuthCodeScene,
        onSuccess: @escaping @MainActor () -> Void
    ) {
        guard !isLoading else { return }
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else {
            presenter.show("Please enter your email.")
            return
        }
        if UITestConfig.mocksAuthSuccess {
            codeId = UUID().uuidString.lowercased()
            ticketId = nil
            onSuccess()
            return
        }

        isLoading = true
        service.requestCode(email: email, scene: scene.rawValue)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoading = false
                guard case let .failure(error) = completion else { return }
                self.handle(error)
            } receiveValue: { [weak self] codeId in
                guard let self else { return }
                self.codeId = codeId
                self.ticketId = nil
                Task { @MainActor in onSuccess() }
            }
            .store(in: &bag)
    }

    func verifySignUpCode(
        email: String,
        otp: String,
        onSuccess: @escaping @MainActor () -> Void
    ) {
        verifyCode(email: email, otp: otp, scene: .signup, onSuccess: onSuccess)
    }

    func verifyResetCode(
        email: String,
        otp: String,
        onSuccess: @escaping @MainActor () -> Void
    ) {
        verifyCode(email: email, otp: otp, scene: .reset, onSuccess: onSuccess)
    }

    private func verifyCode(
        email: String,
        otp: String,
        scene: AuthCodeScene,
        onSuccess: @escaping @MainActor () -> Void
    ) {
        guard !isLoading else { return }
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let otp = otp.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else {
            presenter.show("Please enter your email.")
            return
        }
        guard let codeId else {
            presenter.show("Please request a new verification code.")
            return
        }
        guard otp.count == 6, otp.allSatisfy(\.isNumber) else {
            presenter.show("Please enter a valid 6-digit code.")
            return
        }
        if UITestConfig.mocksAuthSuccess {
            ticketId = UUID().uuidString.lowercased()
            onSuccess()
            return
        }

        isLoading = true
        service.verifyCode(email: email, otp: otp, codeId: codeId, scene: scene.rawValue)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoading = false
                guard case let .failure(error) = completion else { return }
                self.handle(error)
            } receiveValue: { [weak self] ticketId in
                guard let self else { return }
                self.ticketId = ticketId
                Task { @MainActor in onSuccess() }
            }
            .store(in: &bag)
    }

    func createAccount(password: String) {
        submitPassword(password: password, scene: .signup)
    }

    func resetPassword(password: String) {
        submitPassword(password: password, scene: .reset)
    }

    private func submitPassword(password: String, scene: AuthCodeScene) {
        guard !isLoading else { return }
        let password = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let ticketId else {
            presenter.show("Please verify your code first.")
            return
        }
        guard isPasswordValid(password) else {
            presenter.show("Password must be 8-20 chars with upper, lower, number and symbol.")
            return
        }
        if UITestConfig.mocksAuthSuccess {
            completeAuth(.mock())
            resetSignUpFlow()
            return
        }

        isLoading = true
        let request: AnyPublisher<AuthTokens, NetworkError>
        switch scene {
        case .signup:
            request = service.createAccount(ticketId: ticketId, password: password)
        case .reset:
            request = service.resetPassword(ticketId: ticketId, password: password)
        }

        request
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoading = false
                guard case let .failure(error) = completion else { return }
                self.handle(error)
            } receiveValue: { [weak self] tokens in
                guard let self else { return }
                self.completeAuth(tokens)
                self.resetSignUpFlow()
            }
            .store(in: &bag)
    }

    func showMessage(_ message: String) {
        presenter.show(message)
    }

    private func completeAuth(_ tokens: AuthTokens) {
        Task {
            await tokenProvider.setTokens(tokens)
            await MainActor.run { dismissKeyboard() }
            await MainActor.run {
                authState.markSignedIn()
            }
        }
    }

    private func handle(_ error: NetworkError, unauthorizedMessage: String? = nil) {
        if case .unauthorized = error, let unauthorizedMessage {
            presenter.show(unauthorizedMessage)
            return
        }
        if let msg = NetworkError.userMessage(from: error) {
            presenter.show(msg)
        }
    }

    private func resetSignUpFlow() {
        codeId = nil
        ticketId = nil
    }

    private func cancelActiveRequests() {
        bag.forEach { $0.cancel() }
        bag.removeAll()
    }

    private func isPasswordValid(_ password: String) -> Bool {
        guard password.count >= 8, password.count <= 20 else { return false }

        let hasUpper = password.rangeOfCharacter(from: .uppercaseLetters) != nil
        let hasLower = password.rangeOfCharacter(from: .lowercaseLetters) != nil
        let hasDigit = password.rangeOfCharacter(from: .decimalDigits) != nil
        let symbols = CharacterSet.punctuationCharacters.union(.symbols)
        let hasSymbol = password.rangeOfCharacter(from: symbols) != nil

        return hasUpper && hasLower && hasDigit && hasSymbol
    }
}
