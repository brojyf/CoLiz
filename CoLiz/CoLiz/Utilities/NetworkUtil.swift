//
//  NetworkUtil.swift
//  CoList
//
//  Created by 江逸帆 on 2/10/26.
//

import Foundation

enum NetworkUtil {
    /// Core static methods for network requests
    static var session: URLSession = .shared

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()

            if let ts = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: ts)
            }

            let str = try container.decode(String.self)
            let withFractional = ISO8601DateFormatter()
            withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = withFractional.date(from: str) {
                return date
            }

            let basic = ISO8601DateFormatter()
            basic.formatOptions = [.withInternetDateTime]
            if let date = basic.date(from: str) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date format: \(str)"
            )
        }
        return d
    }()
    
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()
    
    static func request(
        u: URL,
        method: String,
        body: Encodable? = nil,
        headers: [String: String]? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: u)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        headers?.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        
        if let body = body {
            request.httpBody = try encoder.encode(AnyEncodable(body))
        }
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        return (data, httpResponse)
    }
    
    // Simple generic decoding method
    static func decode<T: Codable>(_ data: Data) throws -> T {
        try decoder.decode(T.self, from: data)
    }
}

private struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void

    init(_ value: Encodable) {
        self.encodeFunc = value.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeFunc(encoder)
    }
}
