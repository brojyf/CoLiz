import PhotosUI
import SwiftUI
import UIKit

struct GroupDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var vm: TodoVM
    @EnvironmentObject private var profileVM: ProfileVM

    let groupID: String

    @State private var avatarImage: UIImage?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var pendingAvatarCrop: AvatarCropRequest?
    @State private var showInviteFriendSheet = false
    @State private var draftGroupName = ""
    @State private var isGroupNameEditorPresented = false
    @State private var showLeaveGroupConfirmation = false
    @State private var showDeleteGroupConfirmation = false
    @State private var showGroupTodos = false
    @State private var showGroupExpenses = false

    private static let createdAtFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private var group: AppGroup? {
        vm.groups.first(where: { $0.id == groupID })
    }

    private var groupDetail: GroupDetail? {
        vm.groupDetail(for: groupID)
    }

    private var groupSummary: AppGroup? {
        groupDetail?.asAppGroup ?? group
    }

    private var expenseSummary: GroupExpense? {
        vm.groupExpense(for: groupID)
    }

    private var isUploadingAvatar: Bool {
        vm.uploadingGroupAvatarIDs.contains(groupID)
    }

    private var isUpdatingGroupName: Bool {
        vm.updatingGroupNameIDs.contains(groupID)
    }

    private var isDeletingGroup: Bool {
        vm.deletingGroupIDs.contains(groupID)
    }

    private var isLeavingGroup: Bool {
        vm.leavingGroupIDs.contains(groupID)
    }

    private var isLoadingDetail: Bool {
        vm.loadingGroupDetailIDs.contains(groupID)
    }

    private var ownerMember: GroupMember? {
        groupDetail?.members.first(where: { $0.id == groupDetail?.ownerId })
    }

    private var sortedMembers: [GroupMember] {
        guard let groupDetail else { return [] }
        return groupDetail.members.sorted { lhs, rhs in
            let lhsIsOwner = lhs.id == groupDetail.ownerId
            let rhsIsOwner = rhs.id == groupDetail.ownerId

            if lhsIsOwner != rhsIsOwner {
                return lhsIsOwner
            }

            return lhs.username.localizedCaseInsensitiveCompare(rhs.username) == .orderedAscending
        }
    }

    private var nonOwnerMembers: [GroupMember] {
        guard let groupDetail else { return [] }
        return sortedMembers.filter { $0.id != groupDetail.ownerId }
    }

    private var memberIDs: Set<String> {
        Set(sortedMembers.map(\.id))
    }

    private var friendIDs: Set<String> {
        Set(vm.friends.map(\.id))
    }

    private var currentUserID: String? {
        profileVM.profile?.id
    }

    var body: some View {
        Group {
            if let groupSummary {
                List {
                    headerSection(groupSummary)
                    colistSection(groupSummary)
                    membersSection
                    dangerSection
                }
                .navigationTitle(groupSummary.groupName)
                .navigationBarTitleDisplayMode(.inline)
                .scrollContentBackground(.hidden)
                .background(AppTheme.background)
            } else {
                ContentUnavailableView(
                    "Group Not Found",
                    systemImage: "person.3.sequence.fill",
                    description: Text("Refresh the social page and try again.")
                )
                .navigationTitle("Group")
            }
        }
        .task {
            vm.prefetchGroupsIfNeeded()
            vm.prefetchGroupExpensesIfNeeded()
            vm.prefetchFriendsIfNeeded()
            vm.prefetchFriendRequestsIfNeeded()
            vm.fetchGroupDetail(groupID: groupID)
        }
        .onChange(of: selectedPhoto) { _, newValue in
            handleSelectedPhoto(newValue)
        }
        .navigationDestination(isPresented: $showGroupTodos) {
            if let groupSummary {
                GroupTodosView(group: groupSummary)
            }
        }
        .navigationDestination(isPresented: $showGroupExpenses) {
            GroupExpenseSummaryView(groupID: groupID, showsGroupLink: false)
        }
        .sheet(isPresented: $showInviteFriendSheet) {
            NavigationStack {
                InviteFriendSheetView(
                    fixedGroupID: groupID,
                    fixedGroupName: groupSummary?.groupName,
                    excludedFriendIDs: memberIDs,
                    routesToSocialGroupOnSuccess: false
                )
            }
        }
        .sheet(item: $pendingAvatarCrop) { request in
            SquareAvatarCropperSheet(
                image: request.image,
                onCancel: {
                    pendingAvatarCrop = nil
                },
                onConfirm: { croppedImage in
                    guard let uploadData = AvatarUploadImageProcessor.prepareJPEGData(from: croppedImage) else {
                        pendingAvatarCrop = nil
                        return
                    }

                    avatarImage = croppedImage
                    pendingAvatarCrop = nil
                    vm.uploadGroupAvatar(groupID: groupID, data: uploadData)
                }
            )
        }
        .alert("Edit Group Name", isPresented: $isGroupNameEditorPresented) {
            TextField("Group Name", text: $draftGroupName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled(true)

            Button("Cancel", role: .cancel) { }

            Button(isUpdatingGroupName ? "Saving..." : "Save") {
                vm.updateGroupName(groupID: groupID, name: draftGroupName) {
                    isGroupNameEditorPresented = false
                }
            }
            .disabled(isUpdatingGroupName || draftGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Anyone in this group can update the group name.")
        }
    }

    @ViewBuilder
    private func headerSection(_ groupSummary: AppGroup) -> some View {
        Section {
            VStack(spacing: 16) {
                EditableGroupAvatarView(
                    avatarImage: $avatarImage,
                    remoteAvatarURL: groupSummary.resolvedAvatarURL,
                    isUploading: isUploadingAvatar,
                    canEdit: true,
                    selectedPhoto: $selectedPhoto
                )

                VStack(spacing: 6) {
                    Button {
                        draftGroupName = groupSummary.groupName
                        isGroupNameEditorPresented = true
                    } label: {
                        HStack(spacing: 8) {
                            Text(groupSummary.groupName)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(AppTheme.ink)

                            if isUpdatingGroupName {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "square.and.pencil")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(AppTheme.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isUpdatingGroupName)

                    Text("Created \(Self.createdAtFormatter.string(from: groupSummary.createdAt))")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
            .colistCard(fill: AppTheme.surface, cornerRadius: ComponentMetrics.largeCardCornerRadius)
        }
    }

    @ViewBuilder
    private func colistSection(_ groupSummary: AppGroup) -> some View {
        Section {
            Button {
                showGroupTodos = true
            } label: {
                groupActionRow(
                    systemImage: "checklist",
                    title: "View All Todos",
                    subtitle: "View all todos in this group"
                )
            }
            .buttonStyle(.plain)

            Button {
                showGroupExpenses = true
            } label: {
                groupActionRow(
                    systemImage: "creditcard",
                    title: "Expense Summary",
                    subtitle: expenseSummary?.summaryText ?? "Current balance for this group"
                )
            }
            .buttonStyle(.plain)
        } header: {
            Text("CoList")
        }
    }

    private var membersSection: some View {
        Section {
            if isLoadingDetail && groupDetail == nil {
                HStack {
                    ProgressView()
                    Text("Loading members...")
                        .foregroundStyle(AppTheme.secondary)
                }
            } else if let ownerMember {
                memberRow(ownerMember, trailingText: "owner")

                ForEach(nonOwnerMembers) { member in
                    memberRow(member)
                }
            } else if !sortedMembers.isEmpty {
                ForEach(sortedMembers) { member in
                    memberRow(member)
                }
            } else {
                Text("No members found.")
                    .foregroundStyle(AppTheme.secondary)
            }
        } header: {
            membersHeader
        }
    }

    private var membersHeader: some View {
        HStack {
            Text("Members")
            Spacer()

            Button {
                showInviteFriendSheet = true
            } label: {
                Label("Invite", systemImage: "person.badge.plus")
                    .labelStyle(.titleAndIcon)
            }
            .font(.footnote.weight(.semibold))
            .buttonStyle(
                CoListFilledButtonStyle(
                    tone: .butter,
                    horizontalPadding: 14,
                    verticalPadding: 7
                )
            )
            .disabled(vm.isInvitingFriendToGroup || vm.friends.isEmpty)
        }
    }

    private var dangerSection: some View {
        Section {
            if groupSummary?.isOwner == true {
                Button(role: .destructive) {
                    showDeleteGroupConfirmation = true
                } label: {
                    HStack(spacing: 12) {
                        if isDeletingGroup {
                            ProgressView()
                                .tint(.red)
                        } else {
                            Image(systemName: "trash")
                        }

                        Text(isDeletingGroup ? "Deleting Group..." : "Delete Group")
                    }
                }
                .disabled(isDeletingGroup)
                .popover(
                    isPresented: $showDeleteGroupConfirmation,
                    attachmentAnchor: .rect(.bounds),
                    arrowEdge: .bottom
                ) {
                    DeleteGroupPopoverContent(isDeletingGroup: isDeletingGroup) {
                        showDeleteGroupConfirmation = false
                        vm.deleteGroup(groupID: groupID) {
                            dismiss()
                        }
                    }
                    .presentationCompactAdaptation(.popover)
                }
            } else {
                Button(role: .destructive) {
                    showLeaveGroupConfirmation = true
                } label: {
                    HStack(spacing: 12) {
                        if isLeavingGroup {
                            ProgressView()
                                .tint(.red)
                        } else {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                        }

                        Text(isLeavingGroup ? "Leaving Group..." : "Leave Group")
                    }
                }
                .disabled(isLeavingGroup)
                .popover(
                    isPresented: $showLeaveGroupConfirmation,
                    attachmentAnchor: .rect(.bounds),
                    arrowEdge: .bottom
                ) {
                    LeaveGroupPopoverContent(isLeavingGroup: isLeavingGroup) {
                        showLeaveGroupConfirmation = false
                        vm.leaveGroup(groupID: groupID) {
                            dismiss()
                        }
                    }
                    .presentationCompactAdaptation(.popover)
                }
            }
        } header: {
            Text("Danger Zone")
        } footer: {
            Text(
                groupSummary?.isOwner == true
                ? "You can only delete a group after everyone is settled up and nobody owes money."
                : "You can only leave a group after your personal expense balance is settled up."
            )
        }
    }

    private func memberRow(_ member: GroupMember, trailingText: String? = nil) -> some View {
        HStack(spacing: ComponentMetrics.rowSpacing) {
            CircularAvatarView(
                image: nil,
                remoteAvatarURL: member.resolvedAvatarURL,
                size: ComponentMetrics.rowAvatarSize,
                placeholderSystemImage: "person.fill"
            )

            Text(member.username)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)

            Spacer(minLength: 0)

            if let trailingText, !trailingText.isEmpty {
                Text(trailingText)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondary)
                    .lineLimit(1)
            }

            memberAction(member)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func memberAction(_ member: GroupMember) -> some View {
        switch memberFriendStatus(for: member) {
        case .selfMember, .friend:
            EmptyView()
        case .sentPending:
            memberStatusBadge("Requested")
        case .receivedPending:
            memberStatusBadge("Requested You")
        case .canRequest:
            let isSending = vm.sendingDirectFriendRequestIDs.contains(member.id)
            Button {
                vm.sendFriendRequest(
                    toUserID: member.id,
                    username: member.username,
                    avatarVersion: member.avatarVersion
                )
            } label: {
                HStack(spacing: 6) {
                    if isSending {
                        ProgressView()
                            .controlSize(.mini)
                    }
                    Text(isSending ? "Sending..." : "Add")
                }
            }
            .buttonStyle(
                CoListFilledButtonStyle(
                    tone: .butter,
                    horizontalPadding: 12,
                    verticalPadding: 6
                )
            )
            .disabled(isSending)
        }
    }

    private func memberStatusBadge(_ text: String) -> some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(AppTheme.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(AppTheme.surface)
            )
            .overlay(
                Capsule()
                    .stroke(AppTheme.border, lineWidth: 1)
            )
    }

    private enum MemberFriendStatus {
        case selfMember
        case friend
        case sentPending
        case receivedPending
        case canRequest
    }

    private func memberFriendStatus(for member: GroupMember) -> MemberFriendStatus {
        if let currentUserID, member.id == currentUserID {
            return .selfMember
        }

        if friendIDs.contains(member.id) {
            return .friend
        }

        if vm.friendRequests.contains(where: { request in
            request.direction == .sent
                && request.to == member.id
                && request.isPending
        }) {
            return .sentPending
        }

        if vm.friendRequests.contains(where: { request in
            request.direction == .received
                && request.from == member.id
                && request.isPending
        }) {
            return .receivedPending
        }

        return .canRequest
    }

    private func groupActionRow(systemImage: String, title: String, subtitle: String) -> some View {
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

            CoListDisclosureIndicator()
        }
    }

    private func handleSelectedPhoto(_ item: PhotosPickerItem?) {
        guard groupSummary != nil else {
            selectedPhoto = nil
            return
        }

        guard let item else { return }

        Task {
            guard
                let data = try? await item.loadTransferable(type: Data.self),
                let image = UIImage(data: data)
            else {
                await MainActor.run {
                    selectedPhoto = nil
                }
                return
            }

            await MainActor.run {
                pendingAvatarCrop = AvatarCropRequest(image: image)
                selectedPhoto = nil
            }
        }
    }
}

private struct DeleteGroupPopoverContent: View {
    let isDeletingGroup: Bool
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Delete this group?")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)

            Text("Only groups with no outstanding balances can be deleted. This will also remove all todos and expenses in the group.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onDelete) {
                HStack(spacing: 10) {
                    if isDeletingGroup {
                        ProgressView()
                            .tint(.red)
                    }

                    Text(isDeletingGroup ? "Deleting Group..." : "Delete Group")
                        .font(.headline.weight(.semibold))
                }
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AppTheme.background)
                )
            }
            .buttonStyle(.plain)
            .disabled(isDeletingGroup)
        }
        .padding(20)
        .frame(width: 280, alignment: .leading)
        .background(AppTheme.surface)
    }
}

private struct LeaveGroupPopoverContent: View {
    let isLeavingGroup: Bool
    let onLeave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Leave this group?")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)

            Text("You can only leave after your personal balance is settled up. Group owners cannot leave directly.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onLeave) {
                HStack(spacing: 10) {
                    if isLeavingGroup {
                        ProgressView()
                            .tint(.red)
                    }

                    Text(isLeavingGroup ? "Leaving Group..." : "Leave Group")
                        .font(.headline.weight(.semibold))
                }
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AppTheme.background)
                )
            }
            .buttonStyle(.plain)
            .disabled(isLeavingGroup)
        }
        .padding(20)
        .frame(width: 280, alignment: .leading)
        .background(AppTheme.surface)
    }
}

struct EditableGroupAvatarView: View {
    @Binding var avatarImage: UIImage?
    let remoteAvatarURL: URL?
    let isUploading: Bool
    let canEdit: Bool
    @Binding var selectedPhoto: PhotosPickerItem?

    private let avatarSize: CGFloat = 118

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                CircularAvatarView(
                    image: avatarImage,
                    remoteAvatarURL: remoteAvatarURL,
                    size: avatarSize,
                    placeholderSystemImage: "person.3.fill"
                )

                if isUploading {
                    Circle()
                        .fill(AppTheme.surface.opacity(0.92))
                        .frame(width: avatarSize, height: avatarSize)

                    ProgressView()
                }
            }

            if canEdit {
                PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                    AvatarEditBadgeView(size: 34)
                }
                .buttonStyle(.plain)
                .disabled(isUploading)
            }
        }
    }
}
