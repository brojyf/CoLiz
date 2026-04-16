import SwiftUI

struct FriendDetailView: View {
    @EnvironmentObject private var vm: TodoVM
    @State private var selectedSharedGroup: AppGroup?

    let friendID: String
    let initialFriend: FriendUser

    private static let friendSinceFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private var friend: FriendUser? {
        vm.friendDetail(for: friendID) ?? (initialFriend.id == friendID ? initialFriend : nil)
    }

    private var isLoading: Bool {
        vm.loadingFriendDetailIDs.contains(friendID)
    }

    private var mutualGroups: [AppGroup]? {
        friend?.mutualGroups
    }

    var body: some View {
        Group {
            if let friend {
                List {
                    headerSection(friend)
                    colistSection(friend)
                    aboutSection(friend)
                    sharedGroupsSection
                }
                .navigationTitle(friend.username)
                .navigationBarTitleDisplayMode(.inline)
                .scrollContentBackground(.hidden)
                .background(AppTheme.background)
            } else if isLoading {
                Section {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Loading friend details...")
                            .foregroundStyle(AppTheme.secondary)
                    }
                }
                .listStyle(.plain)
                .listSectionSpacing(.compact)
                .contentMargins(.top, 0, for: .scrollContent)
                .navigationTitle(initialFriend.username)
                .navigationBarTitleDisplayMode(.inline)
                .scrollContentBackground(.hidden)
                .background(AppTheme.background)
            } else {
                ContentUnavailableView(
                    "Friend Not Found",
                    systemImage: "person.fill",
                    description: Text("Refresh the social page and try again.")
                )
                .navigationTitle(initialFriend.username)
            }
        }
        .navigationDestination(item: $selectedSharedGroup) { group in
            GroupDetailView(groupID: group.id)
        }
        .task {
            vm.fetchFriendDetail(friendID: friendID)
        }
    }

    private func headerSection(_ friend: FriendUser) -> some View {
        Section {
            VStack(spacing: 16) {
                CircularAvatarView(
                    image: nil,
                    remoteAvatarURL: friend.resolvedAvatarURL,
                    size: ComponentMetrics.profileAvatarSize,
                    placeholderSystemImage: "person.fill",
                    placeholderImageScale: 0.3
                )

                VStack(spacing: 6) {
                    Text(friend.username)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)

                    Text(friend.email)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondary)
                        .multilineTextAlignment(.center)

                    if let friendSince = friend.friendSince {
                        Text("Friends since \(Self.friendSinceFormatter.string(from: friendSince))")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
            .colistCard(fill: AppTheme.surface, cornerRadius: ComponentMetrics.largeCardCornerRadius)
        }
    }

    @ViewBuilder
    private func colistSection(_ friend: FriendUser) -> some View {
        Section("CoList") {
            friendActionRow(
                systemImage: "person.2.fill",
                title: "Shared Groups",
                subtitle: sharedGroupsSummaryText(for: friend)
            )

            friendActionRow(
                systemImage: "clock.arrow.circlepath",
                title: "Friendship",
                subtitle: friendshipSummaryText(for: friend)
            )
        }
    }

    private func aboutSection(_ friend: FriendUser) -> some View {
        Section("About") {
            infoRow(title: "Email", value: friend.email)

            if let friendSince = friend.friendSince {
                infoRow(
                    title: "Friends Since",
                    value: Self.friendSinceFormatter.string(from: friendSince)
                )
                infoRow(
                    title: "Duration",
                    value: friendshipDurationText(friendSince)
                )
            }
        }
    }

    private var sharedGroupsSection: some View {
        Section("Shared Groups") {
            if let mutualGroups, mutualGroups.isEmpty {
                emptySharedGroupRow("No shared groups yet.")
            } else if let mutualGroups {
                ForEach(mutualGroups) { group in
                    Button {
                        selectedSharedGroup = group
                    } label: {
                        GroupRowView(
                            groupName: group.groupName,
                            remoteAvatarURL: group.resolvedAvatarURL,
                            avatarSize: ComponentMetrics.compactRowAvatarSize,
                            showsChevron: true
                        )
                    }
                    .buttonStyle(.plain)
                    .colistCardListRow()
                }
            } else if isLoading {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Loading shared groups...")
                        .foregroundStyle(AppTheme.secondary)
                }
                .colistRowCard(fill: AppTheme.surface, horizontalPadding: 16, verticalPadding: 18)
                .colistCardListRow()
            } else {
                emptySharedGroupRow("No shared groups yet.")
            }
        }
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack(spacing: 14) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)

            Spacer(minLength: 12)

            Text(value)
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondary)
                .multilineTextAlignment(.trailing)
        }
        .colistRowCard(fill: AppTheme.surface, horizontalPadding: 16, verticalPadding: 14)
        .colistCardListRow()
    }

    private func emptySharedGroupRow(_ message: String) -> some View {
        Text(message)
            .foregroundStyle(AppTheme.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .colistRowCard(fill: AppTheme.surface, horizontalPadding: 16, verticalPadding: 18)
            .colistCardListRow()
    }

    private func friendActionRow(systemImage: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(AppTheme.primary)
                .padding(10)
                .background(
                    Circle().fill(AppTheme.creamStrong)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .foregroundStyle(AppTheme.ink)

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondary)
            }

            Spacer(minLength: 0)
        }
        .colistRowCard(fill: AppTheme.surface, horizontalPadding: 16, verticalPadding: 14)
        .colistCardListRow()
    }

    private func sharedGroupsSummaryText(for friend: FriendUser) -> String {
        guard let mutualGroups else { return "Loading shared groups..." }
        let count = mutualGroups.count
        if count == 0 {
            return "No shared groups yet"
        }
        if count == 1 {
            return "1 shared group"
        }
        return "\(count) shared groups"
    }

    private func friendshipSummaryText(for friend: FriendUser) -> String {
        guard let friendSince = friend.friendSince else {
            return "Connected on CoList"
        }
        return "Friends for \(friendshipDurationText(friendSince))"
    }

    private func friendshipDurationText(_ friendSince: Date) -> String {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: friendSince)
        let today = calendar.startOfDay(for: Date())
        let days = max(0, calendar.dateComponents([.day], from: start, to: today).day ?? 0)

        if days == 1 {
            return "1 day"
        }
        return "\(days) days"
    }
}
