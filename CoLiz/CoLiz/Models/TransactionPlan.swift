import Foundation

struct TransactionTransfer: Codable, Equatable, Identifiable {
    let fromUserID: String
    let fromUsername: String
    let fromAvatarVersion: UInt32
    let toUserID: String
    let toUsername: String
    let toAvatarVersion: UInt32
    let amount: String

    var id: String {
        "\(fromUserID)-\(toUserID)-\(amount)"
    }

    var fromAvatarURL: URL {
        API.Users.avatar(userID: fromUserID, version: fromAvatarVersion)
    }

    var toAvatarURL: URL {
        API.Users.avatar(userID: toUserID, version: toAvatarVersion)
    }

    enum CodingKeys: String, CodingKey {
        case fromUserID = "fromUserId"
        case fromUsername = "fromUsername"
        case fromAvatarVersion = "fromAvatarVersion"
        case toUserID = "toUserId"
        case toUsername = "toUsername"
        case toAvatarVersion = "toAvatarVersion"
        case amount
    }
}

struct GroupTransactionPlan: Codable, Equatable {
    let groupID: String
    let groupName: String
    let groupAvatarVersion: UInt32
    let transfers: [TransactionTransfer]

    var resolvedAvatarURL: URL {
        API.Groups.avatar(groupID: groupID, version: groupAvatarVersion)
    }

    enum CodingKeys: String, CodingKey {
        case groupID = "groupId"
        case groupName = "groupName"
        case groupAvatarVersion = "groupAvatarVersion"
        case transfers
    }
}

extension GroupTransactionPlan {
    static func mock(groupID: String, groupName: String) -> GroupTransactionPlan {
        GroupTransactionPlan(
            groupID: groupID,
            groupName: groupName,
            groupAvatarVersion: 0,
            transfers: [
                TransactionTransfer(
                    fromUserID: "friend-1",
                    fromUsername: "Alex Chen",
                    fromAvatarVersion: 0,
                    toUserID: "friend-2",
                    toUsername: "Jordan Park",
                    toAvatarVersion: 0,
                    amount: "12.50"
                )
            ]
        )
    }
}
