import Foundation

struct UserProfile: Identifiable, Codable, Equatable {
    let id: String
    let username: String
    let email: String
    let avatarVersion: UInt32

    var resolvedAvatarURL: URL {
        return API.Users.avatar(userID: id, version: avatarVersion)
    }
}

extension UserProfile {
    static func mock(avatarVersion: UInt32 = 0) -> UserProfile {
        UserProfile(
            id: "mock-user-id",
            username: "mock_user",
            email: "mock_user@example.com",
            avatarVersion: avatarVersion
        )
    }
}
