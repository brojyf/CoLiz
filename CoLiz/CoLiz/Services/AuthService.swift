//
//  AuthService.swift
//  CoList
//
//  Created by 江逸帆 on 2/14/26.
//

import Foundation
import Combine

private struct LoginReq: Encodable {
    let email: String
    let password: String
    let deviceId: String

    enum CodingKeys: String, CodingKey {
        case email
        case password
        case deviceId = "device_id"
    }
}

private struct RequestCodeReq: Encodable {
    let email: String
    let scene: String
}

private struct RequestCodeResp: Codable {
    let codeId: String
}

private struct VerifyCodeReq: Encodable {
    let email: String
    let scene: String
    let otp: String
    let codeId: String
    let deviceId: String

    enum CodingKeys: String, CodingKey {
        case email
        case scene
        case otp
        case codeId = "code_id"
        case deviceId = "device_id"
    }
}

private struct VerifyCodeResp: Codable {
    let ticketId: String
}

private struct CreateAccountReq: Encodable {
    let ticketId: String
    let password: String
    let deviceId: String

    enum CodingKeys: String, CodingKey {
        case ticketId = "ticket_id"
        case password
        case deviceId = "device_id"
    }
}

final class AuthService {
    private let client: BaseClient
    private let store: any AuthStore

    init(c: BaseClient, store: any AuthStore) {
        self.client = c
        self.store = store
    }

    func login(email: String, password: String) -> AnyPublisher<AuthTokens, NetworkError> {
        let req = LoginReq(
            email: email,
            password: password,
            deviceId: store.getDeviceID()
        )
        return client.perform("POST", API.Auth.login, b: req)
    }

    func requestCode(email: String, scene: String = "signup") -> AnyPublisher<String, NetworkError> {
        let req = RequestCodeReq(email: email, scene: scene)
        return client
            .perform("POST", API.Auth.requestCode, b: req)
            .map { (resp: RequestCodeResp) in resp.codeId }
            .eraseToAnyPublisher()
    }

    func verifyCode(
        email: String,
        otp: String,
        codeId: String,
        scene: String = "signup"
    ) -> AnyPublisher<String, NetworkError> {
        let req = VerifyCodeReq(
            email: email,
            scene: scene,
            otp: otp,
            codeId: codeId,
            deviceId: store.getDeviceID()
        )
        return client
            .perform("POST", API.Auth.verifyCode, b: req)
            .map { (resp: VerifyCodeResp) in resp.ticketId }
            .eraseToAnyPublisher()
    }

    func createAccount(ticketId: String, password: String) -> AnyPublisher<AuthTokens, NetworkError> {
        let req = CreateAccountReq(
            ticketId: ticketId,
            password: password,
            deviceId: store.getDeviceID()
        )
        return client.perform("POST", API.Auth.createAccount, b: req)
    }

    func resetPassword(ticketId: String, password: String) -> AnyPublisher<AuthTokens, NetworkError> {
        let req = CreateAccountReq(
            ticketId: ticketId,
            password: password,
            deviceId: store.getDeviceID()
        )
        return client.perform("POST", API.Auth.resetPassword, b: req)
    }
}
