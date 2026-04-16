//
//  BaseClient.swift
//  CoList
//
//  Created by 江逸帆 on 2/11/26.
//
import Foundation
import Combine

struct EmptyResponse: Codable {}

final class BaseClient {
    func perform<T: Codable>(
        _ method: String = "GET",
        _ u: URL,
        h: [String: String]? = nil,
        b: Encodable? = nil
    ) -> AnyPublisher<T, NetworkError> {
        requestPublisher(u: u, method: method, body: b, headers: h)
            .tryMap { data, response in
                try self.decodeResponse(data: data, response: response) as T
            }
            .mapError { NetworkError.map($0) }
            .eraseToAnyPublisher()
    }

    func performVoid(
        _ method: String = "GET",
        _ u: URL,
        h: [String: String]? = nil,
        b: Encodable? = nil
    ) -> AnyPublisher<Void, NetworkError> {
        requestPublisher(u: u, method: method, body: b, headers: h)
            .tryMap { data, response in
                try self.decodeVoidResponse(data: data, response: response)
            }
            .mapError { NetworkError.map($0) }
            .eraseToAnyPublisher()
    }

    private func requestPublisher(
        u: URL,
        method: String,
        body: Encodable?,
        headers: [String: String]?
    ) -> AnyPublisher<(Data, HTTPURLResponse), NetworkError> {
        Deferred {
            Future { promise in
                Task {
                    do {
                        let result = try await NetworkUtil.request(
                            u: u,
                            method: method,
                            body: body,
                            headers: headers
                        )
                        promise(.success(result))
                    } catch {
                        promise(.failure(NetworkError.map(error)))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }

    private func decodeResponse<T: Codable>(
        data: Data,
        response: HTTPURLResponse
    ) throws -> T {
        let code = response.statusCode
        let nullData = Data("null".utf8)

        if (200...299).contains(code) {
            if T.self == EmptyResponse.self && (data.isEmpty || data == nullData) {
                guard let empty = EmptyResponse() as? T else {
                    throw NetworkError.decoding(DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Failed to decode empty response.")))
                }
                return empty
            }
            do {
                return try NetworkUtil.decode(data)
            } catch {
                logDecodeError(
                    url: response.url,
                    code: code,
                    headers: response.allHeaderFields,
                    rawData: data,
                    error: error
                )
                throw NetworkError.decoding(error)
            }
        }

        if let apiErr: APIErrorBody = try? NetworkUtil.decode(data) {
            logAPIError(
                url: response.url,
                code: code,
                headers: response.allHeaderFields,
                body: apiErr,
                rawData: data
            )
            let err = apiErr.error.uppercased()
            if err == "ATK_EXPIRED" || err == "ACCESS_TOKEN_EXPIRED" {
                throw NetworkError.atkExpired
            }
            if code == 401 { throw NetworkError.unauthorized }

            throw NetworkError.apiError(
                u: response.url!,
                code: code,
                h: response.allHeaderFields,
                body: apiErr,
                d: data
            )
        }

        logHTTPError(
            url: response.url,
            code: code,
            headers: response.allHeaderFields,
            rawData: data
        )
        if code == 401 { throw NetworkError.unauthorized }
        throw NetworkError.httpError(
            u: response.url!,
            code: code,
            h: response.allHeaderFields,
            d: data
        )
    }

    private func decodeVoidResponse(
        data: Data,
        response: HTTPURLResponse
    ) throws {
        let code = response.statusCode

        if (200...299).contains(code) {
            return
        }

        if let apiErr: APIErrorBody = try? NetworkUtil.decode(data) {
            logAPIError(
                url: response.url,
                code: code,
                headers: response.allHeaderFields,
                body: apiErr,
                rawData: data
            )
            let err = apiErr.error.uppercased()
            if err == "ATK_EXPIRED" || err == "ACCESS_TOKEN_EXPIRED" {
                throw NetworkError.atkExpired
            }
            if code == 401 { throw NetworkError.unauthorized }

            throw NetworkError.apiError(
                u: response.url!,
                code: code,
                h: response.allHeaderFields,
                body: apiErr,
                d: data
            )
        }

        logHTTPError(
            url: response.url,
            code: code,
            headers: response.allHeaderFields,
            rawData: data
        )
        if code == 401 { throw NetworkError.unauthorized }
        throw NetworkError.httpError(
            u: response.url!,
            code: code,
            h: response.allHeaderFields,
            d: data
        )
    }

    private func logAPIError(
        url: URL?,
        code: Int,
        headers: [AnyHashable: Any],
        body: APIErrorBody,
        rawData: Data
    ) {
        #if DEBUG
        let rawBody = String(data: rawData, encoding: .utf8) ?? "<non-utf8 body>"
        print("""
        [API_ERROR]
          url: \(url?.absoluteString ?? "<nil>")
          status: \(code)
          error: \(body.error)
          message: \(body.message)
          headers: \(prettyHeaders(headers))
          raw: \(rawBody)
        """)
        #endif
    }

    private func logHTTPError(
        url: URL?,
        code: Int,
        headers: [AnyHashable: Any],
        rawData: Data
    ) {
        #if DEBUG
        let rawBody = String(data: rawData, encoding: .utf8) ?? "<non-utf8 body>"
        print("""
        [HTTP_ERROR]
          url: \(url?.absoluteString ?? "<nil>")
          status: \(code)
          headers: \(prettyHeaders(headers))
          raw: \(rawBody)
        """)
        #endif
    }

    private func logDecodeError(
        url: URL?,
        code: Int,
        headers: [AnyHashable: Any],
        rawData: Data,
        error: Error
    ) {
        #if DEBUG
        let rawBody = String(data: rawData, encoding: .utf8) ?? "<non-utf8 body>"
        print("""
        [DECODE_ERROR]
          url: \(url?.absoluteString ?? "<nil>")
          status: \(code)
          error: \(error)
          headers: \(prettyHeaders(headers))
          raw: \(rawBody)
        """)
        #endif
    }

    private func prettyHeaders(_ headers: [AnyHashable: Any]) -> String {
        let parts = headers
            .map { (String(describing: $0.key), String(describing: $0.value)) }
            .sorted { $0.0 < $1.0 }
            .map { "\($0.0)=\($0.1)" }
        return parts.isEmpty ? "<empty>" : parts.joined(separator: ", ")
    }
}
