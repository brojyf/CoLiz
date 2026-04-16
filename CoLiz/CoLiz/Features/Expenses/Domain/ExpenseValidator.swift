import Foundation
import SwiftUI

enum ExpenseValidator {
    nonisolated static func validationMessage(
        state: ExpenseEditorState,
        availableGroups: [AppGroup],
        selectedGroupMembers: [GroupMember]
    ) -> String? {
        if availableGroups.isEmpty {
            return "Create or join a group first."
        }
        if state.selectedGroupID.isEmpty {
            return "Choose a group."
        }
        if !state.selectedGroupID.isEmpty && selectedGroupMembers.isEmpty {
            return "This group has no members yet."
        }

        let trimmedName = state.draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            return "Enter an expense name."
        }
        if trimmedName.count > 32 {
            return "Expense name must be 32 characters or less."
        }
        if !canInferTransactionAmount(state: state, selectedGroupMembers: selectedGroupMembers)
            && normalizedMoney(state.draftAmount) == nil {
            return "Enter a valid amount greater than 0."
        }

        let memberIDs = Set(selectedGroupMembers.map(\.id))
        if !memberIDs.contains(state.selectedPayerID) {
            return "Choose who paid."
        }

        let orderedParticipantIDs = state.orderedSelectedParticipantIDs(in: selectedGroupMembers)
        if orderedParticipantIDs.isEmpty {
            return "Choose at least one participant."
        }
        if state.isTransactionCategory && orderedParticipantIDs.contains(state.selectedPayerID) {
            return "Transaction recipients cannot include the payer."
        }
        if state.isTransactionCategory && state.splitMethod != .fixed {
            return "Transaction must use exact recipient amounts."
        }

        let trimmedNote = state.draftNote.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedNote.count > 64 {
            return "Note must be 64 characters or less."
        }

        switch state.splitMethod {
        case .equal:
            return nil
        case .percentage:
            return percentValidationMessage(
                participantValues: state.participantValues,
                orderedParticipantIDs: orderedParticipantIDs
            )
        case .fixed:
            return fixedValidationMessage(
                participantValues: state.participantValues,
                orderedParticipantIDs: orderedParticipantIDs,
                resolvedAmount: resolvedAmount(state: state, selectedGroupMembers: selectedGroupMembers)
            )
        }
    }

    nonisolated static func submissionRequest(
        state: ExpenseEditorState,
        availableGroups: [AppGroup],
        selectedGroupMembers: [GroupMember],
        originalOccurredAt: Date?
    ) -> CreateExpenseRequest? {
        guard validationMessage(
            state: state,
            availableGroups: availableGroups,
            selectedGroupMembers: selectedGroupMembers
        ) == nil else {
            return nil
        }

        guard let resolvedAmount = resolvedAmount(state: state, selectedGroupMembers: selectedGroupMembers) else {
            return nil
        }

        let orderedParticipantIDs = state.orderedSelectedParticipantIDs(in: selectedGroupMembers)
        let participants = orderedParticipantIDs.compactMap { userID -> ExpenseParticipantInput? in
            switch state.splitMethod {
            case .equal:
                return ExpenseParticipantInput(userID: userID, percentage: nil, fixedAmount: nil)
            case .percentage:
                guard let normalizedPercentage = normalizedPercentage(
                    for: userID,
                    participantValues: state.participantValues
                ) else {
                    return nil
                }
                return ExpenseParticipantInput(
                    userID: userID,
                    percentage: normalizedPercentage,
                    fixedAmount: nil
                )
            case .fixed:
                guard let normalizedFixedAmount = normalizedFixedAmount(
                    for: userID,
                    participantValues: state.participantValues
                ) else {
                    return nil
                }
                return ExpenseParticipantInput(
                    userID: userID,
                    percentage: nil,
                    fixedAmount: normalizedFixedAmount
                )
            }
        }

        guard participants.count == orderedParticipantIDs.count else { return nil }

        let trimmedNote = state.draftNote.trimmingCharacters(in: .whitespacesAndNewlines)
        return CreateExpenseRequest(
            name: state.draftName.trimmingCharacters(in: .whitespacesAndNewlines),
            category: state.selectedCategory.rawValue,
            amount: resolvedAmount,
            paidBy: state.selectedPayerID,
            splitMethod: state.splitMethod.rawValue,
            note: trimmedNote.isEmpty ? nil : trimmedNote,
            occurredAt: formattedOccurredAt(state.selectedOccurredAt, originalOccurredAt: originalOccurredAt),
            participants: participants
        )
    }

    nonisolated static func canInferTransactionAmount(
        state: ExpenseEditorState,
        selectedGroupMembers: [GroupMember]
    ) -> Bool {
        state.isTransactionCategory
            && state.orderedSelectedParticipantIDs(in: selectedGroupMembers).count == 1
    }

    nonisolated static func inferredTransactionAmount(
        state: ExpenseEditorState,
        selectedGroupMembers: [GroupMember]
    ) -> String? {
        guard canInferTransactionAmount(state: state, selectedGroupMembers: selectedGroupMembers),
              let participantID = state.orderedSelectedParticipantIDs(in: selectedGroupMembers).first else {
            return nil
        }
        return normalizedFixedAmount(for: participantID, participantValues: state.participantValues)
    }

    nonisolated static func resolvedAmount(
        state: ExpenseEditorState,
        selectedGroupMembers: [GroupMember]
    ) -> String? {
        normalizedMoney(state.draftAmount)
            ?? inferredTransactionAmount(state: state, selectedGroupMembers: selectedGroupMembers)
    }

    nonisolated static func fixedSplitRemainingCents(
        state: ExpenseEditorState,
        selectedGroupMembers: [GroupMember]
    ) -> Int? {
        guard state.splitMethod == .fixed else { return nil }
        guard let totalCents = resolvedAmount(
            state: state,
            selectedGroupMembers: selectedGroupMembers
        ).flatMap(parseMoneyToCents) else {
            return nil
        }

        let allocatedCents = state.orderedSelectedParticipantIDs(in: selectedGroupMembers)
            .reduce(into: 0) { total, userID in
                total += fixedCents(for: userID, participantValues: state.participantValues) ?? 0
            }
        return totalCents - allocatedCents
    }

    nonisolated static func fixedSplitRemainingText(
        state: ExpenseEditorState,
        selectedGroupMembers: [GroupMember]
    ) -> String? {
        guard let remainingCents = fixedSplitRemainingCents(
            state: state,
            selectedGroupMembers: selectedGroupMembers
        ) else {
            return nil
        }

        let formattedAmount = "$\(formatCents(abs(remainingCents)))"
        if remainingCents == 0 {
            return "Balanced"
        }
        if remainingCents > 0 {
            return "\(formattedAmount) remaining"
        }
        return "\(formattedAmount) over"
    }

    static func fixedSplitRemainingTint(
        state: ExpenseEditorState,
        selectedGroupMembers: [GroupMember]
    ) -> Color {
        guard let remainingCents = fixedSplitRemainingCents(
            state: state,
            selectedGroupMembers: selectedGroupMembers
        ) else {
            return AppTheme.secondary
        }
        if remainingCents == 0 {
            return AppTheme.lent
        }
        if remainingCents > 0 {
            return AppTheme.primary
        }
        return AppTheme.blush
    }

    nonisolated static func remainingAmountForParticipant(
        _ userID: String,
        state: ExpenseEditorState,
        selectedGroupMembers: [GroupMember]
    ) -> Int? {
        guard state.selectedParticipantIDs.contains(userID) else { return nil }
        guard let totalCents = resolvedAmount(
            state: state,
            selectedGroupMembers: selectedGroupMembers
        ).flatMap(parseMoneyToCents) else {
            return nil
        }

        let otherAllocatedCents = state.orderedSelectedParticipantIDs(in: selectedGroupMembers)
            .reduce(into: 0) { total, participantID in
                guard participantID != userID else { return }
                total += fixedCents(for: participantID, participantValues: state.participantValues) ?? 0
            }
        return totalCents - otherAllocatedCents
    }

    nonisolated static func equalSummaryText(memberCount: Int) -> String {
        guard memberCount > 0 else { return "Split equally with all members" }
        return "Default: split equally with all \(memberCount) members."
    }

    nonisolated static func participantsSectionTitle(for state: ExpenseEditorState) -> String {
        let baseTitle = state.isTransactionCategory ? "Recipients" : "Participants"
        return state.splitMethod == .equal ? baseTitle : "\(baseTitle) (\(state.splitMethod.inputTitle))"
    }

    nonisolated static func normalizedMoney(_ raw: String) -> String? {
        guard let cents = parseMoneyToCents(raw) else { return nil }
        return formatCents(cents)
    }

    nonisolated static func normalizedPercentage(
        for userID: String,
        participantValues: [String: String]
    ) -> String? {
        guard let basisPoints = basisPoints(for: userID, participantValues: participantValues) else {
            return nil
        }
        return formatBasisPoints(basisPoints)
    }

    nonisolated static func normalizedFixedAmount(
        for userID: String,
        participantValues: [String: String]
    ) -> String? {
        guard let cents = fixedCents(for: userID, participantValues: participantValues) else {
            return nil
        }
        return formatCents(cents)
    }

    nonisolated static func parseMoneyToCents(_ raw: String) -> Int? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2, let intPart = parts.first, !intPart.isEmpty else { return nil }
        guard intPart.allSatisfy(\.isNumber), intPart.count <= 8 else { return nil }

        let fractional = parts.count == 2 ? String(parts[1]) : ""
        guard fractional.count <= 2, fractional.allSatisfy(\.isNumber) else { return nil }

        let whole = Int(intPart) ?? -1
        guard whole >= 0 else { return nil }

        let fraction = Int(fractional.padding(toLength: 2, withPad: "0", startingAt: 0)) ?? -1
        let cents = whole * 100 + fraction
        return cents > 0 ? cents : nil
    }

    nonisolated static func parsePercentToBasisPoints(_ raw: String) -> Int? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2, let intPart = parts.first, !intPart.isEmpty else { return nil }
        guard intPart.allSatisfy(\.isNumber) else { return nil }

        let fractional = parts.count == 2 ? String(parts[1]) : ""
        guard fractional.count <= 2, fractional.allSatisfy(\.isNumber) else { return nil }

        let whole = Int(intPart) ?? -1
        guard whole >= 0 else { return nil }

        let fraction = Int(fractional.padding(toLength: 2, withPad: "0", startingAt: 0)) ?? -1
        let basisPoints = whole * 100 + fraction
        guard basisPoints > 0, basisPoints <= 10_000 else { return nil }
        return basisPoints
    }

    nonisolated static func formatCents(_ cents: Int) -> String {
        String(format: "%d.%02d", cents / 100, cents % 100)
    }

    nonisolated static func formatBasisPoints(_ basisPoints: Int) -> String {
        String(format: "%d.%02d", basisPoints / 100, basisPoints % 100)
    }

    nonisolated private static func percentValidationMessage(
        participantValues: [String: String],
        orderedParticipantIDs: [String]
    ) -> String? {
        var totalBasisPoints = 0
        for userID in orderedParticipantIDs {
            guard let basisPoints = basisPoints(for: userID, participantValues: participantValues) else {
                return "Each selected participant needs a percentage."
            }
            totalBasisPoints += basisPoints
        }
        return totalBasisPoints == 10_000 ? nil : "Selected percentages must add up to 100.00."
    }

    nonisolated private static func fixedValidationMessage(
        participantValues: [String: String],
        orderedParticipantIDs: [String],
        resolvedAmount: String?
    ) -> String? {
        guard let totalCents = resolvedAmount.flatMap(parseMoneyToCents) else {
            return "Enter a valid amount greater than 0."
        }

        var splitTotal = 0
        for userID in orderedParticipantIDs {
            guard let fixedCents = fixedCents(for: userID, participantValues: participantValues) else {
                return "Each selected participant needs a fixed amount."
            }
            splitTotal += fixedCents
        }
        return splitTotal == totalCents ? nil : "Selected fixed amounts must equal the total amount."
    }

    nonisolated private static func basisPoints(
        for userID: String,
        participantValues: [String: String]
    ) -> Int? {
        guard let value = participantValues[userID] else { return nil }
        return parsePercentToBasisPoints(value)
    }

    nonisolated private static func fixedCents(
        for userID: String,
        participantValues: [String: String]
    ) -> Int? {
        guard let value = participantValues[userID] else { return nil }
        return parseMoneyToCents(value)
    }

    nonisolated private static func formattedOccurredAt(_ date: Date, originalOccurredAt: Date?) -> String? {
        if let originalOccurredAt,
           Calendar.current.isDate(date, inSameDayAs: originalOccurredAt) {
            return nil
        }

        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.formatOptions = [.withInternetDateTime]

        let now = Date()
        if Calendar.current.isDate(date, inSameDayAs: now) {
            return formatter.string(from: now)
        }

        let localComponents = Calendar.current.dateComponents([.year, .month, .day], from: date)
        var utcComponents = DateComponents()
        utcComponents.calendar = Calendar(identifier: .gregorian)
        utcComponents.timeZone = TimeZone(secondsFromGMT: 0)
        utcComponents.year = localComponents.year
        utcComponents.month = localComponents.month
        utcComponents.day = localComponents.day
        utcComponents.hour = 12
        utcComponents.minute = 0
        utcComponents.second = 0

        guard let utcDate = utcComponents.date else {
            return formatter.string(from: now)
        }
        return formatter.string(from: utcDate)
    }
}
