import SwiftUI

struct CreateTodoSheetView: View {
    @EnvironmentObject private var vm: TodoVM
    @EnvironmentObject private var navigationState: MainTabNavigationState
    @Environment(\.dismiss) private var dismiss
    var onClose: (() -> Void)? = nil
    var onSuccess: (() -> Void)? = nil

    @State private var selectedGroupID = ""
    @State private var draftMessage = ""
    @State private var groupSearchText = ""

    private var isSelectingGroup: Bool {
        selectedGroupID.isEmpty
    }

    private var selectedGroup: AppGroup? {
        vm.groups.first(where: { $0.id == selectedGroupID })
    }

    private var filteredGroups: [AppGroup] {
        let keyword = groupSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return vm.groups }
        return vm.groups.filter { group in
            group.groupName.localizedCaseInsensitiveContains(keyword)
        }
    }

    private var canCreate: Bool {
        !selectedGroupID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }

    var body: some View {
        Group {
            if isSelectingGroup {
                groupSelectionContent
            } else {
                todoFormContent
            }
        }
        .navigationTitle("Create Todo")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .task {
            vm.loadGroups()
        }
        .onChange(of: vm.groups) { _, _ in
            if let currentGroup = selectedGroup, vm.groups.contains(where: { $0.id == currentGroup.id }) == false {
                selectedGroupID = ""
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(isSelectingGroup ? "Cancel" : "Back") {
                    if isSelectingGroup {
                        closeSheet()
                    } else {
                        selectedGroupID = ""
                        groupSearchText = ""
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if !isSelectingGroup {
                    Button {
                        vm.createTodo(groupID: selectedGroupID, message: draftMessage) {
                            navigationState.openTodoHome()
                            completeSheet()
                        }
                    } label: {
                        Text("Create")
                            .font(.body.weight(.semibold))
                    }
                    .foregroundStyle(AppTheme.primary)
                    .disabled(!canCreate)
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
        if let onSuccess {
            onSuccess()
        } else {
            closeSheet()
        }
    }

    private var groupSelectionContent: some View {
        List {
            Section {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(AppTheme.secondary)

                    TextField("Search groups", text: $groupSearchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                }
                .colistInputField()
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
            }

            if filteredGroups.isEmpty {
                ContentUnavailableView(
                    "No groups found",
                    systemImage: "person.3.sequence.fill",
                    description: Text(groupSearchText.isEmpty ? "Create or join a group first." : "Try another keyword.")
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                ForEach(filteredGroups) { group in
                    Button {
                        selectedGroupID = group.id
                        groupSearchText = ""
                    } label: {
                        GroupRowView(
                            groupName: group.groupName,
                            remoteAvatarURL: group.resolvedAvatarURL,
                            avatarSize: ComponentMetrics.rowAvatarSize,
                            verticalPadding: 0
                        )
                    }
                    .buttonStyle(.plain)
                    .colistCardListRow()
                }
            }
        }
        .listStyle(.plain)
        .listSectionSpacing(.compact)
        .contentMargins(.top, 0, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
    }

    private var todoFormContent: some View {
        Form {
            Section("Group") {
                Button {
                    selectedGroupID = ""
                    groupSearchText = ""
                } label: {
                    if let selectedGroup {
                        GroupRowView(
                            groupName: selectedGroup.groupName,
                            remoteAvatarURL: selectedGroup.resolvedAvatarURL,
                            avatarSize: ComponentMetrics.rowAvatarSize,
                            showsChevron: true
                        )
                    }
                }
                .buttonStyle(.plain)
            }

            Section("Todo") {
                TextField("Write todo...", text: $draftMessage, axis: .vertical)
                    .lineLimit(2...4)
                    .colistInputField()
            }

            if draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).count == 1 {
                Section {
                    Text("Todo message must be at least 2 characters.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.blush)
                }
            }
        }
    }
}
