import Foundation

struct ProfileCacheSnapshot: Codable {
    let profile: UserProfile?
}

struct TodoCacheSnapshot: Codable {
    let pending: [Todo]
    let completed: [Todo]
    let groupTodosByGroupID: [String: [Todo]]
    let groupExpenses: [GroupExpense]
    let groupExpenseHistoryByGroupID: [String: [ExpenseHistoryItem]]
    let groupTransactionPlansByGroupID: [String: GroupTransactionPlan]
    let expenseDetailsByID: [String: ExpenseDetail]
    let groups: [AppGroup]
    let groupDetailsByID: [String: GroupDetail]
    let friends: [FriendUser]
    let friendDetailsByID: [String: FriendUser]
    let friendRequests: [FriendRequest]
}
