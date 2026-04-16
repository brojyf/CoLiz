//
//  TodoView.swift
//  CoList
//
//  Created by 江逸帆 on 2/10/26.
//

import SwiftUI

struct TodoView: View {
    @EnvironmentObject var vm: TodoVM
    @State private var editingTodo: Todo?
    @State private var showCompleted = true
    @State private var searchText = ""
    @State private var isShowingSearch = false
    @State private var isShowingCreateTodoSheet = false
    @FocusState private var isSearchFieldFocused: Bool

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var pendingIDs: [String] {
        filteredPending.map(\.id)
    }

    private var completedIDs: [String] {
        filteredCompleted.map(\.id)
    }

    private var filteredPending: [Todo] {
        guard !trimmedSearchText.isEmpty else { return vm.pending }
        return vm.pending.filter(matchesSearch(_:))
    }

    private var filteredCompleted: [Todo] {
        guard !trimmedSearchText.isEmpty else { return vm.completed }
        return vm.completed.filter(matchesSearch(_:))
    }

    var body: some View {
        List {
            if isShowingSearch {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(AppTheme.secondary)

                        TextField("Search groups or todos", text: $searchText)
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
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            Section {
                if !filteredPending.isEmpty {
                    ForEach(Array(filteredPending.enumerated()), id: \.element.id) { index, todo in
                        todoRow(todo, index: index)
                    }
                } else {
                    emptyTodoCard("No pending todos.")
                }
            } header: {
                Text("Pending")
            }

            Section {
                if showCompleted {
                    if !filteredCompleted.isEmpty {
                        ForEach(Array(filteredCompleted.enumerated()), id: \.element.id) { index, todo in
                            todoRow(todo, index: index + filteredPending.count)
                        }
                    } else {
                        emptyTodoCard("No completed todos.")
                    }
                }
            } header: {
                Button {
                    withAnimation(CoListMotion.sectionToggle) {
                        showCompleted.toggle()
                    }
                } label: {
                    HStack {
                        Text("Completed (\(vm.completed.count))")
                        Spacer()
                        Image(systemName: showCompleted ? "chevron.down" : "chevron.right")
                            .font(.caption.weight(.semibold))
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
        .listSectionSpacing(.compact)
        .contentMargins(.top, 0, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .colistScreenBackground()
        .navigationTitle("Todos")
        .navigationBarTitleDisplayMode(.inline)
        .animation(CoListMotion.sectionToggle, value: isShowingSearch)
        .animation(CoListMotion.sectionToggle, value: showCompleted)
        .animation(CoListMotion.sectionToggle, value: pendingIDs)
        .animation(CoListMotion.sectionToggle, value: completedIDs)
        .task {
            vm.loadTodosIfNeeded()
            vm.prefetchGroupsIfNeeded()
        }
        .refreshable {
            await vm.refreshTodos()
            vm.loadGroups()
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
                Button {
                    isShowingCreateTodoSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $isShowingCreateTodoSheet) {
            NavigationStack {
                CreateTodoSheetView()
            }
        }
        .sheet(item: $editingTodo) { todo in
            NavigationStack {
                EditTodoSheetView(todo: todo) { message in
                    vm.updateTodoMessage(todoID: todo.id, message: message)
                }
            }
        }
    }

    private func animateToggle(id: String) {
        withAnimation(CoListMotion.sectionToggle) {
            vm.toggle(id: id)
        }
    }

    private func groupAvatarURL(for todo: Todo) -> URL? {
        vm.groups.first(where: { $0.id == todo.groupId })?.resolvedAvatarURL
    }

    private func groupName(for todo: Todo) -> String {
        vm.groups.first(where: { $0.id == todo.groupId })?.groupName ?? ""
    }

    private func matchesSearch(_ todo: Todo) -> Bool {
        let keyword = trimmedSearchText
        guard !keyword.isEmpty else { return true }

        return todo.message.localizedCaseInsensitiveContains(keyword)
            || groupName(for: todo).localizedCaseInsensitiveContains(keyword)
            || todo.createdByName.localizedCaseInsensitiveContains(keyword)
    }


    private func todoRow(_ todo: Todo, index: Int) -> some View {
        TodoRowView(
            todo: todo,
            remoteAvatarURL: groupAvatarURL(for: todo),
            subtitle: todoSubtitle(for: todo),
            verticalPadding: 0
        ) {
            animateToggle(id: todo.id)
        }
        .colistReveal(animation: CoListMotion.stagger(at: index), yOffset: 18, startScale: 0.992)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                vm.delete(id: todo.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            
            Button {
                editingTodo = todo
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(AppTheme.secondary)
        }
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
    }

    private func todoSubtitle(for todo: Todo) -> String {
        let group = groupName(for: todo)
        return group
    }

    private func emptyTodoCard(_ message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(AppTheme.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .colistCard(fill: AppTheme.surface, cornerRadius: ComponentMetrics.largeCardCornerRadius)
            .colistReveal(yOffset: 14, startScale: 0.994)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
    }
}

private struct EditTodoSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isMessageFocused: Bool

    let todo: Todo
    let onSave: (String) -> Void

    @State private var draft: String

    init(todo: Todo, onSave: @escaping (String) -> Void) {
        self.todo = todo
        self.onSave = onSave
        _draft = State(initialValue: todo.message)
    }

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        trimmedDraft.count >= 2 && trimmedDraft.count <= 64 && trimmedDraft != todo.message
    }

    var body: some View {
        List {
            Section("Todo") {
                TextField("What needs to get done?", text: $draft, axis: .vertical)
                    .lineLimit(2...5)
                    .focused($isMessageFocused)
                    .textInputAutocapitalization(.sentences)
            }

            Section {
                Text("You can update the todo name here.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Edit Todo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    onSave(trimmedDraft)
                    dismiss()
                }
                .disabled(!canSave)
            }
        }
        .task {
            isMessageFocused = true
        }
    }
}

#Preview {
    let store = DefaultAuthStore()
    let base = BaseClient()
    let refresher = DefaultAuthRefresher(c: base)
    let tp = DefaultTokenProvider(store: store, refresher: refresher)
    let authState = AuthStateStore(tp: tp)
    let c = AuthedClient(base: base, tp: tp)
    let service = TodoService(c: c, tp: tp)
    let presenter = ErrorPresenter()

    NavigationStack {
        TodoView()
    }
    .environmentObject(authState)
    .environmentObject(TodoVM(ep: presenter, s: service))
    .environmentObject(MainTabNavigationState())
}
