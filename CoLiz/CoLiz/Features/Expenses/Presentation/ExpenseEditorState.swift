import Foundation
import UIKit

enum ExpenseSplitMethod: String, CaseIterable, Identifiable {
    case equal
    case percentage
    case fixed

    nonisolated var id: String { rawValue }

    nonisolated var title: String {
        switch self {
        case .equal:
            return "Equal"
        case .percentage:
            return "Percentage"
        case .fixed:
            return "Fixed"
        }
    }

    nonisolated var inputTitle: String {
        switch self {
        case .equal:
            return ""
        case .percentage:
            return "Percent"
        case .fixed:
            return "Amount"
        }
    }

    nonisolated var keyboardType: UIKeyboardType {
        switch self {
        case .equal:
            return .default
        case .percentage, .fixed:
            return .decimalPad
        }
    }
}

struct ExpenseEditorState {
    var selectedGroupID = ""
    var draftName = ""
    var selectedCategory: ExpenseCategory = .other
    var draftAmount = ""
    var draftNote = ""
    var selectedOccurredAt = Date()
    var selectedPayerID = ""
    var selectedParticipantIDs = Set<String>()
    var splitMethod: ExpenseSplitMethod = .equal
    var participantValues: [String: String] = [:]
    var showAdvancedOptions = false
    var groupSearchText = ""
    var hasManuallySelectedCategory = false
    var isApplyingSuggestedCategory = false
    var hasLoadedEditingExpense = false

    nonisolated var isShowingAdvancedOptions: Bool {
        showAdvancedOptions || splitMethod != .equal
    }

    nonisolated var isTransactionCategory: Bool {
        selectedCategory == .transaction
    }

    nonisolated func orderedSelectedParticipantIDs(in members: [GroupMember]) -> [String] {
        members
            .map(\.id)
            .filter { selectedParticipantIDs.contains($0) }
    }

    mutating func resetForGroupChange(isHydratingEditingExpense: Bool) {
        guard !isHydratingEditingExpense else { return }
        selectedPayerID = ""
        selectedParticipantIDs = []
        participantValues = [:]
        splitMethod = .equal
        showAdvancedOptions = false
    }

    mutating func applyEditingExpense(_ detail: ExpenseDetail) {
        draftName = detail.name
        selectedCategory = detail.expenseCategory
        draftAmount = detail.amount
        draftNote = detail.note ?? ""
        selectedOccurredAt = detail.occurredAt ?? Date()
        selectedPayerID = detail.paidBy
        splitMethod = ExpenseSplitMethod(rawValue: detail.splitMethod) ?? .equal
        showAdvancedOptions = splitMethod != .equal
        hasManuallySelectedCategory = true
        selectedParticipantIDs = Set(detail.participants.map(\.userID))

        switch splitMethod {
        case .equal:
            participantValues = [:]
        case .percentage:
            participantValues = Dictionary(
                uniqueKeysWithValues: detail.participants.compactMap { participant in
                    guard let percentage = participant.percentage else { return nil }
                    return (participant.userID, percentage)
                }
            )
        case .fixed:
            participantValues = Dictionary(
                uniqueKeysWithValues: detail.participants.compactMap { participant in
                    guard let fixedAmount = participant.fixedAmount else { return nil }
                    return (participant.userID, fixedAmount)
                }
            )
        }

        hasLoadedEditingExpense = true
    }

    mutating func toggleParticipant(_ userID: String) {
        if selectedParticipantIDs.contains(userID) {
            selectedParticipantIDs.remove(userID)
            participantValues.removeValue(forKey: userID)
        } else {
            selectedParticipantIDs.insert(userID)
        }
    }
}
