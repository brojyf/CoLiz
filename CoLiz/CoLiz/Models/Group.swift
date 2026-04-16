//
//  Group.swift
//  CoList
//
//  Created by 江逸帆 on 2/14/26.
//

import Foundation

struct AppGroup: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let groupName: String
    let avatarVersion: UInt32
    let isOwner: Bool
    let createdAt: Date

    var resolvedAvatarURL: URL {
        return API.Groups.avatar(groupID: id, version: avatarVersion)
    }
}

struct GroupMember: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let username: String
    let email: String
    let avatarVersion: UInt32

    var resolvedAvatarURL: URL {
        return API.Users.avatar(userID: id, version: avatarVersion)
    }
}

struct GroupDetail: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let groupName: String
    let avatarVersion: UInt32
    let ownerId: String
    let isOwner: Bool
    let createdAt: Date
    let members: [GroupMember]

    var resolvedAvatarURL: URL {
        return API.Groups.avatar(groupID: id, version: avatarVersion)
    }

    var asAppGroup: AppGroup {
        AppGroup(
            id: id,
            groupName: groupName,
            avatarVersion: avatarVersion,
            isOwner: isOwner,
            createdAt: createdAt
        )
    }
}

extension AppGroup {
    static func mockList() -> [AppGroup] {
        [
            AppGroup(
                id: "group-home",
                groupName: "Roommates",
                avatarVersion: 0,
                isOwner: true,
                createdAt: Date().addingTimeInterval(-86400)
            ),
            AppGroup(
                id: "group-work",
                groupName: "Work Buddies",
                avatarVersion: 0,
                isOwner: false,
                createdAt: Date().addingTimeInterval(-3600)
            ),
        ]
    }
}
