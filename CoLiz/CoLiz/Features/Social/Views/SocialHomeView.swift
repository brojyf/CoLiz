import SwiftUI

struct SocialHomeView: View {
    private struct SocialGroupNavigationTarget: Identifiable, Hashable {
        let id: String
    }

    private enum QuickAction: String, Identifiable {
        case addFriend
        case createGroup
        case inviteFriend

        var id: String { rawValue }
    }

    @EnvironmentObject private var vm: TodoVM
    @EnvironmentObject private var navigationState: MainTabNavigationState
    @State private var searchText = ""
    @State private var isShowingSearch = false
    @State private var isRequestsExpanded = true
    @State private var selectedGroup: SocialGroupNavigationTarget?
    @State private var selectedFriend: FriendUser?
    @State private var quickAction: QuickAction?
    @FocusState private var isSearchFieldFocused: Bool

    private var groupIDs: [String] {
        filteredGroups.map(\.id)
    }

    private var friendIDs: [String] {
        filteredFriends.map(\.id)
    }

    private var requestIDs: [String] {
        filteredRequests.map(\.id)
    }

    private var hasPendingReceivedRequests: Bool {
        vm.friendRequests.contains { $0.direction == .received && $0.isPending }
    }

    private var hasPendingSentRequests: Bool {
        vm.friendRequests.contains { $0.direction == .sent && $0.isPending }
    }

    private var shouldExpandRequestsSection: Bool {
        hasPendingReceivedRequests || hasPendingSentRequests
    }

    private var filteredGroups: [AppGroup] {
        guard !trimmedSearchText.isEmpty else { return vm.groups }
        return vm.groups.filter {
            $0.groupName.localizedCaseInsensitiveContains(trimmedSearchText)
        }
    }

    private var filteredFriends: [FriendUser] {
        guard !trimmedSearchText.isEmpty else { return vm.friends }
        return vm.friends.filter {
            $0.username.localizedCaseInsensitiveContains(trimmedSearchText)
                || $0.email.localizedCaseInsensitiveContains(trimmedSearchText)
        }
    }

    private var filteredRequests: [FriendRequest] {
        let requests = vm.friendRequests.sorted { $0.createdAt > $1.createdAt }
        guard !trimmedSearchText.isEmpty else { return requests }
        return requests.filter {
            $0.from.localizedCaseInsensitiveContains(trimmedSearchText)
                || $0.to.localizedCaseInsensitiveContains(trimmedSearchText)
                || ($0.msg?.localizedCaseInsensitiveContains(trimmedSearchText) ?? false)
        }
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        List {
            if isShowingSearch {
                searchSection
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            requestsSection
            groupsSection
            friendsSection
        }
        .listStyle(.plain)
        .listSectionSpacing(.compact)
        .contentMargins(.top, 0, for: .scrollContent)
        .navigationTitle("Friends & Groups")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .colistScreenBackground()
        .navigationDestination(item: $selectedGroup) { target in
            GroupDetailView(groupID: target.id)
        }
        .navigationDestination(item: $selectedFriend) { friend in
            FriendDetailView(friendID: friend.id, initialFriend: friend)
        }
        .animation(CoListMotion.sectionToggle, value: isShowingSearch)
        .animation(CoListMotion.sectionToggle, value: isRequestsExpanded)
        .animation(CoListMotion.sectionToggle, value: requestIDs)
        .animation(CoListMotion.sectionToggle, value: groupIDs)
        .animation(CoListMotion.sectionToggle, value: friendIDs)
        .task {
            vm.prefetchGroupsIfNeeded()
            vm.prefetchFriendsIfNeeded()
            if vm.friendRequests.isEmpty {
                vm.prefetchFriendRequestsIfNeeded()
            }
            syncRequestsExpansion()
            handlePendingSocialNavigation()
        }
        .refreshable {
            await vm.refreshSocial()
        }
        .onChange(of: hasPendingReceivedRequests) { _, _ in
            syncRequestsExpansion()
        }
        .onChange(of: hasPendingSentRequests) { _, _ in
            syncRequestsExpansion()
        }
        .onChange(of: navigationState.socialGroupIDToOpen) { _, _ in
            handlePendingSocialNavigation()
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    withAnimation(CoListMotion.sectionToggle) {
                        isShowingSearch.toggle()
                    }
                    if isShowingSearch {
                        isSearchFieldFocused = true
                    } else {
                        searchText = ""
                        isSearchFieldFocused = false
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(.plain)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        quickAction = .addFriend
                    } label: {
                        Label("Add Friend", systemImage: "person.badge.plus")
                    }

                    Button {
                        quickAction = .createGroup
                    } label: {
                        Label("Create Group", systemImage: "person.3.sequence.fill")
                    }

                    Button {
                        quickAction = .inviteFriend
                    } label: {
                        Label("Invite Friend", systemImage: "envelope.badge.fill")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $quickAction) { action in
            NavigationStack {
                switch action {
                case .addFriend:
                    AddFriendSheetView()
                case .createGroup:
                    AddGroupSheetView()
                case .inviteFriend:
                    InviteFriendSheetView()
                }
            }
        }
    }

    private var searchSection: some View {
        Section {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppTheme.secondary)

                TextField("Search friends or groups", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isSearchFieldFocused)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppTheme.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .colistInputField()
            .colistReveal(animation: CoListMotion.screenReveal, yOffset: 10, startScale: 0.995)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 4, trailing: 16))
        }
    }

    private var requestsSection: some View {
        Section {
            if isRequestsExpanded {
                if vm.friendRequests.isEmpty {
                    emptyStateRow("No requests yet.")
                } else if filteredRequests.isEmpty {
                    emptyStateRow("No matching requests.")
                } else {
                    ForEach(Array(filteredRequests.enumerated()), id: \.element.id) { index, req in
                        requestRow(req, index: index)
                    }
                }
            }
        } header: {
            Button {
                withAnimation(CoListMotion.sectionToggle) {
                    isRequestsExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Requests")
                    Spacer()
                    Image(systemName: isRequestsExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var groupsSection: some View {
        Section("My Groups") {
            if vm.groups.isEmpty {
                emptyStateRow("No groups yet.")
            } else if filteredGroups.isEmpty {
                emptyStateRow("No matching groups.")
            }
            ForEach(Array(filteredGroups.enumerated()), id: \.element.id) { index, group in
                groupRow(group, index: index)
            }
        }
    }

    private var friendsSection: some View {
        Section("My Friends") {
            if vm.friends.isEmpty {
                emptyStateRow("No friends yet.")
            } else if filteredFriends.isEmpty {
                emptyStateRow("No matching friends.")
            }
            ForEach(Array(filteredFriends.enumerated()), id: \.element.id) { index, friend in
                friendRow(friend, index: index)
            }
        }
    }

    private func requestRow(_ req: FriendRequest, index: Int) -> some View {
        SocialRequestRowView(
            req: req,
            displayName: req.direction == .received
                ? (req.fromUsername ?? req.from)
                : (req.toUsername ?? req.to),
            avatarURL: req.direction == .received ? req.fromAvatarURL : req.toAvatarURL,
            canAccept: req.direction == .received && req.isPending,
            isAccepting: vm.acceptingFriendRequestIDs.contains(req.id),
            canDecline: req.direction == .received && req.isPending,
            isDeclining: vm.decliningFriendRequestIDs.contains(req.id),
            canCancel: req.direction == .sent && req.isPending,
            isCancelling: vm.cancellingFriendRequestIDs.contains(req.id),
            onAccept: {
                vm.acceptFriendRequest(requestID: req.id)
            },
            onDecline: {
                vm.declineFriendRequest(requestID: req.id)
            },
            onCancel: {
                vm.cancelFriendRequest(requestID: req.id)
            }
        )
        .colistReveal(animation: CoListMotion.stagger(at: index), yOffset: 18, startScale: 0.992)
        .colistCardListRow()
    }

    private func groupRow(_ group: AppGroup, index: Int) -> some View {
        Button {
            selectedGroup = SocialGroupNavigationTarget(id: group.id)
        } label: {
            GroupRowView(
                groupName: group.groupName,
                remoteAvatarURL: group.resolvedAvatarURL,
                verticalPadding: 0,
                showsChevron: true
            )
            .colistReveal(animation: CoListMotion.stagger(at: index), yOffset: 18, startScale: 0.992)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .colistCardListRow()
    }

    private func friendRow(_ friend: FriendUser, index: Int) -> some View {
        Button {
            selectedFriend = friend
        } label: {
            FriendRowView(
                username: friend.username,
                remoteAvatarURL: friend.resolvedAvatarURL,
                verticalPadding: 0,
                showsChevron: true
            )
            .colistReveal(animation: CoListMotion.stagger(at: index), yOffset: 18, startScale: 0.992)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .colistCardListRow()
    }

    private func emptyStateRow(_ message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(AppTheme.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .colistRowCard(fill: AppTheme.surface, horizontalPadding: 16, verticalPadding: 18)
            .colistReveal(yOffset: 14, startScale: 0.994)
            .colistCardListRow()
    }

    private func syncRequestsExpansion() {
        guard isRequestsExpanded != shouldExpandRequestsSection else { return }
        withAnimation(CoListMotion.sectionToggle) {
            isRequestsExpanded = shouldExpandRequestsSection
        }
    }

    private func handlePendingSocialNavigation() {
        guard let groupID = navigationState.socialGroupIDToOpen else { return }
        selectedGroup = SocialGroupNavigationTarget(id: groupID)
        navigationState.consumeSocialGroup()
    }
}
