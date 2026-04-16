//
//  TodoViewModel.swift
//  CoList
//
//  Created by 江逸帆 on 2/14/26.
//

import Foundation
import Combine

final class TodoVM: ObservableObject {
    @Published private(set) var pending: [Todo] = []
    @Published private(set) var completed: [Todo] = []
    @Published private(set) var groupTodosByGroupID: [String: [Todo]] = [:]
    @Published private(set) var groupExpenses: [GroupExpense] = []
    @Published private(set) var groupExpenseHistoryByGroupID: [String: [ExpenseHistoryItem]] = [:]
    @Published private(set) var groupTransactionPlansByGroupID: [String: GroupTransactionPlan] = [:]
    @Published private(set) var expenseDetailsByID: [String: ExpenseDetail] = [:]
    @Published private(set) var groups: [AppGroup] = []
    @Published private(set) var groupDetailsByID: [String: GroupDetail] = [:]
    @Published private(set) var friends: [FriendUser] = []
    @Published private(set) var friendDetailsByID: [String: FriendUser] = [:]
    @Published var friendSearchEmail = ""
    @Published private(set) var isSearchingFriend = false
    @Published private(set) var friendSearchResult: FriendUser?
    @Published private(set) var friendNotFound = false
    @Published private(set) var didSearchFriend = false
    @Published var friendRequestMessage = ""
    @Published private(set) var isCreatingGroup = false
    @Published private(set) var isCreatingExpense = false
    @Published private(set) var isInvitingFriendToGroup = false
    @Published private(set) var isSendingFriendRequest = false
    @Published private(set) var sendingDirectFriendRequestIDs = Set<String>()
    @Published private(set) var friendRequests: [FriendRequest] = []
    @Published private(set) var acceptingFriendRequestIDs = Set<String>()
    @Published private(set) var decliningFriendRequestIDs = Set<String>()
    @Published private(set) var cancellingFriendRequestIDs = Set<String>()
    @Published private(set) var updatingGroupNameIDs = Set<String>()
    @Published private(set) var uploadingGroupAvatarIDs = Set<String>()
    @Published private(set) var loadingGroupDetailIDs = Set<String>()
    @Published private(set) var loadingExpenseDetailIDs = Set<String>()
    @Published private(set) var loadingFriendDetailIDs = Set<String>()
    @Published private(set) var isLoadingGroupExpenses = false
    @Published private(set) var loadingGroupExpenseHistoryIDs = Set<String>()
    @Published private(set) var loadingGroupTransactionPlanIDs = Set<String>()
    @Published private(set) var loadingGroupTodoIDs = Set<String>()
    @Published private(set) var applyingGroupTransactionPlanIDs = Set<String>()
    @Published private(set) var deletingExpenseIDs = Set<String>()
    @Published private(set) var deletingGroupIDs = Set<String>()
    @Published private(set) var leavingGroupIDs = Set<String>()
    @Published private(set) var updatingExpenseIDs = Set<String>()
    
    private let presenter: ErrorPresenter
    private let service: TodoService
    private var bag = Set<AnyCancellable>()
    private var cacheBag = Set<AnyCancellable>()
    private var didLoadFromServer = false
    private var didPrefetchGroupExpenses = false
    private var didPrefetchGroups = false
    private var didPrefetchFriends = false
    private var didPrefetchFriendRequests = false
    private var groupExpensesRequestVersion = 0
    private var markingTodoIDs = Set<String>()
    private var updatingTodoIDs = Set<String>()
    private var deletingTodoIDs = Set<String>()

    private static let expenseAmountLocale = Locale(identifier: "en_US_POSIX")
    private static let expenseAmountFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.generatesDecimalNumbers = true
        return formatter
    }()
    private static let cacheKey = "todo"
    
    init(ep: ErrorPresenter, s: TodoService) {
        presenter = ep
        service = s
        observeCachePersistence()
        hydrateCachedSnapshot()
    }

    private func applyUITestFixturesIfNeeded() -> Bool {
        guard UITestConfig.usesStubData else { return false }

        apply(Todo.mockList())
        groupTodosByGroupID = [:]
        groupExpenses = GroupExpense.mockList()
        groupTransactionPlansByGroupID = [:]
        expenseDetailsByID = [:]
        groups = AppGroup.mockList()
        groupDetailsByID = [:]
        friends = FriendUser.mockList()
        friendDetailsByID = Dictionary(uniqueKeysWithValues: friends.map { ($0.id, $0) })
        friendRequests = FriendRequest.mockList()
        didLoadFromServer = true
        didPrefetchGroupExpenses = true
        didPrefetchGroups = true
        didPrefetchFriends = true
        didPrefetchFriendRequests = true
        return true
    }

    func apply(_ result: [Todo]) {
        pending = result
            .filter { !$0.done }
            .sorted { $0.updatedAt > $1.updatedAt }

        completed = result
            .filter { $0.done }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func toggle(id: String) {
        guard !markingTodoIDs.contains(id) else { return }

        var all = pending + completed
        guard let idx = all.firstIndex(where: { $0.id == id }) else { return }
        let original = all[idx]
        let optimistic = original.toggle()
        all[idx] = optimistic
        apply(all)
        updateGroupTodoCache(with: optimistic)

        markingTodoIDs.insert(id)
        service.markTodo(todoID: id, done: optimistic.done)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.markingTodoIDs.remove(id)

                guard case let .failure(error) = completion else { return }

                var rollback = self.pending + self.completed
                if let rollbackIdx = rollback.firstIndex(where: { $0.id == id }) {
                    rollback[rollbackIdx] = original
                    self.apply(rollback)
                }
                self.updateGroupTodoCache(with: original)
                if let msg = NetworkError.userMessage(from: error) {
                    self.presenter.show(msg)
                }
            } receiveValue: { [weak self] updated in
                guard let self else { return }
                var latest = self.pending + self.completed
                if let latestIdx = latest.firstIndex(where: { $0.id == id }) {
                    latest[latestIdx] = updated
                    self.apply(latest)
                }
                self.updateGroupTodoCache(with: updated)
            }
            .store(in: &bag)
    }

    func delete(id: String) {
        guard !deletingTodoIDs.contains(id) else { return }

        var all = pending + completed
        guard let idx = all.firstIndex(where: { $0.id == id }) else { return }
        let removed = all.remove(at: idx)
        apply(all)
        removeTodoFromGroupCaches(todoID: id)

        deletingTodoIDs.insert(id)
        service.deleteTodo(todoID: id)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.deletingTodoIDs.remove(id)

                guard case let .failure(error) = completion else { return }

                var rollback = self.pending + self.completed
                let restoreIndex = min(idx, rollback.count)
                rollback.insert(removed, at: restoreIndex)
                self.apply(rollback)
                self.updateGroupTodoCache(with: removed)

                if let msg = NetworkError.userMessage(from: error) {
                    self.presenter.show(msg)
                }
            } receiveValue: { _ in }
            .store(in: &bag)
    }

    func updateTodoMessage(todoID: String, message: String) {
        let trimmedTodoID = todoID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTodoID.isEmpty else { return }
        guard trimmedMessage.count >= 2 else {
            presenter.show("Todo message must be at least 2 characters.")
            return
        }
        guard trimmedMessage.count <= 64 else {
            presenter.show("Todo message must be 64 characters or less.")
            return
        }
        guard !updatingTodoIDs.contains(trimmedTodoID) else { return }

        if UITestConfig.usesStubData {
            let original = (pending + completed).first(where: { $0.id == trimmedTodoID })
            let updatedAt = Date()
            replaceTodoLocally(
                Todo(
                    id: trimmedTodoID,
                    groupId: original?.groupId ?? "",
                    message: trimmedMessage,
                    done: original?.done ?? false,
                    createdBy: original?.createdBy ?? "",
                    createdByName: original?.createdByName ?? "",
                    doneBy: original?.doneBy ?? "",
                    updatedAt: updatedAt,
                    createdAt: original?.createdAt ?? updatedAt
                )
            )
            return
        }

        updatingTodoIDs.insert(trimmedTodoID)
        service.updateTodo(todoID: trimmedTodoID, message: trimmedMessage)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.updatingTodoIDs.remove(trimmedTodoID)

                guard case let .failure(error) = completion else { return }
                if let msg = NetworkError.userMessage(from: error) {
                    self.presenter.show(msg)
                }
            } receiveValue: { [weak self] todo in
                self?.replaceTodoLocally(todo)
            }
            .store(in: &bag)
    }

    func loadTodosIfNeeded() {
        if applyUITestFixturesIfNeeded() { return }
        guard !didLoadFromServer else { return }
        didLoadFromServer = true
        loadTodos()
    }

    func loadTodos() {
        if applyUITestFixturesIfNeeded() { return }
        service.getTodos()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                guard case let .failure(error) = completion else { return }
                if let msg = NetworkError.userMessage(from: error) {
                    self.presenter.show(msg)
                }
            } receiveValue: { [weak self] todos in
                self?.apply(todos)
            }
            .store(in: &bag)
    }

    func preloadSignedInDataIfNeeded() {
        if applyUITestFixturesIfNeeded() { return }
        loadTodosIfNeeded()
        prefetchGroupExpensesIfNeeded()
        prefetchGroupsIfNeeded()
        prefetchFriendsIfNeeded()
        prefetchFriendRequestsIfNeeded()
    }

    @MainActor
    func refreshTodos() async {
        if applyUITestFixturesIfNeeded() { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            service.getTodos()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] completion in
                    guard let self else {
                        continuation.resume()
                        return
                    }
                    if case let .failure(error) = completion,
                       let msg = NetworkError.userMessage(from: error) {
                        self.presenter.show(msg)
                    }
                    continuation.resume()
                } receiveValue: { [weak self] todos in
                    self?.apply(todos)
                }
                .store(in: &bag)
        }
    }

    func loadGroups() {
        if applyUITestFixturesIfNeeded() { return }
        service.getGroups()
            .map { $0.sorted { $0.createdAt > $1.createdAt } }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                guard case let .failure(error) = completion else { return }
                if let msg = NetworkError.userMessage(from: error) {
                    self.presenter.show(msg)
                }
            } receiveValue: { [weak self] groups in
                self?.groups = groups
            }
            .store(in: &bag)
    }

    func loadGroupExpenses() {
        if applyUITestFixturesIfNeeded() { return }
        fetchGroupExpenses(force: false, resetPrefetchOnFailure: false)
    }

    func prefetchGroupExpensesIfNeeded() {
        if applyUITestFixturesIfNeeded() { return }
        guard !didPrefetchGroupExpenses else { return }
        guard !isLoadingGroupExpenses else { return }
        didPrefetchGroupExpenses = true
        fetchGroupExpenses(force: false, resetPrefetchOnFailure: true)
    }

    func groupExpense(for groupID: String) -> GroupExpense? {
        groupExpenses.first(where: { $0.id == groupID })
    }

    func groupTodos(for groupID: String) -> [Todo] {
        groupTodosByGroupID[groupID] ?? []
    }

    func groupExpenseHistory(for groupID: String) -> [ExpenseHistoryItem] {
        groupExpenseHistoryByGroupID[groupID] ?? []
    }

    func groupTransactionPlan(for groupID: String) -> GroupTransactionPlan? {
        groupTransactionPlansByGroupID[groupID]
    }

    func expenseDetail(for expenseID: String) -> ExpenseDetail? {
        expenseDetailsByID[expenseID]
    }

    func fetchGroupExpenseHistory(groupID: String) {
        let trimmedGroupID = groupID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedGroupID.isEmpty else { return }

        guard !loadingGroupExpenseHistoryIDs.contains(trimmedGroupID) else { return }
        loadingGroupExpenseHistoryIDs.insert(trimmedGroupID)

        service.getExpenseHistory(groupID: trimmedGroupID)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.loadingGroupExpenseHistoryIDs.remove(trimmedGroupID)
                guard case let .failure(error) = completion else { return }
                if let msg = NetworkError.userMessage(from: error) {
                    self.presenter.show(msg)
                }
            } receiveValue: { [weak self] items in
                self?.groupExpenseHistoryByGroupID[trimmedGroupID] = items
            }
            .store(in: &bag)
    }

    func fetchGroupTransactionPlan(groupID: String, force: Bool = false) {
        let trimmedGroupID = groupID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedGroupID.isEmpty else { return }
        if !force, loadingGroupTransactionPlanIDs.contains(trimmedGroupID) {
            return
        }

        if UITestConfig.usesStubData {
            let groupName = groupExpense(for: trimmedGroupID)?.groupName
                ?? groups.first(where: { $0.id == trimmedGroupID })?.groupName
                ?? "Group"
            groupTransactionPlansByGroupID[trimmedGroupID] = .mock(groupID: trimmedGroupID, groupName: groupName)
            return
        }

        loadingGroupTransactionPlanIDs.insert(trimmedGroupID)
        service.getTransactionPlan(groupID: trimmedGroupID)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.loadingGroupTransactionPlanIDs.remove(trimmedGroupID)
                guard case let .failure(error) = completion else { return }
                if let msg = NetworkError.userMessage(from: error) {
                    self.presenter.show(msg)
                }
            } receiveValue: { [weak self] plan in
                self?.groupTransactionPlansByGroupID[trimmedGroupID] = plan
            }
            .store(in: &bag)
    }

    func applyGroupTransactionPlan(groupID: String, onSuccess: (() -> Void)? = nil) {
        let trimmedGroupID = groupID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedGroupID.isEmpty else { return }
        guard !applyingGroupTransactionPlanIDs.contains(trimmedGroupID) else { return }

        if UITestConfig.usesStubData {
            groupTransactionPlansByGroupID[trimmedGroupID] = GroupTransactionPlan(
                groupID: trimmedGroupID,
                groupName: groupExpense(for: trimmedGroupID)?.groupName
                    ?? groups.first(where: { $0.id == trimmedGroupID })?.groupName
                    ?? "Group",
                groupAvatarVersion: groupExpense(for: trimmedGroupID)?.avatarVersion
                    ?? groups.first(where: { $0.id == trimmedGroupID })?.avatarVersion
                    ?? 0,
                transfers: []
            )
            onSuccess?()
            return
        }

        applyingGroupTransactionPlanIDs.insert(trimmedGroupID)
        service.applyTransactionPlan(groupID: trimmedGroupID)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.applyingGroupTransactionPlanIDs.remove(trimmedGroupID)
                guard case let .failure(error) = completion else { return }
                if let msg = NetworkError.userMessage(from: error) {
                    self.presenter.show(msg)
                }
            } receiveValue: { [weak self] plan in
                guard let self else { return }
                self.groupTransactionPlansByGroupID[trimmedGroupID] = plan
                self.fetchGroupExpenses(force: true, resetPrefetchOnFailure: false)
                self.fetchGroupExpenseHistory(groupID: trimmedGroupID)
                self.fetchGroupTransactionPlan(groupID: trimmedGroupID, force: true)
                onSuccess?()
            }
            .store(in: &bag)
    }

    func fetchGroupTodos(groupID: String, force: Bool = false) {
        let trimmedGroupID = groupID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedGroupID.isEmpty else { return }

        if !force, loadingGroupTodoIDs.contains(trimmedGroupID) {
            return
        }

        if UITestConfig.usesStubData {
            groupTodosByGroupID[trimmedGroupID] = Todo.mockList().enumerated().map { index, todo in
                Todo(
                    id: "\(trimmedGroupID)-mock-\(index)",
                    groupId: trimmedGroupID,
                    message: todo.message,
                    done: todo.done,
                    createdBy: todo.createdBy,
                    createdByName: todo.createdByName,
                    doneBy: todo.doneBy,
                    updatedAt: todo.updatedAt,
                    createdAt: todo.createdAt
                )
            }
            return
        }

        loadingGroupTodoIDs.insert(trimmedGroupID)
        service.getGroupTodos(groupID: trimmedGroupID)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.loadingGroupTodoIDs.remove(trimmedGroupID)
                guard case let .failure(error) = completion else { return }
                if let msg = NetworkError.userMessage(from: error) {
                    self.presenter.show(msg)
                }
            } receiveValue: { [weak self] todos in
                self?.groupTodosByGroupID[trimmedGroupID] = todos
            }
            .store(in: &bag)
    }

    func loadFriends() {
        if applyUITestFixturesIfNeeded() { return }
        service.getFriends()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                guard case let .failure(error) = completion else { return }
                if let msg = NetworkError.userMessage(from: error) {
                    self.presenter.show(msg)
                }
            } receiveValue: { [weak self] friends in
                self?.replaceFriends(with: friends)
            }
            .store(in: &bag)
    }

    func prefetchGroupsIfNeeded() {
        if applyUITestFixturesIfNeeded() { return }
        guard !didPrefetchGroups else { return }
        didPrefetchGroups = true

        service.getGroups()
            .map { $0.sorted { $0.createdAt > $1.createdAt } }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                if case .failure = completion {
                    self.didPrefetchGroups = false
                }
            } receiveValue: { [weak self] groups in
                self?.groups = groups
            }
            .store(in: &bag)
    }

    func groupDetail(for groupID: String) -> GroupDetail? {
        groupDetailsByID[groupID]
    }

    func fetchGroupDetail(groupID: String) {
        let trimmedGroupID = groupID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedGroupID.isEmpty else { return }

        if UITestConfig.usesStubData {
            guard let group = groups.first(where: { $0.id == trimmedGroupID }) else { return }
            groupDetailsByID[trimmedGroupID] = GroupDetail(
                id: group.id,
                groupName: group.groupName,
                avatarVersion: group.avatarVersion,
                ownerId: friends.first?.id ?? "mock-owner-id",
                isOwner: group.isOwner,
                createdAt: group.createdAt,
                members: friends.prefix(2).map {
                    GroupMember(
                        id: $0.id,
                        username: $0.username,
                        email: $0.email,
                        avatarVersion: $0.avatarVersion
                    )
                }
            )
            return
        }

        guard !loadingGroupDetailIDs.contains(trimmedGroupID) else { return }
        loadingGroupDetailIDs.insert(trimmedGroupID)

        service.getGroupDetail(groupID: trimmedGroupID)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.loadingGroupDetailIDs.remove(trimmedGroupID)
                guard case let .failure(error) = completion else { return }
                if self.handleUnavailableGroupDetail(error, groupID: trimmedGroupID) {
                    return
                }
                if let msg = NetworkError.userMessage(from: error) {
                    self.presenter.show(msg)
                }
            } receiveValue: { [weak self] detail in
                guard let self else { return }
                self.groupDetailsByID[trimmedGroupID] = detail
                self.upsertGroup(detail.asAppGroup)
            }
            .store(in: &bag)
    }

    func fetchExpenseDetail(expenseID: String) {
        let trimmedExpenseID = expenseID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedExpenseID.isEmpty else { return }

        if UITestConfig.usesStubData {
            let historyItem = groupExpenseHistoryByGroupID.values
                .flatMap { $0 }
                .first(where: { $0.id == trimmedExpenseID })
            guard let historyItem else { return }
            let groupID = groupExpenses.first(where: { $0.groupName == historyItem.paidByName })?.id
                ?? groupExpenseHistoryByGroupID.first(where: { $0.value.contains(where: { $0.id == trimmedExpenseID }) })?.key
                ?? ""
            expenseDetailsByID[trimmedExpenseID] = ExpenseDetail(
                id: historyItem.id,
                groupID: groupID,
                name: historyItem.name,
                category: historyItem.category,
                categorySymbol: historyItem.categorySymbol,
                amount: historyItem.amount,
                paidBy: historyItem.paidBy,
                splitMethod: "equal",
                note: nil,
                occurredAt: historyItem.occurredAt,
                createdBy: historyItem.createdBy,
                createdAt: historyItem.createdAt,
                updatedAt: historyItem.createdAt,
                participants: []
            )
            return
        }

        guard !loadingExpenseDetailIDs.contains(trimmedExpenseID) else { return }
        loadingExpenseDetailIDs.insert(trimmedExpenseID)

        service.getExpenseDetail(expenseID: trimmedExpenseID)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.loadingExpenseDetailIDs.remove(trimmedExpenseID)
                guard case let .failure(error) = completion else { return }
                if let msg = NetworkError.userMessage(from: error) {
                    self.presenter.show(msg)
                }
            } receiveValue: { [weak self] detail in
                self?.expenseDetailsByID[trimmedExpenseID] = detail
            }
            .store(in: &bag)
    }

    func prefetchFriendsIfNeeded() {
        if applyUITestFixturesIfNeeded() { return }
        guard !didPrefetchFriends else { return }
        didPrefetchFriends = true

        service.getFriends()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                if case .failure = completion {
                    self.didPrefetchFriends = false
                }
            } receiveValue: { [weak self] friends in
                self?.replaceFriends(with: friends)
            }
            .store(in: &bag)
    }

    func friendDetail(for friendID: String) -> FriendUser? {
        if let detail = friendDetailsByID[friendID] {
            return detail
        }
        return friends.first(where: { $0.id == friendID })
    }

    func fetchFriendDetail(friendID: String) {
        let trimmedFriendID = friendID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFriendID.isEmpty else { return }

        if UITestConfig.usesStubData {
            if let friend = friends.first(where: { $0.id == trimmedFriendID }) {
                friendDetailsByID[trimmedFriendID] = friend
            }
            return
        }

        guard !loadingFriendDetailIDs.contains(trimmedFriendID) else { return }
        loadingFriendDetailIDs.insert(trimmedFriendID)

        service.getFriend(userID: trimmedFriendID)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.loadingFriendDetailIDs.remove(trimmedFriendID)
                guard case let .failure(error) = completion else { return }
                if let msg = NetworkError.userMessage(from: error) {
                    self.presenter.show(msg)
                }
            } receiveValue: { [weak self] friend in
                self?.upsertFriend(friend)
            }
            .store(in: &bag)
    }

    func loadFriendRequests() {
        if applyUITestFixturesIfNeeded() { return }
        service.getFriendRequests()
            .map { $0.sorted { $0.createdAt > $1.createdAt } }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                guard case let .failure(error) = completion else { return }
                if let msg = NetworkError.userMessage(from: error) {
                    self.presenter.show(msg)
                }
            } receiveValue: { [weak self] requests in
                self?.friendRequests = requests
            }
            .store(in: &bag)
    }

    @MainActor
    func refreshSocial() async {
        if applyUITestFixturesIfNeeded() { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            var remaining = 4

            func completeOne() {
                remaining -= 1
                if remaining == 0 {
                    continuation.resume()
                }
            }

            service.getGroups()
                .map { $0.sorted { $0.createdAt > $1.createdAt } }
                .receive(on: DispatchQueue.main)
                .sink { [weak self] completion in
                    if let self,
                       case let .failure(error) = completion,
                       let msg = NetworkError.userMessage(from: error) {
                        self.presenter.show(msg)
                    }
                    completeOne()
                } receiveValue: { [weak self] groups in
                    self?.groups = groups
                }
                .store(in: &bag)

            service.getExpenses()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] completion in
                    if let self,
                       case let .failure(error) = completion,
                       let msg = NetworkError.userMessage(from: error) {
                        self.presenter.show(msg)
                    }
                    completeOne()
                } receiveValue: { [weak self] expenses in
                    self?.groupExpenses = expenses
                }
                .store(in: &bag)

            service.getFriends()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] completion in
                    if let self,
                       case let .failure(error) = completion,
                       let msg = NetworkError.userMessage(from: error) {
                        self.presenter.show(msg)
                    }
                    completeOne()
                } receiveValue: { [weak self] friends in
                    self?.replaceFriends(with: friends)
                }
                .store(in: &bag)

            service.getFriendRequests()
                .map { $0.sorted { $0.createdAt > $1.createdAt } }
                .receive(on: DispatchQueue.main)
                .sink { [weak self] completion in
                    if let self,
                       case let .failure(error) = completion,
                       let msg = NetworkError.userMessage(from: error) {
                        self.presenter.show(msg)
                    }
                    completeOne()
                } receiveValue: { [weak self] requests in
                    self?.friendRequests = requests
                }
                .store(in: &bag)
        }
    }

    @MainActor
    func refreshExpenses() async {
        if applyUITestFixturesIfNeeded() { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            service.getExpenses()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] completion in
                    if let self,
                       case let .failure(error) = completion,
                       let msg = NetworkError.userMessage(from: error) {
                        self.presenter.show(msg)
                    }
                    continuation.resume()
                } receiveValue: { [weak self] expenses in
                    self?.groupExpenses = expenses
                }
                .store(in: &bag)
        }
    }

    @MainActor
    func refreshGroupExpenseSummary(groupID: String) async {
        let trimmedGroupID = groupID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedGroupID.isEmpty else { return }
        if applyUITestFixturesIfNeeded() { return }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            var remaining = 3

            func completeOne() {
                remaining -= 1
                if remaining == 0 {
                    continuation.resume()
                }
            }

            service.getExpenses()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] completion in
                    if let self,
                       case let .failure(error) = completion,
                       let msg = NetworkError.userMessage(from: error) {
                        self.presenter.show(msg)
                    }
                    completeOne()
                } receiveValue: { [weak self] expenses in
                    self?.groupExpenses = expenses
                }
                .store(in: &bag)

            service.getExpenseHistory(groupID: trimmedGroupID)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] completion in
                    if let self,
                       case let .failure(error) = completion,
                       let msg = NetworkError.userMessage(from: error) {
                        self.presenter.show(msg)
                    }
                    completeOne()
                } receiveValue: { [weak self] items in
                    self?.groupExpenseHistoryByGroupID[trimmedGroupID] = items
                }
                .store(in: &bag)

            service.getTransactionPlan(groupID: trimmedGroupID)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] completion in
                    if let self,
                       case let .failure(error) = completion,
                       let msg = NetworkError.userMessage(from: error) {
                        self.presenter.show(msg)
                    }
                    completeOne()
                } receiveValue: { [weak self] plan in
                    self?.groupTransactionPlansByGroupID[trimmedGroupID] = plan
                }
                .store(in: &bag)
        }
    }

    func prefetchFriendRequestsIfNeeded() {
        if applyUITestFixturesIfNeeded() { return }
        guard !didPrefetchFriendRequests else { return }
        didPrefetchFriendRequests = true

        service.getFriendRequests()
            .map { $0.sorted { $0.createdAt > $1.createdAt } }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                if case .failure = completion {
                    self.didPrefetchFriendRequests = false
                }
            } receiveValue: { [weak self] requests in
                self?.friendRequests = requests
            }
            .store(in: &bag)
    }

    func refreshCreateContext() {
        if applyUITestFixturesIfNeeded() { return }
        loadTodos()
        loadGroups()
    }

    func createGroup(name: String, onSuccess: ((AppGroup) -> Void)? = nil) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            presenter.show("Please enter group name.")
            return
        }
        guard trimmed.count >= 2 else {
            presenter.show("Group name must be at least 2 characters.")
            return
        }
        guard trimmed.count <= 32 else {
            presenter.show("Group name must be 32 characters or less.")
            return
        }

        if UITestConfig.usesStubData {
            let group = AppGroup(
                id: UUID().uuidString.lowercased(),
                groupName: trimmed,
                avatarVersion: 0,
                isOwner: true,
                createdAt: Date()
            )
            groups.insert(group, at: 0)
            onSuccess?(group)
            return
        }
        guard !isCreatingGroup else { return }

        isCreatingGroup = true
        service.createGroup(groupName: trimmed)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isCreatingGroup = false
                guard case let .failure(error) = completion else { return }
                if let msg = NetworkError.userMessage(from: error) {
                    self.presenter.show(msg)
                }
            } receiveValue: { [weak self] group in
                guard let self else { return }
                self.groups.insert(group, at: 0)
                onSuccess?(group)
            }
            .store(in: &bag)
    }

    func updateGroupName(groupID: String, name: String, onSuccess: (() -> Void)? = nil) {
        let trimmedGroupID = groupID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedGroupID.isEmpty else { return }
        guard !trimmedName.isEmpty else {
            presenter.show("Please enter group name.")
            return
        }
        guard trimmedName.count >= 2 else {
            presenter.show("Group name must be at least 2 characters.")
            return
        }
        guard trimmedName.count <= 32 else {
            presenter.show("Group name must be 32 characters or less.")
            return
        }
        guard !updatingGroupNameIDs.contains(trimmedGroupID) else { return }

        if UITestConfig.usesStubData {
            guard let current = groups.first(where: { $0.id == trimmedGroupID }) else { return }
            upsertGroup(
                AppGroup(
                    id: current.id,
                    groupName: trimmedName,
                    avatarVersion: current.avatarVersion,
                    isOwner: current.isOwner,
                    createdAt: current.createdAt
                )
            )
            onSuccess?()
            return
        }

        updatingGroupNameIDs.insert(trimmedGroupID)
        service.updateGroupName(groupID: trimmedGroupID, groupName: trimmedName)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.updatingGroupNameIDs.remove(trimmedGroupID)
                guard case let .failure(error) = completion else { return }
                if let msg = NetworkError.userMessage(from: error) {
                    self.presenter.show(msg)
                }
            } receiveValue: { [weak self] group in
                guard let self else { return }
                self.upsertGroup(group)
                onSuccess?()
            }
            .store(in: &bag)
    }

    func inviteFriendToGroup(groupID: String, userID: String, onSuccess: (() -> Void)? = nil) {
        let trimmedGroupID = groupID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUserID = userID.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedGroupID.isEmpty else {
            presenter.show("Please choose a group.")
            return
        }
        guard !trimmedUserID.isEmpty else {
            presenter.show("Please choose a friend.")
            return
        }

        if UITestConfig.usesStubData {
            onSuccess?()
            return
        }
        guard !isInvitingFriendToGroup else { return }

        isInvitingFriendToGroup = true
        service.inviteFriendToGroup(groupID: trimmedGroupID, userID: trimmedUserID)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isInvitingFriendToGroup = false
                guard case let .failure(error) = completion else { return }
                if let msg = NetworkError.userMessage(from: error) {
                    self.presenter.show(msg)
                }
            } receiveValue: { [weak self] in
                guard let self else { return }
                self.loadGroups()
                onSuccess?()
            }
            .store(in: &bag)
    }

    func inviteFriendsToGroup(groupID: String, userIDs: [String], onSuccess: (() -> Void)? = nil) {
        let trimmedGroupID = groupID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUserIDs = userIDs.reduce(into: [String]()) { result, userID in
            let trimmedUserID = userID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedUserID.isEmpty, !result.contains(trimmedUserID) else { return }
            result.append(trimmedUserID)
        }

        guard !trimmedGroupID.isEmpty else {
            presenter.show("Please choose a group.")
            return
        }
        guard !trimmedUserIDs.isEmpty else {
            presenter.show("Please choose at least one friend.")
            return
        }

        if UITestConfig.usesStubData {
            onSuccess?()
            return
        }
        guard !isInvitingFriendToGroup else { return }

        isInvitingFriendToGroup = true
        inviteFriendsSequentially(
            groupID: trimmedGroupID,
            userIDs: trimmedUserIDs,
            currentIndex: 0,
            completedAny: false,
            onSuccess: onSuccess
        )
    }

    private func inviteFriendsSequentially(
        groupID: String,
        userIDs: [String],
        currentIndex: Int,
        completedAny: Bool,
        onSuccess: (() -> Void)?
    ) {
        guard currentIndex < userIDs.count else {
            isInvitingFriendToGroup = false
            loadGroups()
            onSuccess?()
            return
        }

        service.inviteFriendToGroup(groupID: groupID, userID: userIDs[currentIndex])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                guard case let .failure(error) = completion else { return }
                self.isInvitingFriendToGroup = false
                if completedAny {
                    self.loadGroups()
                }
                if let msg = NetworkError.userMessage(from: error) {
                    self.presenter.show(msg)
                }
            } receiveValue: { [weak self] in
                guard let self else { return }
                self.inviteFriendsSequentially(
                    groupID: groupID,
                    userIDs: userIDs,
                    currentIndex: currentIndex + 1,
                    completedAny: true,
                    onSuccess: onSuccess
                )
            }
            .store(in: &bag)
    }

    func deleteGroup(groupID: String, onSuccess: (() -> Void)? = nil) {
        let trimmedGroupID = groupID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedGroupID.isEmpty else { return }

        if UITestConfig.usesStubData {
            removeGroupLocally(groupID: trimmedGroupID)
            onSuccess?()
            return
        }

        guard !deletingGroupIDs.contains(trimmedGroupID) else { return }
        deletingGroupIDs.insert(trimmedGroupID)

        service.deleteGroup(groupID: trimmedGroupID)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.deletingGroupIDs.remove(trimmedGroupID)
                guard case let .failure(error) = completion else { return }
                if let msg = NetworkError.userMessage(from: error) {
                    self.presenter.show(msg)
                }
            } receiveValue: { [weak self] in
                guard let self else { return }
                self.removeGroupLocally(groupID: trimmedGroupID)
                onSuccess?()
            }
            .store(in: &bag)
    }

    func leaveGroup(groupID: String, onSuccess: (() -> Void)? = nil) {
        let trimmedGroupID = groupID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedGroupID.isEmpty else { return }

        if UITestConfig.usesStubData {
            removeGroupLocally(groupID: trimmedGroupID)
            onSuccess?()
            return
        }

        guard !leavingGroupIDs.contains(trimmedGroupID) else { return }
        leavingGroupIDs.insert(trimmedGroupID)

        service.leaveGroup(groupID: trimmedGroupID)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.leavingGroupIDs.remove(trimmedGroupID)
                guard case let .failure(error) = completion else { return }
                if let msg = NetworkError.userMessage(from: error) {
                    self.presenter.show(msg)
                }
            } receiveValue: { [weak self] in
                guard let self else { return }
                self.removeGroupLocally(groupID: trimmedGroupID)
                onSuccess?()
            }
            .store(in: &bag)
    }

    func createTodo(groupID: String, message: String, onSuccess: (() -> Void)? = nil) {
        if applyUITestFixturesIfNeeded() {
            let todo = Todo(
                id: UUID().uuidString.lowercased(),
                groupId: groupID.trimmingCharacters(in: .whitespacesAndNewlines),
                message: message.trimmingCharacters(in: .whitespacesAndNewlines),
                done: false,
                createdBy: "UI Test",
                createdByName: "UI Test",
                doneBy: "",
                updatedAt: Date(),
                createdAt: Date()
            )
            var all = pending + completed
            all.append(todo)
            apply(all)
            updateGroupTodoCache(with: todo, insertAtFront: true)
            onSuccess?()
            return
        }
        let groupID = groupID.trimmingCharacters(in: .whitespacesAndNewlines)
        let message = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !groupID.isEmpty else {
            presenter.show("Please enter group id.")
            return
        }
        guard message.count >= 2 else {
            presenter.show("Todo message must be at least 2 characters.")
            return
        }

        service.createTodo(groupID: groupID, message: message)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                guard case let .failure(error) = completion else { return }
                if let msg = NetworkError.userMessage(from: error) {
                    self.presenter.show(msg)
                }
            } receiveValue: { [weak self] todo in
                guard let self else { return }
                var all = self.pending + self.completed
                all.append(todo)
                self.apply(all)
                self.updateGroupTodoCache(with: todo, insertAtFront: true)
                onSuccess?()
            }
            .store(in: &bag)
    }

    func createExpense(
        groupID: String,
        request: CreateExpenseRequest,
        onSuccess: (() -> Void)? = nil
    ) {
        let trimmedGroupID = groupID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = request.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCategory = request.category.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPaidBy = request.paidBy.trimmingCharacters(in: .whitespacesAndNewlines)
        let orderedParticipants = request.participants.map {
            $0.userID.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let uniqueParticipants = Array(NSOrderedSet(array: orderedParticipants)) as? [String] ?? orderedParticipants

        guard !trimmedGroupID.isEmpty else {
            presenter.show("Please choose a group.")
            return
        }
        guard !trimmedName.isEmpty else {
            presenter.show("Please enter an expense name.")
            return
        }
        guard ExpenseCategory(rawValue: trimmedCategory) != nil else {
            presenter.show("Please choose an expense category.")
            return
        }
        guard trimmedName.count <= 32 else {
            presenter.show("Expense name must be 32 characters or less.")
            return
        }
        guard let normalizedAmount = Self.normalizedExpenseAmount(request.amount) else {
            presenter.show("Please enter a valid amount.")
            return
        }
        guard !trimmedPaidBy.isEmpty else {
            presenter.show("Please choose who paid.")
            return
        }
        guard !uniqueParticipants.isEmpty else {
            presenter.show("Please choose at least one participant.")
            return
        }
        if let trimmedNote = request.note?.trimmingCharacters(in: .whitespacesAndNewlines),
           trimmedNote.count > 64 {
            presenter.show("Note must be 64 characters or less.")
            return
        }
        guard ["equal", "percentage", "fixed"].contains(request.splitMethod) else {
            presenter.show("Unsupported split method.")
            return
        }
        if trimmedCategory == ExpenseCategory.transaction.rawValue && request.splitMethod != "fixed" {
            presenter.show("Transaction must use exact recipient amounts.")
            return
        }
        if trimmedCategory == ExpenseCategory.transaction.rawValue && uniqueParticipants.contains(trimmedPaidBy) {
            presenter.show("Transaction recipients cannot include the payer.")
            return
        }

        if let members = groupDetail(for: trimmedGroupID)?.members {
            let memberIDs = Set(members.map(\.id))
            guard memberIDs.contains(trimmedPaidBy) else {
                presenter.show("Selected payer is not in this group.")
                return
            }
            guard uniqueParticipants.allSatisfy(memberIDs.contains) else {
                presenter.show("Some selected participants are not in this group.")
                return
            }
        }

        if UITestConfig.usesStubData {
            if let group = groups.first(where: { $0.id == trimmedGroupID }) {
                let summary = GroupExpense(
                    id: group.id,
                    groupName: group.groupName,
                    avatarVersion: group.avatarVersion,
                    lentAmount: "0.00",
                    borrowAmount: "0.00"
                )
                if let index = groupExpenses.firstIndex(where: { $0.id == group.id }) {
                    groupExpenses[index] = summary
                } else {
                    groupExpenses.insert(summary, at: 0)
                }
            }
            onSuccess?()
            return
        }

        guard !isCreatingExpense else { return }

        isCreatingExpense = true
        service.createExpense(
            groupID: trimmedGroupID,
            request: CreateExpenseRequest(
                name: trimmedName,
                category: trimmedCategory,
                amount: normalizedAmount,
                paidBy: trimmedPaidBy,
                splitMethod: request.splitMethod,
                note: request.note?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                occurredAt: request.occurredAt,
                participants: request.participants.compactMap { participant in
                    let trimmedUserID = participant.userID.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard uniqueParticipants.contains(trimmedUserID) else { return nil }
                    return ExpenseParticipantInput(
                        userID: trimmedUserID,
                        percentage: participant.percentage?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                        fixedAmount: participant.fixedAmount?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                    )
                }
            )
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] completion in
            guard let self else { return }
            self.isCreatingExpense = false
            guard case let .failure(error) = completion else { return }
            if let msg = NetworkError.userMessage(from: error) {
                self.presenter.show(msg)
            }
        } receiveValue: { [weak self] _ in
            guard let self else { return }
            self.fetchGroupExpenseHistory(groupID: trimmedGroupID)
            self.fetchGroupExpenses(force: true, resetPrefetchOnFailure: false)
            self.fetchGroupTransactionPlan(groupID: trimmedGroupID, force: true)
            onSuccess?()
        }
        .store(in: &bag)
    }

    func updateExpense(
        expenseID: String,
        groupID: String,
        request: CreateExpenseRequest,
        onSuccess: (() -> Void)? = nil
    ) {
        let trimmedExpenseID = expenseID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedGroupID = groupID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = request.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCategory = request.category.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPaidBy = request.paidBy.trimmingCharacters(in: .whitespacesAndNewlines)
        let orderedParticipants = request.participants.map {
            $0.userID.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let uniqueParticipants = Array(NSOrderedSet(array: orderedParticipants)) as? [String] ?? orderedParticipants

        guard !trimmedExpenseID.isEmpty else { return }
        guard !trimmedGroupID.isEmpty else { return }
        guard !trimmedName.isEmpty else {
            presenter.show("Please enter an expense name.")
            return
        }
        guard ExpenseCategory(rawValue: trimmedCategory) != nil else {
            presenter.show("Please choose an expense category.")
            return
        }
        guard trimmedName.count <= 32 else {
            presenter.show("Expense name must be 32 characters or less.")
            return
        }
        guard let normalizedAmount = Self.normalizedExpenseAmount(request.amount) else {
            presenter.show("Please enter a valid amount.")
            return
        }
        guard !trimmedPaidBy.isEmpty else {
            presenter.show("Please choose who paid.")
            return
        }
        guard !uniqueParticipants.isEmpty else {
            presenter.show("Please choose at least one participant.")
            return
        }
        if let trimmedNote = request.note?.trimmingCharacters(in: .whitespacesAndNewlines),
           trimmedNote.count > 64 {
            presenter.show("Note must be 64 characters or less.")
            return
        }
        guard ["equal", "percentage", "fixed"].contains(request.splitMethod) else {
            presenter.show("Unsupported split method.")
            return
        }
        if trimmedCategory == ExpenseCategory.transaction.rawValue && request.splitMethod != "fixed" {
            presenter.show("Transaction must use exact recipient amounts.")
            return
        }
        if trimmedCategory == ExpenseCategory.transaction.rawValue && uniqueParticipants.contains(trimmedPaidBy) {
            presenter.show("Transaction recipients cannot include the payer.")
            return
        }

        if let members = groupDetail(for: trimmedGroupID)?.members {
            let memberIDs = Set(members.map(\.id))
            guard memberIDs.contains(trimmedPaidBy) else {
                presenter.show("Selected payer is not in this group.")
                return
            }
            guard uniqueParticipants.allSatisfy(memberIDs.contains) else {
                presenter.show("Some selected participants are not in this group.")
                return
            }
        }

        guard !updatingExpenseIDs.contains(trimmedExpenseID) else { return }

        if UITestConfig.usesStubData {
            onSuccess?()
            return
        }

        updatingExpenseIDs.insert(trimmedExpenseID)
        service.updateExpense(
            expenseID: trimmedExpenseID,
            request: CreateExpenseRequest(
                name: trimmedName,
                category: trimmedCategory,
                amount: normalizedAmount,
                paidBy: trimmedPaidBy,
                splitMethod: request.splitMethod,
                note: request.note?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                occurredAt: request.occurredAt,
                participants: request.participants.compactMap { participant in
                    let trimmedUserID = participant.userID.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard uniqueParticipants.contains(trimmedUserID) else { return nil }
                    return ExpenseParticipantInput(
                        userID: trimmedUserID,
                        percentage: participant.percentage?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                        fixedAmount: participant.fixedAmount?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                    )
                }
            )
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] completion in
            guard let self else { return }
            self.updatingExpenseIDs.remove(trimmedExpenseID)
            guard case let .failure(error) = completion else { return }
            if let msg = NetworkError.userMessage(from: error) {
                self.presenter.show(msg)
            }
        } receiveValue: { [weak self] detail in
            guard let self else { return }
            self.expenseDetailsByID[trimmedExpenseID] = detail
            self.fetchGroupExpenseHistory(groupID: trimmedGroupID)
            self.fetchGroupExpenses(force: true, resetPrefetchOnFailure: false)
            self.fetchGroupTransactionPlan(groupID: trimmedGroupID, force: true)
            onSuccess?()
        }
        .store(in: &bag)
    }

    func deleteExpense(groupID: String, expenseID: String) {
        let trimmedGroupID = groupID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedExpenseID = expenseID.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedGroupID.isEmpty else { return }
        guard !trimmedExpenseID.isEmpty else { return }
        guard !deletingExpenseIDs.contains(trimmedExpenseID) else { return }

        let originalHistory = groupExpenseHistoryByGroupID[trimmedGroupID] ?? []
        guard let removedIndex = originalHistory.firstIndex(where: { $0.id == trimmedExpenseID }) else {
            return
        }

        var updatedHistory = originalHistory
        let removedExpense = updatedHistory.remove(at: removedIndex)
        groupExpenseHistoryByGroupID[trimmedGroupID] = updatedHistory

        if UITestConfig.usesStubData {
            if updatedHistory.isEmpty {
                groupExpenses.removeAll { $0.id == trimmedGroupID }
            }
            return
        }

        deletingExpenseIDs.insert(trimmedExpenseID)
        service.deleteExpense(expenseID: trimmedExpenseID)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.deletingExpenseIDs.remove(trimmedExpenseID)

                guard case let .failure(error) = completion else { return }

                var rollback = self.groupExpenseHistoryByGroupID[trimmedGroupID] ?? []
                let restoreIndex = min(removedIndex, rollback.count)
                rollback.insert(removedExpense, at: restoreIndex)
                self.groupExpenseHistoryByGroupID[trimmedGroupID] = rollback

                if let msg = NetworkError.userMessage(from: error) {
                    self.presenter.show(msg)
                }
            } receiveValue: { [weak self] in
                guard let self else { return }
                self.fetchGroupExpenses(force: true, resetPrefetchOnFailure: false)
                self.fetchGroupTransactionPlan(groupID: trimmedGroupID, force: true)
            }
            .store(in: &bag)
    }

    func resetFriendSearchState() {
        friendSearchEmail = ""
        friendRequestMessage = ""
        isSearchingFriend = false
        isSendingFriendRequest = false
        decliningFriendRequestIDs = []
        cancellingFriendRequestIDs = []
        friendSearchResult = nil
        friendNotFound = false
        didSearchFriend = false
    }

    func searchFriendByEmail() {
        if UITestConfig.usesStubData {
            let email = friendSearchEmail.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !email.isEmpty else {
                presenter.show("Please enter your friend's email.")
                return
            }
            didSearchFriend = true
            friendNotFound = false
            friendSearchResult = FriendUser(
                username: "UITest Friend",
                id: "ui-friend-1",
                email: email,
                avatarVersion: 0,
                friendSince: nil,
                mutualGroups: nil
            )
            return
        }
        guard !isSearchingFriend else { return }

        let email = friendSearchEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else {
            presenter.show("Please enter your friend's email.")
            return
        }

        didSearchFriend = true
        friendNotFound = false
        friendSearchResult = nil
        isSearchingFriend = true

        service.searchFriendByEmail(email: email)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isSearchingFriend = false
                guard case let .failure(error) = completion else { return }

                if case let .apiError(_, code, _, _, _) = error, code == 404 {
                    self.friendNotFound = true
                    return
                }
                if let msg = NetworkError.userMessage(from: error) {
                    self.presenter.show(msg)
                }
            } receiveValue: { [weak self] friend in
                guard let self else { return }
                self.friendNotFound = false
                self.friendSearchResult = friend
            }
            .store(in: &bag)
    }

    func sendFriendRequest(onSuccess: (() -> Void)? = nil) {
        if UITestConfig.usesStubData {
            guard let user = friendSearchResult else {
                presenter.show("Please search and choose a friend first.")
                return
            }
            let trimmedMessage = friendRequestMessage.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedMessage.isEmpty else {
                presenter.show("Please enter a message.")
                return
            }
            let request = FriendRequest(
                id: UUID().uuidString.lowercased(),
                from: "mock-user-id",
                fromUsername: "Me",
                fromAvatarVersion: 0,
                to: user.id,
                toUsername: user.username,
                toAvatarVersion: user.avatarVersion,
                msg: trimmedMessage,
                status: "pending",
                createdAt: Date(),
                direction: .sent
            )
            friendRequests.insert(request, at: 0)
            resetFriendSearchState()
            onSuccess?()
            return
        }
        guard !isSendingFriendRequest else { return }
        guard let user = friendSearchResult else {
            presenter.show("Please search and choose a friend first.")
            return
        }

        let trimmedMessage = friendRequestMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else {
            presenter.show("Please enter a message.")
            return
        }
        guard trimmedMessage.count <= 64 else {
            presenter.show("Message must be 64 characters or less.")
            return
        }

        isSendingFriendRequest = true
        service.sendFriendRequest(
            toUserID: user.id,
            message: trimmedMessage
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] completion in
            guard let self else { return }
            self.isSendingFriendRequest = false
            guard case let .failure(error) = completion else { return }
            if let msg = NetworkError.userMessage(from: error) {
                self.presenter.show(msg)
            }
        } receiveValue: { [weak self] in
            guard let self else { return }
            self.resetFriendSearchState()
            self.loadFriendRequests()
            onSuccess?()
        }
        .store(in: &bag)
    }

    func sendFriendRequest(
        toUserID userID: String,
        username: String? = nil,
        avatarVersion: UInt32? = nil,
        message: String = "Hi, let's connect on CoList.",
        onSuccess: (() -> Void)? = nil
    ) {
        let trimmedUserID = userID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedUserID.isEmpty else { return }
        guard !trimmedMessage.isEmpty else {
            presenter.show("Please enter a message.")
            return
        }
        guard trimmedMessage.count <= 64 else {
            presenter.show("Message must be 64 characters or less.")
            return
        }
        guard !sendingDirectFriendRequestIDs.contains(trimmedUserID) else { return }

        if UITestConfig.usesStubData {
            let request = FriendRequest(
                id: UUID().uuidString.lowercased(),
                from: "mock-user-id",
                fromUsername: "Me",
                fromAvatarVersion: 0,
                to: trimmedUserID,
                toUsername: username,
                toAvatarVersion: avatarVersion,
                msg: trimmedMessage,
                status: "pending",
                createdAt: Date(),
                direction: .sent
            )
            friendRequests.insert(request, at: 0)
            onSuccess?()
            return
        }

        sendingDirectFriendRequestIDs.insert(trimmedUserID)
        service.sendFriendRequest(toUserID: trimmedUserID, message: trimmedMessage)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.sendingDirectFriendRequestIDs.remove(trimmedUserID)
                guard case let .failure(error) = completion else { return }
                if let msg = NetworkError.userMessage(from: error) {
                    self.presenter.show(msg)
                }
            } receiveValue: { [weak self] in
                guard let self else { return }
                self.loadFriendRequests()
                onSuccess?()
            }
            .store(in: &bag)
    }

    func acceptFriendRequest(requestID: String) {
        if UITestConfig.usesStubData {
            guard let acceptedRequest = friendRequests.first(where: { $0.id == requestID }) else { return }
            friendRequests = friendRequests.map { request in
                guard request.id == requestID else { return request }
                return acceptedRequestSettingStatus(request, status: "accepted")
            }
            if let optimisticFriend = optimisticFriend(from: acceptedRequest) {
                upsertFriend(optimisticFriend)
            }
            return
        }
        guard !acceptingFriendRequestIDs.contains(requestID) else { return }
        let request = friendRequests.first(where: { $0.id == requestID })
        acceptingFriendRequestIDs.insert(requestID)

        service.acceptFriendRequest(requestID: requestID)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.acceptingFriendRequestIDs.remove(requestID)
                guard case let .failure(error) = completion else { return }
                if let msg = NetworkError.userMessage(from: error) {
                    self.presenter.show(msg)
                }
            } receiveValue: { [weak self] in
                guard let self else { return }
                if let request, let optimisticFriend = self.optimisticFriend(from: request) {
                    self.upsertFriend(optimisticFriend)
                }
                self.loadFriends()
                self.loadFriendRequests()
            }
            .store(in: &bag)
    }

    func declineFriendRequest(requestID: String) {
        if UITestConfig.usesStubData {
            friendRequests = friendRequests.map { request in
                guard request.id == requestID else { return request }
                return FriendRequest(
                    id: request.id,
                    from: request.from,
                    fromUsername: request.fromUsername,
                    fromAvatarVersion: request.fromAvatarVersion,
                    to: request.to,
                    toUsername: request.toUsername,
                    toAvatarVersion: request.toAvatarVersion,
                    msg: request.msg,
                    status: "rejected",
                    createdAt: request.createdAt,
                    direction: request.direction
                )
            }
            return
        }
        guard !decliningFriendRequestIDs.contains(requestID) else { return }
        decliningFriendRequestIDs.insert(requestID)

        service.declineFriendRequest(requestID: requestID)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.decliningFriendRequestIDs.remove(requestID)
                guard case let .failure(error) = completion else { return }
                if let msg = NetworkError.userMessage(from: error) {
                    self.presenter.show(msg)
                }
            } receiveValue: { [weak self] in
                self?.loadFriendRequests()
            }
            .store(in: &bag)
    }

    func cancelFriendRequest(requestID: String) {
        if UITestConfig.usesStubData {
            friendRequests = friendRequests.map { request in
                guard request.id == requestID else { return request }
                return FriendRequest(
                    id: request.id,
                    from: request.from,
                    fromUsername: request.fromUsername,
                    fromAvatarVersion: request.fromAvatarVersion,
                    to: request.to,
                    toUsername: request.toUsername,
                    toAvatarVersion: request.toAvatarVersion,
                    msg: request.msg,
                    status: "rejected",
                    createdAt: request.createdAt,
                    direction: request.direction
                )
            }
            return
        }
        guard !cancellingFriendRequestIDs.contains(requestID) else { return }
        cancellingFriendRequestIDs.insert(requestID)

        service.cancelFriendRequest(requestID: requestID)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.cancellingFriendRequestIDs.remove(requestID)
                guard case let .failure(error) = completion else { return }
                if let msg = NetworkError.userMessage(from: error) {
                    self.presenter.show(msg)
                }
            } receiveValue: { [weak self] in
                self?.loadFriendRequests()
            }
            .store(in: &bag)
    }

    func uploadGroupAvatar(groupID: String, data: Data) {
        let trimmedGroupID = groupID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedGroupID.isEmpty else { return }

        if UITestConfig.usesStubData {
            guard let index = groups.firstIndex(where: { $0.id == trimmedGroupID }) else { return }
            let current = groups[index]
            groups[index] = AppGroup(
                id: current.id,
                groupName: current.groupName,
                avatarVersion: current.avatarVersion + 1,
                isOwner: current.isOwner,
                createdAt: current.createdAt
            )
            if let detail = groupDetailsByID[trimmedGroupID] {
                groupDetailsByID[trimmedGroupID] = GroupDetail(
                    id: detail.id,
                    groupName: detail.groupName,
                    avatarVersion: detail.avatarVersion + 1,
                    ownerId: detail.ownerId,
                    isOwner: detail.isOwner,
                    createdAt: detail.createdAt,
                    members: detail.members
                )
            }
            return
        }

        guard !uploadingGroupAvatarIDs.contains(trimmedGroupID) else { return }
        uploadingGroupAvatarIDs.insert(trimmedGroupID)

        Task { [weak self] in
            guard let self else { return }
            do {
                let updatedGroup = try await service.uploadGroupAvatar(groupID: trimmedGroupID, data: data)
                await MainActor.run {
                    self.upsertGroup(updatedGroup)
                    self.uploadingGroupAvatarIDs.remove(trimmedGroupID)
                }
            } catch {
                await MainActor.run {
                    self.uploadingGroupAvatarIDs.remove(trimmedGroupID)
                    if let msg = NetworkError.userMessage(from: NetworkError.map(error)) {
                        self.presenter.show(msg)
                    }
                }
            }
        }
    }

    func resetOnSignOut() {
        bag.removeAll()

        pending = []
        completed = []
        groupTodosByGroupID = [:]
        groupExpenses = []
        groupExpenseHistoryByGroupID = [:]
        groupTransactionPlansByGroupID = [:]
        expenseDetailsByID = [:]
        groups = []
        groupDetailsByID = [:]
        friends = []
        friendDetailsByID = [:]
        friendSearchEmail = ""
        isSearchingFriend = false
        friendSearchResult = nil
        friendNotFound = false
        didSearchFriend = false
        friendRequestMessage = ""
        isCreatingGroup = false
        isCreatingExpense = false
        isInvitingFriendToGroup = false
        isSendingFriendRequest = false
        sendingDirectFriendRequestIDs = []
        friendRequests = []
        acceptingFriendRequestIDs = []
        decliningFriendRequestIDs = []
        cancellingFriendRequestIDs = []
        updatingGroupNameIDs = []
        uploadingGroupAvatarIDs = []
        loadingGroupDetailIDs = []
        loadingExpenseDetailIDs = []
        loadingFriendDetailIDs = []
        isLoadingGroupExpenses = false
        loadingGroupExpenseHistoryIDs = []
        loadingGroupTransactionPlanIDs = []
        loadingGroupTodoIDs = []
        applyingGroupTransactionPlanIDs = []
        deletingExpenseIDs = []
        deletingGroupIDs = []
        leavingGroupIDs = []
        updatingExpenseIDs = []

        didLoadFromServer = false
        didPrefetchGroupExpenses = false
        didPrefetchGroups = false
        didPrefetchFriends = false
        didPrefetchFriendRequests = false
        markingTodoIDs.removeAll()
        updatingTodoIDs.removeAll()
        deletingTodoIDs.removeAll()
        clearCache()
    }

    private func upsertGroup(_ group: AppGroup) {
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index] = group
        } else {
            groups.insert(group, at: 0)
        }

        if let detail = groupDetailsByID[group.id] {
            groupDetailsByID[group.id] = GroupDetail(
                id: detail.id,
                groupName: group.groupName,
                avatarVersion: group.avatarVersion,
                ownerId: detail.ownerId,
                isOwner: group.isOwner,
                createdAt: group.createdAt,
                members: detail.members
            )
        }

        if let index = groupExpenses.firstIndex(where: { $0.id == group.id }) {
            let current = groupExpenses[index]
            groupExpenses[index] = GroupExpense(
                id: current.id,
                groupName: group.groupName,
                avatarVersion: group.avatarVersion,
                lentAmount: current.lentAmount,
                borrowAmount: current.borrowAmount
            )
        }
    }

    private func upsertFriend(_ friend: FriendUser) {
        let merged = mergedFriend(summary: friend, existing: friendDetailsByID[friend.id])
        friendDetailsByID[friend.id] = merged

        if let index = friends.firstIndex(where: { $0.id == friend.id }) {
            friends[index] = merged
        } else {
            friends.append(merged)
            friends.sort { $0.username.localizedCaseInsensitiveCompare($1.username) == .orderedAscending }
        }
    }

    private func replaceFriends(with friends: [FriendUser]) {
        self.friends = friends.map { friend in
            let merged = mergedFriend(summary: friend, existing: friendDetailsByID[friend.id])
            friendDetailsByID[friend.id] = merged
            return merged
        }
    }

    private func fetchGroupExpenses(force: Bool, resetPrefetchOnFailure: Bool) {
        if !force {
            guard !isLoadingGroupExpenses else { return }
        }
        groupExpensesRequestVersion += 1
        let requestVersion = groupExpensesRequestVersion
        isLoadingGroupExpenses = true

        service.getExpenses()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                guard requestVersion == self.groupExpensesRequestVersion else { return }
                self.isLoadingGroupExpenses = false
                guard case let .failure(error) = completion else { return }
                if resetPrefetchOnFailure {
                    self.didPrefetchGroupExpenses = false
                }
                if let msg = NetworkError.userMessage(from: error) {
                    self.presenter.show(msg)
                }
            } receiveValue: { [weak self] expenses in
                guard let self, requestVersion == self.groupExpensesRequestVersion else { return }
                self.groupExpenses = expenses
            }
            .store(in: &bag)
    }

    private func handleUnavailableGroupDetail(_ error: NetworkError, groupID: String) -> Bool {
        switch error {
        case let .apiError(_, code, _, _, _), let .httpError(_, code, _, _):
            guard code == 401 || code == 404 else { return false }
            let shouldPresentUnavailableMessage = hasLocalGroupState(groupID: groupID)
            removeGroupLocally(groupID: groupID)
            if shouldPresentUnavailableMessage {
                presenter.show("This group is no longer available.")
            }
            return true
        default:
            return false
        }
    }

    private func hasLocalGroupState(groupID: String) -> Bool {
        groups.contains { $0.id == groupID }
            || groupDetailsByID[groupID] != nil
            || groupTodosByGroupID[groupID] != nil
            || groupExpenseHistoryByGroupID[groupID] != nil
            || groupTransactionPlansByGroupID[groupID] != nil
            || groupExpenses.contains { $0.id == groupID }
    }

    private func removeGroupLocally(groupID: String) {
        pending.removeAll { $0.groupId == groupID }
        completed.removeAll { $0.groupId == groupID }
        groups.removeAll { $0.id == groupID }
        groupDetailsByID.removeValue(forKey: groupID)
        groupTodosByGroupID.removeValue(forKey: groupID)
        groupExpenseHistoryByGroupID.removeValue(forKey: groupID)
        groupTransactionPlansByGroupID.removeValue(forKey: groupID)
        groupExpenses.removeAll { $0.id == groupID }
        loadingGroupDetailIDs.remove(groupID)
        loadingGroupExpenseHistoryIDs.remove(groupID)
        loadingGroupTransactionPlanIDs.remove(groupID)
        loadingGroupTodoIDs.remove(groupID)
        applyingGroupTransactionPlanIDs.remove(groupID)
        uploadingGroupAvatarIDs.remove(groupID)
        deletingGroupIDs.remove(groupID)
        leavingGroupIDs.remove(groupID)
    }

    private func updateGroupTodoCache(with todo: Todo, insertAtFront: Bool = false) {
        guard groupTodosByGroupID[todo.groupId] != nil else { return }

        var todos = groupTodosByGroupID[todo.groupId] ?? []
        if let index = todos.firstIndex(where: { $0.id == todo.id }) {
            todos[index] = todo
        } else if insertAtFront {
            todos.insert(todo, at: 0)
        } else {
            todos.append(todo)
        }
        todos.sort { lhs, rhs in
            if lhs.updatedAt != rhs.updatedAt {
                return lhs.updatedAt > rhs.updatedAt
            }
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.id > rhs.id
        }
        groupTodosByGroupID[todo.groupId] = todos
    }

    private func removeTodoFromGroupCaches(todoID: String) {
        for groupID in groupTodosByGroupID.keys {
            groupTodosByGroupID[groupID]?.removeAll { $0.id == todoID }
        }
    }

    private func replaceTodoLocally(_ todo: Todo) {
        var all = pending + completed
        if let index = all.firstIndex(where: { $0.id == todo.id }) {
            all[index] = todo
        } else {
            all.append(todo)
        }
        apply(all)
        updateGroupTodoCache(with: todo)
    }

    private static func normalizedExpenseAmount(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let amount = Decimal(string: trimmed, locale: Self.expenseAmountLocale), amount > .zero else {
            return nil
        }
        return Self.expenseAmountFormatter.string(from: NSDecimalNumber(decimal: amount))
    }

    private func mergedFriend(summary: FriendUser, existing: FriendUser?) -> FriendUser {
        FriendUser(
            username: summary.username,
            id: summary.id,
            email: summary.email,
            avatarVersion: summary.avatarVersion,
            friendSince: summary.friendSince ?? existing?.friendSince,
            mutualGroups: summary.mutualGroups ?? existing?.mutualGroups
        )
    }

    private func optimisticFriend(from request: FriendRequest) -> FriendUser? {
        let counterpartID: String
        let counterpartUsername: String?
        let counterpartAvatarVersion: UInt32?

        switch request.direction {
        case .received:
            counterpartID = request.from
            counterpartUsername = request.fromUsername
            counterpartAvatarVersion = request.fromAvatarVersion
        case .sent:
            counterpartID = request.to
            counterpartUsername = request.toUsername
            counterpartAvatarVersion = request.toAvatarVersion
        }

        let trimmedID = counterpartID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUsername = counterpartUsername?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedID.isEmpty, !trimmedUsername.isEmpty else { return nil }

        return FriendUser(
            username: trimmedUsername,
            id: trimmedID,
            email: friendDetailsByID[trimmedID]?.email ?? "",
            avatarVersion: counterpartAvatarVersion ?? 0,
            friendSince: Date(),
            mutualGroups: friendDetailsByID[trimmedID]?.mutualGroups
        )
    }

    private func acceptedRequestSettingStatus(_ request: FriendRequest, status: String) -> FriendRequest {
        FriendRequest(
            id: request.id,
            from: request.from,
            fromUsername: request.fromUsername,
            fromAvatarVersion: request.fromAvatarVersion,
            to: request.to,
            toUsername: request.toUsername,
            toAvatarVersion: request.toAvatarVersion,
            msg: request.msg,
            status: status,
            createdAt: request.createdAt,
            direction: request.direction
        )
    }

    private func observeCachePersistence() {
        objectWillChange
            .debounce(for: .milliseconds(350), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.persistCache()
            }
            .store(in: &cacheBag)
    }

    private func hydrateCachedSnapshot() {
        guard !UITestConfig.usesStubData else { return }

        Task { [weak self] in
            guard
                let snapshot = await AppCacheStore.shared.load(
                    TodoCacheSnapshot.self,
                    for: Self.cacheKey
                )
            else {
                return
            }

            DispatchQueue.main.async {
                self?.applyCachedSnapshot(snapshot)
            }
        }
    }

    private func applyCachedSnapshot(_ snapshot: TodoCacheSnapshot) {
        pending = snapshot.pending
        completed = snapshot.completed
        groupTodosByGroupID = snapshot.groupTodosByGroupID
        groupExpenses = snapshot.groupExpenses
        groupExpenseHistoryByGroupID = snapshot.groupExpenseHistoryByGroupID
        groupTransactionPlansByGroupID = snapshot.groupTransactionPlansByGroupID
        expenseDetailsByID = snapshot.expenseDetailsByID
        groups = snapshot.groups
        groupDetailsByID = snapshot.groupDetailsByID
        friends = snapshot.friends
        friendDetailsByID = snapshot.friendDetailsByID
        friendRequests = snapshot.friendRequests
    }

    private func persistCache() {
        guard !UITestConfig.usesStubData else { return }
        let hasCachedContent = !pending.isEmpty
            || !completed.isEmpty
            || !groupTodosByGroupID.isEmpty
            || !groupExpenses.isEmpty
            || !groupExpenseHistoryByGroupID.isEmpty
            || !groupTransactionPlansByGroupID.isEmpty
            || !expenseDetailsByID.isEmpty
            || !groups.isEmpty
            || !groupDetailsByID.isEmpty
            || !friends.isEmpty
            || !friendDetailsByID.isEmpty
            || !friendRequests.isEmpty

        guard hasCachedContent else {
            clearCache()
            return
        }

        let snapshot = TodoCacheSnapshot(
            pending: pending,
            completed: completed,
            groupTodosByGroupID: groupTodosByGroupID,
            groupExpenses: groupExpenses,
            groupExpenseHistoryByGroupID: groupExpenseHistoryByGroupID,
            groupTransactionPlansByGroupID: groupTransactionPlansByGroupID,
            expenseDetailsByID: expenseDetailsByID,
            groups: groups,
            groupDetailsByID: groupDetailsByID,
            friends: friends,
            friendDetailsByID: friendDetailsByID,
            friendRequests: friendRequests
        )

        Task {
            await AppCacheStore.shared.save(snapshot, for: Self.cacheKey)
        }
    }

    private func clearCache() {
        Task {
            await AppCacheStore.shared.removeValue(for: Self.cacheKey)
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
