import SwiftUI

struct AddFriendSheetView: View {
    @EnvironmentObject private var vm: TodoVM
    @EnvironmentObject private var navigationState: MainTabNavigationState
    @Environment(\.dismiss) private var dismiss
    var onClose: (() -> Void)? = nil
    var onSuccess: (() -> Void)? = nil

    var body: some View {
        List {
            Section("Search by Email") {
                TextField("friend@example.com", text: $vm.friendSearchEmail)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .keyboardType(.emailAddress)
                    .submitLabel(.search)
                    .onSubmit {
                        vm.searchFriendByEmail()
                    }
                    .colistInputField()
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                Button {
                    vm.searchFriendByEmail()
                } label: {
                    if vm.isSearchingFriend {
                        ProgressView()
                            .tint(AppTheme.onBrand)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Search")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(CoListFilledButtonStyle(tone: .secondary))
                .disabled(
                    vm.isSearchingFriend
                    || vm.friendSearchEmail
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .isEmpty
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            Section("Send Request") {
                if let user = vm.friendSearchResult {
                    FriendRowView(
                        username: user.username,
                        remoteAvatarURL: user.resolvedAvatarURL,
                        avatarSize: ComponentMetrics.rowAvatarSize
                    )

                    TextField("Message (required, max 64)", text: $vm.friendRequestMessage, axis: .vertical)
                        .lineLimit(1...3)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .colistInputField()

                    Button {
                        vm.sendFriendRequest {
                            completeSheet()
                        }
                    } label: {
                        if vm.isSendingFriendRequest {
                            ProgressView()
                                .tint(AppTheme.onBrand)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Send Friend Request")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(CoListFilledButtonStyle())
                    .disabled(
                        vm.isSendingFriendRequest
                        || vm.friendRequestMessage
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .isEmpty
                    )
                } else if vm.didSearchFriend && vm.friendNotFound {
                    Text("No user found for this email.")
                        .foregroundStyle(AppTheme.secondary)
                } else {
                    Text("Search a user first.")
                        .foregroundStyle(AppTheme.secondary)
                }
            }
        }
        .navigationTitle("Add Friend")
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .task {
            vm.resetFriendSearchState()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    closeSheet()
                }
            }
        }
    }

    private func closeSheet() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    private func completeSheet() {
        navigationState.openSocialHome()
        if let onSuccess {
            onSuccess()
        } else {
            closeSheet()
        }
    }
}

struct AllRequestsView: View {
    @EnvironmentObject private var vm: TodoVM

    private var receivedRequests: [FriendRequest] {
        vm.friendRequests.filter { $0.direction == .received }
    }

    private var sentRequests: [FriendRequest] {
        vm.friendRequests.filter { $0.direction == .sent }
    }

    var body: some View {
        List {
            Section("Received") {
                if receivedRequests.isEmpty {
                    Text("No received requests yet.")
                        .foregroundStyle(AppTheme.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .colistRowCard(fill: AppTheme.surface, horizontalPadding: 16, verticalPadding: 18)
                        .colistCardListRow()
                } else {
                    ForEach(receivedRequests) { req in
                        SocialRequestRowView(
                            req: req,
                            displayName: req.fromUsername ?? req.from,
                            avatarURL: req.fromAvatarURL,
                            canAccept: req.isPending,
                            isAccepting: vm.acceptingFriendRequestIDs.contains(req.id),
                            canDecline: req.isPending,
                            isDeclining: vm.decliningFriendRequestIDs.contains(req.id),
                            canCancel: false,
                            isCancelling: false,
                            onAccept: {
                                vm.acceptFriendRequest(requestID: req.id)
                            },
                            onDecline: {
                                vm.declineFriendRequest(requestID: req.id)
                            },
                            onCancel: {}
                        )
                        .colistCardListRow()
                    }
                }
            }

            Section("Sent") {
                if sentRequests.isEmpty {
                    Text("No sent requests yet.")
                        .foregroundStyle(AppTheme.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .colistRowCard(fill: AppTheme.surface, horizontalPadding: 16, verticalPadding: 18)
                        .colistCardListRow()
                } else {
                    ForEach(sentRequests) { req in
                        SocialRequestRowView(
                            req: req,
                            displayName: req.toUsername ?? req.to,
                            avatarURL: req.toAvatarURL,
                            canAccept: false,
                            isAccepting: false,
                            canDecline: false,
                            isDeclining: false,
                            canCancel: req.isPending,
                            isCancelling: vm.cancellingFriendRequestIDs.contains(req.id),
                            onAccept: {},
                            onDecline: {},
                            onCancel: {
                                vm.cancelFriendRequest(requestID: req.id)
                            }
                        )
                        .colistCardListRow()
                    }
                }
            }
        }
        .listStyle(.plain)
        .listSectionSpacing(.compact)
        .contentMargins(.top, 0, for: .scrollContent)
        .navigationTitle("All Requests")
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .task {
            vm.loadFriendRequests()
        }
    }
}

struct AddGroupSheetView: View {
    @EnvironmentObject private var vm: TodoVM
    @EnvironmentObject private var navigationState: MainTabNavigationState
    @Environment(\.dismiss) private var dismiss
    var onClose: (() -> Void)? = nil
    var onSuccess: (() -> Void)? = nil
    @State private var groupName = ""

    var body: some View {
        Form {
            Section("New Group") {
                TextField("Group Name", text: $groupName)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .onSubmit {
                        submit()
                    }
            }
        }
        .navigationTitle("Add Group")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    closeSheet()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    submit()
                } label: {
                    if vm.isCreatingGroup {
                        ProgressView()
                    } else {
                        Text("Create")
                    }
                }
                .disabled(
                    vm.isCreatingGroup
                    || groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
        }
    }

    private func submit() {
        vm.createGroup(name: groupName) { group in
            navigationState.openSocialGroup(group.id)
            completeSheet()
        }
    }

    private func closeSheet() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    private func completeSheet() {
        if let onSuccess {
            onSuccess()
        } else {
            closeSheet()
        }
    }
}

struct InviteFriendSheetView: View {
    @EnvironmentObject private var vm: TodoVM
    @EnvironmentObject private var navigationState: MainTabNavigationState
    @Environment(\.dismiss) private var dismiss
    var onClose: (() -> Void)? = nil
    var onSuccess: (() -> Void)? = nil
    let routesToSocialGroupOnSuccess: Bool
    let fixedGroupID: String?
    let fixedGroupName: String?
    let excludedFriendIDs: Set<String>
    @State private var selectedGroupID = ""
    @State private var selectedFriendIDs = Set<String>()

    init(
        fixedGroupID: String? = nil,
        fixedGroupName: String? = nil,
        excludedFriendIDs: Set<String> = [],
        routesToSocialGroupOnSuccess: Bool = true,
        onClose: (() -> Void)? = nil,
        onSuccess: (() -> Void)? = nil
    ) {
        self.fixedGroupID = fixedGroupID
        self.fixedGroupName = fixedGroupName
        self.excludedFriendIDs = excludedFriendIDs
        self.routesToSocialGroupOnSuccess = routesToSocialGroupOnSuccess
        self.onClose = onClose
        self.onSuccess = onSuccess
    }

    private var availableFriends: [FriendUser] {
        vm.friends.filter { !excludedFriendIDs.contains($0.id) }
    }

    var body: some View {
        List {
            if let fixedGroupID {
                Section("Group") {
                    if let fixedGroup = vm.groups.first(where: { $0.id == fixedGroupID }) {
                        GroupRowView(
                            groupName: fixedGroup.groupName,
                            remoteAvatarURL: fixedGroup.resolvedAvatarURL,
                            avatarSize: ComponentMetrics.rowAvatarSize
                        )
                    } else if let fixedGroupName {
                        GroupRowView(
                            groupName: fixedGroupName,
                            remoteAvatarURL: nil,
                            avatarSize: ComponentMetrics.rowAvatarSize
                        )
                    } else {
                        Text("Current group")
                            .foregroundStyle(AppTheme.secondary)
                    }
                }
            } else {
                Section("Group") {
                    if vm.groups.isEmpty {
                        Text("Create a group first.")
                            .foregroundStyle(AppTheme.secondary)
                    } else {
                        Picker("Group", selection: $selectedGroupID) {
                            ForEach(vm.groups) { group in
                                Text(group.groupName).tag(group.id)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }
                }
            }

            Section(friendSectionTitle) {
                if vm.friends.isEmpty {
                    Text("Add a friend first.")
                        .foregroundStyle(AppTheme.secondary)
                } else if availableFriends.isEmpty {
                    Text("All your friends are already in this group.")
                        .foregroundStyle(AppTheme.secondary)
                } else {
                    ForEach(availableFriends) { friend in
                        Button {
                            toggleFriendSelection(friend.id)
                        } label: {
                            inviteFriendRow(friend)
                        }
                        .buttonStyle(.plain)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                }
            }
        }
        .navigationTitle("Invite To Group")
        .listStyle(.plain)
        .listSectionSpacing(.compact)
        .contentMargins(.top, 0, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .task {
            vm.prefetchGroupsIfNeeded()
            vm.prefetchFriendsIfNeeded()
            syncSelections()
        }
        .onChange(of: vm.groups) { _, _ in
            syncSelections()
        }
        .onChange(of: vm.friends) { _, _ in
            syncSelections()
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    closeSheet()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    submit()
                } label: {
                    if vm.isInvitingFriendToGroup {
                        ProgressView()
                    } else {
                        Text("Invite")
                    }
                }
                .disabled(
                    vm.isInvitingFriendToGroup
                    || selectedGroupID.isEmpty
                    || selectedFriendIDs.isEmpty
                )
            }
        }
    }

    private var friendSectionTitle: String {
        if selectedFriendIDs.isEmpty {
            return "Friends"
        }
        return "Friends (\(selectedFriendIDs.count) selected)"
    }

    private func syncSelections() {
        if let fixedGroupID {
            selectedGroupID = fixedGroupID
        } else if selectedGroupID.isEmpty || !vm.groups.contains(where: { $0.id == selectedGroupID }) {
            selectedGroupID = vm.groups.first?.id ?? ""
        }
        let availableFriendIDs = Set(availableFriends.map(\.id))
        selectedFriendIDs = selectedFriendIDs.intersection(availableFriendIDs)
    }

    private func submit() {
        vm.inviteFriendsToGroup(groupID: selectedGroupID, userIDs: Array(selectedFriendIDs)) {
            if fixedGroupID != nil {
                vm.fetchGroupDetail(groupID: selectedGroupID)
            }
            if routesToSocialGroupOnSuccess {
                navigationState.openSocialGroup(selectedGroupID)
            }
            completeSheet()
        }
    }

    private func toggleFriendSelection(_ friendID: String) {
        if selectedFriendIDs.contains(friendID) {
            selectedFriendIDs.remove(friendID)
        } else {
            selectedFriendIDs.insert(friendID)
        }
    }

    private func inviteFriendRow(_ friend: FriendUser) -> some View {
        let isSelected = selectedFriendIDs.contains(friend.id)

        return HStack(spacing: ComponentMetrics.rowSpacing) {
            CircularAvatarView(
                image: nil,
                remoteAvatarURL: friend.resolvedAvatarURL,
                size: ComponentMetrics.rowAvatarSize,
                placeholderSystemImage: "person.fill"
            )

            Text(friend.username)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)

            Spacer(minLength: 0)

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.headline.weight(.semibold))
                .foregroundStyle(isSelected ? AppTheme.primary : AppTheme.border)
        }
        .colistRowCard(
            fill: isSelected ? AppTheme.creamStrong.opacity(0.65) : AppTheme.surface,
            verticalPadding: 14
        )
    }

    private func closeSheet() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    private func completeSheet() {
        if let onSuccess {
            onSuccess()
        } else {
            closeSheet()
        }
    }
}
