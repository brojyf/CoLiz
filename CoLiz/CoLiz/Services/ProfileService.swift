import Foundation
import Combine

final class ProfileService {
    private struct UpdateUsernameRequest: Encodable {
        let username: String
    }

    private struct ChangePasswordRequest: Encodable {
        let old: String
        let new: String
    }

    private struct DeviceTokenRequest: Encodable {
        let token: String
    }

    private let client: AuthedClient
    private let tokenProvider: any TokenProvider

    init(c: AuthedClient, tp: any TokenProvider) {
        self.client = c
        self.tokenProvider = tp
    }

    func getProfile() -> AnyPublisher<UserProfile, NetworkError> {
        client.get(u: API.Users.me)
    }

    func updateUsername(_ username: String) -> AnyPublisher<UserProfile, NetworkError> {
        client.patch(u: API.Users.me, b: UpdateUsernameRequest(username: username))
    }

    func changePassword(old: String, new: String) -> AnyPublisher<Void, NetworkError> {
        client.post(u: API.Auth.changePassword, b: ChangePasswordRequest(old: old, new: new))
            .flatMap { [tokenProvider] (tokens: AuthTokens) in
                Future<Void, NetworkError> { promise in
                    Task {
                        await tokenProvider.setTokens(tokens)
                        promise(.success(()))
                    }
                }
            }
            .eraseToAnyPublisher()
    }

    func uploadDeviceToken(_ token: String) -> AnyPublisher<Void, NetworkError> {
        client.postVoid(u: API.Users.meDeviceToken, b: DeviceTokenRequest(token: token))
    }

    func uploadAvatar(
        data: Data,
        fileName: String = "avatar.jpg",
        mimeType: String = "image/jpeg"
    ) async throws -> UserProfile {
        guard let token = try await tokenProvider.getValidATK() else {
            throw NetworkError.unauthorized
        }
        let tokenType = try await tokenProvider.getTokenType() ?? "Bearer"

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: API.Users.meAvatar)
        request.httpMethod = "PUT"
        request.setValue("\(tokenType) \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = multipartBody(
            boundary: boundary,
            fieldName: "avatar",
            fileName: fileName,
            mimeType: mimeType,
            data: data
        )

        let (data, response) = try await NetworkUtil.session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return try decodeProfileResponse(data: data, response: httpResponse)
    }

    private func multipartBody(
        boundary: String,
        fieldName: String,
        fileName: String,
        mimeType: String,
        data: Data
    ) -> Data {
        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".utf8))
        body.append(Data("Content-Type: \(mimeType)\r\n\r\n".utf8))
        body.append(data)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        return body
    }

    private func decodeProfileResponse(
        data: Data,
        response: HTTPURLResponse
    ) throws -> UserProfile {
        if (200...299).contains(response.statusCode) {
            do { return try NetworkUtil.decode(data) }
            catch { throw NetworkError.decoding(error) }
        }

        if let apiErr: APIErrorBody = try? NetworkUtil.decode(data) {
            if response.statusCode == 401 {
                throw NetworkError.unauthorized
            }
            throw NetworkError.apiError(
                u: response.url!,
                code: response.statusCode,
                h: response.allHeaderFields,
                body: apiErr,
                d: data
            )
        }

        if response.statusCode == 401 {
            throw NetworkError.unauthorized
        }

        throw NetworkError.httpError(
            u: response.url!,
            code: response.statusCode,
            h: response.allHeaderFields,
            d: data
        )
    }
}
