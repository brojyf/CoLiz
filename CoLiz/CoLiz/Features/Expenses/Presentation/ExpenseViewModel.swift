import Combine
import Foundation

@MainActor
final class ExpenseViewModel: ObservableObject {
    private let todoVM: TodoVM
    private var bag = Set<AnyCancellable>()

    init(todoVM: TodoVM) {
        self.todoVM = todoVM

        todoVM.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &bag)
    }

    var groupExpenses: [GroupExpense] { todoVM.groupExpenses }
    var groups: [AppGroup] { todoVM.groups }
    var isLoadingGroupExpenses: Bool { todoVM.isLoadingGroupExpenses }
    var isCreatingExpense: Bool { todoVM.isCreatingExpense }
    var loadingGroupDetailIDs: Set<String> { todoVM.loadingGroupDetailIDs }
    var loadingExpenseDetailIDs: Set<String> { todoVM.loadingExpenseDetailIDs }
    var loadingGroupExpenseHistoryIDs: Set<String> { todoVM.loadingGroupExpenseHistoryIDs }
    var loadingGroupTransactionPlanIDs: Set<String> { todoVM.loadingGroupTransactionPlanIDs }
    var applyingGroupTransactionPlanIDs: Set<String> { todoVM.applyingGroupTransactionPlanIDs }
    var updatingExpenseIDs: Set<String> { todoVM.updatingExpenseIDs }
    var deletingExpenseIDs: Set<String> { todoVM.deletingExpenseIDs }

    func prefetchGroupExpensesIfNeeded() {
        todoVM.prefetchGroupExpensesIfNeeded()
    }

    func refreshExpenses() async {
        await todoVM.refreshExpenses()
    }

    func refreshGroupExpenseSummary(groupID: String) async {
        await todoVM.refreshGroupExpenseSummary(groupID: groupID)
    }

    func loadGroups() {
        todoVM.loadGroups()
    }

    func prefetchGroupsIfNeeded() {
        todoVM.prefetchGroupsIfNeeded()
    }

    func groupExpense(for groupID: String) -> GroupExpense? {
        todoVM.groupExpense(for: groupID)
    }

    func groupExpenseHistory(for groupID: String) -> [ExpenseHistoryItem] {
        todoVM.groupExpenseHistory(for: groupID)
    }

    func groupTransactionPlan(for groupID: String) -> GroupTransactionPlan? {
        todoVM.groupTransactionPlan(for: groupID)
    }

    func expenseDetail(for expenseID: String) -> ExpenseDetail? {
        todoVM.expenseDetail(for: expenseID)
    }

    func groupDetail(for groupID: String) -> GroupDetail? {
        todoVM.groupDetail(for: groupID)
    }

    func fetchGroupDetail(groupID: String) {
        todoVM.fetchGroupDetail(groupID: groupID)
    }

    func fetchExpenseDetail(expenseID: String) {
        todoVM.fetchExpenseDetail(expenseID: expenseID)
    }

    func fetchGroupExpenseHistory(groupID: String) {
        todoVM.fetchGroupExpenseHistory(groupID: groupID)
    }

    func fetchGroupTransactionPlan(groupID: String, force: Bool = false) {
        todoVM.fetchGroupTransactionPlan(groupID: groupID, force: force)
    }

    func applyGroupTransactionPlan(groupID: String, onSuccess: (() -> Void)? = nil) {
        todoVM.applyGroupTransactionPlan(groupID: groupID, onSuccess: onSuccess)
    }

    func createExpense(
        groupID: String,
        request: CreateExpenseRequest,
        onSuccess: (() -> Void)? = nil
    ) {
        todoVM.createExpense(groupID: groupID, request: request, onSuccess: onSuccess)
    }

    func updateExpense(
        expenseID: String,
        groupID: String,
        request: CreateExpenseRequest,
        onSuccess: (() -> Void)? = nil
    ) {
        todoVM.updateExpense(
            expenseID: expenseID,
            groupID: groupID,
            request: request,
            onSuccess: onSuccess
        )
    }

    func deleteExpense(groupID: String, expenseID: String) {
        todoVM.deleteExpense(groupID: groupID, expenseID: expenseID)
    }
}
