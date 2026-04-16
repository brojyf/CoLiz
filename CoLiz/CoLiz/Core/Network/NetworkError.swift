//
//  NetworkError.swift
//  CoList
//
//  Created by 江逸帆 on 2/11/26.
//
import Foundation

struct APIErrorBody: Codable, LocalizedError {
    let error: String
    let message: String
    var errorDescription: String? { message }
}

enum NetworkError: Error {
    case missingLocalData(String)
    case encoding(Error)
    case decoding(Error)
    case transport(URLError)
    case atkExpired
    case unauthorized
    case apiError(u: URL, code: Int, h: [AnyHashable:Any], body: APIErrorBody, d: Data)
    case httpError(u: URL, code: Int, h: [AnyHashable:Any], d: Data)
    case unknown
}

extension NetworkError {
    static func map(_ error: Error) -> NetworkError {
        if let e = error as? NetworkError { return e }
        if let e = error as? URLError { return .transport(e) }
        if error is EncodingError { return .encoding(error) }
        if error is DecodingError { return .decoding(error) }
        return .unknown
    }

    var shouldAttemptTokenRefresh: Bool {
        if case .atkExpired = self {
            return true
        }
        return false
    }

    var shouldForceSignOut: Bool {
        switch self {
        case .atkExpired:
            return false
        case .unauthorized:
            return true
        case let .apiError(_, code, _, body, _):
            guard code == 401 else { return false }
            let err = body.error.uppercased()
            return err != "ATK_EXPIRED" && err != "ACCESS_TOKEN_EXPIRED"
        case let .httpError(_, code, _, _):
            return code == 401
        default:
            return false
        }
    }

    static func userMessage(from error: NetworkError) -> String? {
        switch error {
        case .atkExpired, .unauthorized:
            return nil
        case let .apiError(_, _, _, body, _):
            return body.message
        default:
            return "网络异常，请稍后重试"
        }
    }
}
