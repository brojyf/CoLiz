//
//  TodoService.swift
//  CoList
//
//  Created by 江逸帆 on 2/14/26.
//

import Foundation
import Combine

private struct CreateTodoReq: Encodable {
    let message: String
}

private struct MarkTodoReq: Encodable {
    let done: Bool
}

private struct UpdateTodoReq: Encodable {
    let message: String
}

private struct SendFriendRequestReq: Encodable {
    let to: String
    let msg: String
}

private struct CreateGroupReq: Encodable {
    let groupName: String
}

private struct UpdateGroupReq: Encodable {
    let groupName: String
}

private struct InviteFriendToGroupReq: Encodable {
    let userID: String
}

private struct EmptyRequest: Encodable {}

struct FriendUser: Identifiable, Codable, Equatable, Hashable {
    let username: String
    let id: String
    let email: String
    let avatarVersion: UInt32
    let friendSince: Date?
    let mutualGroups: [AppGroup]?

    var resolvedAvatarURL: URL {
        return API.Users.avatar(userID: id, version: avatarVersion)
    }
}

extension FriendUser {
    static func mockList() -> [FriendUser] {
        [
            FriendUser(
                username: "Alex Chen",
                id: "friend-1",
                email: "alex@example.com",
                avatarVersion: 0,
                friendSince: Calendar.current.date(byAdding: .day, value: -42, to: Date()),
                mutualGroups: [AppGroup.mockList()[0]]
            ),
            FriendUser(
                username: "Jordan Park",
                id: "friend-2",
                email: "jordan@example.com",
                avatarVersion: 0,
                friendSince: Calendar.current.date(byAdding: .day, value: -128, to: Date()),
                mutualGroups: AppGroup.mockList()
            ),
        ]
    }
}

final class TodoService {
    private let client: AuthedClient
    private let tokenProvider: any TokenProvider
    
    init(c: AuthedClient, tp: any TokenProvider) {
        client = c
        tokenProvider = tp
    }
    
    func getTodos() -> AnyPublisher<[Todo], NetworkError> {
        return client.get(u: API.Todos.default)
    }

    func getGroupTodos(groupID: String) -> AnyPublisher<[Todo], NetworkError> {
        client.get(u: API.Todos.group(groupId: groupID))
    }

    func getGroups() -> AnyPublisher<[AppGroup], NetworkError> {
        client.get(u: API.Groups.default)
    }

    func getExpenses() -> AnyPublisher<[GroupExpense], NetworkError> {
        client.get(u: API.Expenses.default)
    }

    func getExpenseHistory(groupID: String) -> AnyPublisher<[ExpenseHistoryItem], NetworkError> {
        client.get(u: API.Expenses.detail(groupID: groupID))
    }

    func getTransactionPlan(groupID: String) -> AnyPublisher<GroupTransactionPlan, NetworkError> {
        client.get(u: API.Expenses.transactionPlan(groupID: groupID))
    }

    func applyTransactionPlan(groupID: String) -> AnyPublisher<GroupTransactionPlan, NetworkError> {
        client.post(
            u: API.Expenses.applyTransactionPlan(groupID: groupID),
            b: EmptyRequest()
        )
    }

    func getExpenseDetail(expenseID: String) -> AnyPublisher<ExpenseDetail, NetworkError> {
        client.get(u: API.Expenses.item(expenseID: expenseID))
    }

    func createExpense(
        groupID: String,
        request: CreateExpenseRequest
    ) -> AnyPublisher<Void, NetworkError> {
        client.postVoid(
            u: API.Expenses.create(groupID: groupID),
            b: request
        )
    }

    func updateExpense(
        expenseID: String,
        request: CreateExpenseRequest
    ) -> AnyPublisher<ExpenseDetail, NetworkError> {
        client.patch(
            u: API.Expenses.update(expenseID: expenseID),
            b: request
        )
    }

    func deleteExpense(expenseID: String) -> AnyPublisher<Void, NetworkError> {
        let req: AnyPublisher<EmptyResponse, NetworkError> = client.delete(
            u: API.Expenses.delete(expenseID: expenseID)
        )
        return req
            .map { _ in () }
            .eraseToAnyPublisher()
    }

    func getGroupDetail(groupID: String) -> AnyPublisher<GroupDetail, NetworkError> {
        client.get(u: API.Groups.detail(groupID: groupID))
    }

    func createGroup(groupName: String) -> AnyPublisher<AppGroup, NetworkError> {
        client.post(
            u: API.Groups.default,
            b: CreateGroupReq(groupName: groupName)
        )
    }

    func updateGroupName(groupID: String, groupName: String) -> AnyPublisher<AppGroup, NetworkError> {
        client.patch(
            u: API.Groups.update(groupID: groupID),
            b: UpdateGroupReq(groupName: groupName)
        )
    }

    func deleteGroup(groupID: String) -> AnyPublisher<Void, NetworkError> {
        let req: AnyPublisher<EmptyResponse, NetworkError> = client.delete(
            u: API.Groups.delete(groupID: groupID)
        )
        return req
            .map { _ in () }
            .eraseToAnyPublisher()
    }

    func inviteFriendToGroup(groupID: String, userID: String) -> AnyPublisher<Void, NetworkError> {
        let result: AnyPublisher<EmptyResponse, NetworkError> = client.post(
            u: API.Groups.invite(groupID: groupID),
            b: InviteFriendToGroupReq(userID: userID)
        )
        return result
            .map { _ in () }
            .eraseToAnyPublisher()
    }

    func leaveGroup(groupID: String) -> AnyPublisher<Void, NetworkError> {
        let result: AnyPublisher<EmptyResponse, NetworkError> = client.post(
            u: API.Groups.leave(groupID: groupID),
            b: EmptyRequest()
        )
        return result
            .map { _ in () }
            .eraseToAnyPublisher()
    }

    func uploadGroupAvatar(
        groupID: String,
        data: Data,
        fileName: String = "group-avatar.jpg",
        mimeType: String = "image/jpeg"
    ) async throws -> AppGroup {
        guard let token = try await tokenProvider.getValidATK() else {
            throw NetworkError.unauthorized
        }
        let tokenType = try await tokenProvider.getTokenType() ?? "Bearer"

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: API.Groups.avatar(groupID: groupID))
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
        return try decodeGroupResponse(data: data, response: httpResponse)
    }

    func getFriends() -> AnyPublisher<[FriendUser], NetworkError> {
        client.get(u: API.Friends.default)
    }

    func getFriend(userID: String) -> AnyPublisher<FriendUser, NetworkError> {
        client.get(u: API.Friends.detail(userID: userID))
    }

    func createTodo(groupID: String, message: String) -> AnyPublisher<Todo, NetworkError> {
        client.post(
            u: API.Todos.create(groupId: groupID),
            b: CreateTodoReq(message: message)
        )
    }

    func markTodo(todoID: String, done: Bool) -> AnyPublisher<Todo, NetworkError> {
        client.patch(
            u: API.Todos.mark(todoId: todoID),
            b: MarkTodoReq(done: done)
        )
    }

    func updateTodo(todoID: String, message: String) -> AnyPublisher<Todo, NetworkError> {
        client.patch(
            u: API.Todos.update(todoId: todoID),
            b: UpdateTodoReq(message: message)
        )
    }

    func deleteTodo(todoID: String) -> AnyPublisher<Void, NetworkError> {
        let req: AnyPublisher<EmptyResponse, NetworkError> = client.delete(
            u: API.Todos.delete(todoId: todoID)
        )
        return req
            .map { _ in () }
            .eraseToAnyPublisher()
    }

    func searchFriendByEmail(email: String) -> AnyPublisher<FriendUser, NetworkError> {
        client.get(
            u: API.Users.searchByEmail(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        )
    }

    func sendFriendRequest(toUserID: String, message: String) -> AnyPublisher<Void, NetworkError> {
        let req = SendFriendRequestReq(
            to: toUserID,
            msg: message.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        let result: AnyPublisher<EmptyResponse, NetworkError> = client.post(
            u: API.FriendRequests.default,
            b: req
        )
        return result
            .map { _ in () }
            .eraseToAnyPublisher()
    }

    func getFriendRequests() -> AnyPublisher<[FriendRequest], NetworkError> {
        client.get(u: API.FriendRequests.default)
    }

    func acceptFriendRequest(requestID: String) -> AnyPublisher<Void, NetworkError> {
        let result: AnyPublisher<EmptyResponse, NetworkError> = client.post(
            u: API.FriendRequests.accept(requestID: requestID),
            b: EmptyResponse()
        )
        return result
            .map { _ in () }
            .eraseToAnyPublisher()
    }

    func declineFriendRequest(requestID: String) -> AnyPublisher<Void, NetworkError> {
        let result: AnyPublisher<EmptyResponse, NetworkError> = client.post(
            u: API.FriendRequests.reject(requestID: requestID),
            b: EmptyResponse()
        )
        return result
            .map { _ in () }
            .eraseToAnyPublisher()
    }

    func cancelFriendRequest(requestID: String) -> AnyPublisher<Void, NetworkError> {
        let result: AnyPublisher<EmptyResponse, NetworkError> = client.post(
            u: API.FriendRequests.cancel(requestID: requestID),
            b: EmptyResponse()
        )
        return result
            .map { _ in () }
            .eraseToAnyPublisher()
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

    private func decodeGroupResponse(
        data: Data,
        response: HTTPURLResponse
    ) throws -> AppGroup {
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
