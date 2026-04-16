//
//  FriendRequest.swift
//  CoList
//
//  Created by Codex on 3/4/26.
//

import Foundation

enum FriendRequestDirection: String, Codable {
    case sent
    case received
}

struct FriendRequest: Identifiable, Codable, Equatable {
    let id: String
    let from: String
    let fromUsername: String?
    let fromAvatarVersion: UInt32?
    let to: String
    let toUsername: String?
    let toAvatarVersion: UInt32?
    let msg: String?
    let status: String
    let createdAt: Date
    let direction: FriendRequestDirection

    var statusText: String {
        switch status.lowercased() {
        case "pending": return "Pending"
        case "accepted": return "Accepted"
        case "rejected": return "Rejected"
        default: return status
        }
    }

    var isPending: Bool {
        status.caseInsensitiveCompare("pending") == .orderedSame
    }

    var fromAvatarURL: URL {
        API.Users.avatar(userID: from, version: fromAvatarVersion ?? 0)
    }

    var toAvatarURL: URL {
        API.Users.avatar(userID: to, version: toAvatarVersion ?? 0)
    }
}

extension FriendRequest {
    static func mockList() -> [FriendRequest] {
        [
            FriendRequest(
                id: "friend-request-1",
                from: "friend-1",
                fromUsername: "Alex Chen",
                fromAvatarVersion: 0,
                to: "mock-user-id",
                toUsername: "Me",
                toAvatarVersion: 0,
                msg: "Join our grocery group",
                status: "pending",
                createdAt: Date().addingTimeInterval(-7200),
                direction: .received
            ),
            FriendRequest(
                id: "friend-request-2",
                from: "mock-user-id",
                fromUsername: "Me",
                fromAvatarVersion: 0,
                to: "friend-2",
                toUsername: "Sam Lee",
                toAvatarVersion: 0,
                msg: "Let's split rent",
                status: "accepted",
                createdAt: Date().addingTimeInterval(-86400),
                direction: .sent
            ),
        ]
    }
}
