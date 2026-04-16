import SwiftUI

struct CreateHubSheetView: View {
    enum Destination: String, Identifiable, Hashable {
        case addFriend
        case createExpense
        case createGroup
        case createTodo
        case inviteFriend

        var id: String { rawValue }

        var title: String {
            switch self {
            case .addFriend:
                return "Add Friend"
            case .createExpense:
                return "Add Expense"
            case .createGroup:
                return "Create Group"
            case .createTodo:
                return "Add Todo"
            case .inviteFriend:
                return "Invite Friend"
            }
        }

        var symbol: String {
            switch self {
            case .addFriend:
                return "person.badge.plus"
            case .createExpense:
                return "creditcard.fill"
            case .createGroup:
                return "person.3.sequence.fill"
            case .createTodo:
                return "checklist"
            case .inviteFriend:
                return "envelope.badge.fill"
            }
        }

        var subtitle: String {
            switch self {
            case .addFriend:
                return "Search by email and send a request"
            case .createExpense:
                return "Create a new shared expense"
            case .createGroup:
                return "Start a new group for roommates or trips"
            case .createTodo:
                return "Add a task to one of your groups"
            case .inviteFriend:
                return "Invite an existing friend into a group"
            }
        }
    }

    @EnvironmentObject private var vm: TodoVM
    @Environment(\.dismiss) private var dismiss
    let initialDestination: Destination?
    @State private var selectedDestination: Destination?

    init(initialDestination: Destination? = nil) {
        self.initialDestination = initialDestination
        _selectedDestination = State(initialValue: initialDestination)
    }

    var body: some View {
        NavigationStack {
            if let selectedDestination {
                destinationView(selectedDestination)
            } else {
                actionList
            }
        }
        .task {
            vm.loadGroups()
            vm.prefetchGroupsIfNeeded()
            vm.prefetchFriendsIfNeeded()
        }
    }

    private var actionList: some View {
        List {
            Section {
                Text("Choose what you want to create. All entry points are centralized here.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondary)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            Section("Actions") {
                ForEach(actionOrder, id: \.self) { destination in
                    Button {
                        selectedDestination = destination
                    } label: {
                        CreateHubActionRow(destination: destination)
                    }
                    .buttonStyle(.plain)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                }
            }
        }
        .navigationTitle("Add")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .colistScreenBackground()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }

    private var actionOrder: [Destination] {
        [
            .createExpense,
            .createTodo,
            .addFriend,
            .createGroup,
            .inviteFriend,
        ]
    }

    @ViewBuilder
    private func destinationView(_ destination: Destination) -> some View {
        switch destination {
        case .addFriend:
            AddFriendSheetView(onClose: dismissHub, onSuccess: dismissHub)
        case .createExpense:
            CreateExpenseSheetView(onClose: closeDestination, onSuccess: dismissHub)
        case .createGroup:
            AddGroupSheetView(onClose: closeDestination, onSuccess: dismissHub)
        case .createTodo:
            CreateTodoSheetView(onClose: closeDestination, onSuccess: dismissHub)
        case .inviteFriend:
            InviteFriendSheetView(onClose: closeDestination, onSuccess: dismissHub)
        }
    }

    private func closeDestination() {
        if initialDestination != nil {
            dismissHub()
        } else {
            selectedDestination = nil
        }
    }

    private func dismissHub() {
        dismiss()
    }
}

private struct CreateHubActionRow: View {
    let destination: CreateHubSheetView.Destination

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: destination.symbol)
                .font(.headline)
                .foregroundStyle(AppTheme.primary)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppTheme.primary.opacity(0.10))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(destination.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)

                Text(destination.subtitle)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondary)
            }

            Spacer(minLength: 12)

            CoListDisclosureIndicator()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .colistCard(fill: AppTheme.surface, cornerRadius: ComponentMetrics.largeCardCornerRadius)
    }
}
