import Foundation
import SwiftUI
import UIKit

private extension View {
    func dismissesKeyboardOnBackgroundTap() -> some View {
        modifier(BackgroundKeyboardDismissModifier())
    }
}

private struct BackgroundKeyboardDismissModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(KeyboardDismissTapView())
    }
}

private struct KeyboardDismissTapView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.installIfNeeded(from: uiView)
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var tapGesture: UITapGestureRecognizer?
        weak var hostView: UIView?

        func installIfNeeded(from view: UIView) {
            let candidateHost = view.superview ?? view.window
            guard let candidateHost, candidateHost !== hostView else { return }

            detach()

            let tapGesture = UITapGestureRecognizer(
                target: self,
                action: #selector(handleTap)
            )
            tapGesture.cancelsTouchesInView = false
            tapGesture.delegate = self
            candidateHost.addGestureRecognizer(tapGesture)

            self.tapGesture = tapGesture
            self.hostView = candidateHost
        }

        func detach() {
            if let tapGesture, let hostView {
                hostView.removeGestureRecognizer(tapGesture)
            }
            tapGesture = nil
            hostView = nil
        }

        @objc
        func handleTap() {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let touchedView = touch.view else { return true }
            return shouldDismissKeyboard(for: touchedView)
        }

        private func shouldDismissKeyboard(for view: UIView) -> Bool {
            if view is UIControl || view is UITextView {
                return false
            }

            var current: UIView? = view
            while let inspecting = current {
                if inspecting is UIControl || inspecting is UITextView {
                    return false
                }
                current = inspecting.superview
            }

            return true
        }
    }
}

struct CreateExpenseSheetView: View {
    @EnvironmentObject private var expenseVM: ExpenseViewModel
    @EnvironmentObject private var profileVM: ProfileVM
    @EnvironmentObject private var navigationState: MainTabNavigationState
    @Environment(\.dismiss) private var dismiss

    let fixedGroupID: String?
    let editingExpenseID: String?
    var onClose: (() -> Void)? = nil
    var onSuccess: (() -> Void)? = nil

    @State private var editor = ExpenseEditorState()

    init(
        fixedGroupID: String? = nil,
        editingExpenseID: String? = nil,
        onClose: (() -> Void)? = nil,
        onSuccess: (() -> Void)? = nil
    ) {
        self.fixedGroupID = fixedGroupID
        self.editingExpenseID = editingExpenseID
        self.onClose = onClose
        self.onSuccess = onSuccess
    }

    private var isEditing: Bool {
        editingExpenseID != nil
    }

    private var selectedGroup: AppGroup? {
        expenseVM.groups.first(where: { $0.id == editor.selectedGroupID })
            ?? expenseVM.groupDetail(for: editor.selectedGroupID)?.asAppGroup
    }

    private var selectedGroupDetail: GroupDetail? {
        guard !editor.selectedGroupID.isEmpty else { return nil }
        return expenseVM.groupDetail(for: editor.selectedGroupID)
    }

    private var selectedGroupMembers: [GroupMember] {
        selectedGroupDetail?.members ?? []
    }

    private var isLoadingSelectedGroup: Bool {
        !editor.selectedGroupID.isEmpty && expenseVM.loadingGroupDetailIDs.contains(editor.selectedGroupID)
    }

    private var editingExpenseDetail: ExpenseDetail? {
        guard let editingExpenseID else { return nil }
        return expenseVM.expenseDetail(for: editingExpenseID)
    }

    private var isLoadingExpenseDetail: Bool {
        guard let editingExpenseID else { return false }
        return expenseVM.loadingExpenseDetailIDs.contains(editingExpenseID)
    }

    private var isSubmitting: Bool {
        if let editingExpenseID {
            return expenseVM.updatingExpenseIDs.contains(editingExpenseID)
        }
        return expenseVM.isCreatingExpense
    }

    private var isTransactionCategory: Bool {
        editor.isTransactionCategory
    }

    private var isSelectingGroup: Bool {
        !isEditing && editor.selectedGroupID.isEmpty
    }

    private var orderedSelectedParticipantIDs: [String] {
        editor.orderedSelectedParticipantIDs(in: selectedGroupMembers)
    }

    private var canInferTransactionAmount: Bool {
        ExpenseValidator.canInferTransactionAmount(
            state: editor,
            selectedGroupMembers: selectedGroupMembers
        )
    }

    private var validationMessage: String? {
        if isLoadingSelectedGroup {
            return "Loading group members..."
        }
        return ExpenseValidator.validationMessage(
            state: editor,
            availableGroups: expenseVM.groups,
            selectedGroupMembers: selectedGroupMembers
        )
    }

    private var fixedSplitRemainingText: String? {
        ExpenseValidator.fixedSplitRemainingText(
            state: editor,
            selectedGroupMembers: selectedGroupMembers
        )
    }

    private var fixedSplitRemainingTint: Color {
        ExpenseValidator.fixedSplitRemainingTint(
            state: editor,
            selectedGroupMembers: selectedGroupMembers
        )
    }

    private var normalizedAmount: String? {
        ExpenseValidator.normalizedMoney(editor.draftAmount)
    }

    private var equalSummaryText: String {
        ExpenseValidator.equalSummaryText(memberCount: selectedGroupMembers.count)
    }

    private var filteredGroups: [AppGroup] {
        let keyword = editor.groupSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return expenseVM.groups }
        return expenseVM.groups.filter { group in
            group.groupName.localizedCaseInsensitiveContains(keyword)
        }
    }

    private var submissionRequest: CreateExpenseRequest? {
        ExpenseValidator.submissionRequest(
            state: editor,
            availableGroups: expenseVM.groups,
            selectedGroupMembers: selectedGroupMembers,
            originalOccurredAt: editingExpenseDetail?.occurredAt
        )
    }

    var body: some View {
        screenContent
        .navigationTitle(navigationTitleText)
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .dismissesKeyboardOnBackgroundTap()
        .background(AppTheme.background)
        .task {
            expenseVM.loadGroups()
            initializeSelectedGroupIfNeeded()
            if let detail = editingExpenseDetail, !editor.hasLoadedEditingExpense {
                applyEditingExpense(detail)
            }
            if let editingExpenseID {
                expenseVM.fetchExpenseDetail(expenseID: editingExpenseID)
            }
        }
        .onChange(of: editingExpenseID) { _, _ in
            editor.hasLoadedEditingExpense = false
        }
        .onChange(of: expenseVM.groups) { _, _ in
            if
                !editor.selectedGroupID.isEmpty,
                expenseVM.groups.contains(where: { $0.id == editor.selectedGroupID }) == false,
                expenseVM.groupDetail(for: editor.selectedGroupID) == nil
            {
                editor.selectedGroupID = ""
            }
            initializeSelectedGroupIfNeeded()
        }
        .onChange(of: editor.selectedGroupID) { _, newValue in
            setSelectedGroup(newValue)
        }
        .onChange(of: selectedGroupDetail) { _, newValue in
            guard let detail = newValue else { return }
            applyDefaults(from: detail)
        }
        .onChange(of: editingExpenseDetail) { _, newValue in
            guard let newValue, !editor.hasLoadedEditingExpense else { return }
            applyEditingExpense(newValue)
        }
        .onChange(of: editor.draftName) { _, newValue in
            applySuggestedCategory(for: newValue)
        }
        .onChange(of: editor.draftAmount) { _, _ in
            syncSingleTransactionRecipientAmount()
        }
        .onChange(of: editor.selectedCategory) { _, newValue in
            guard !editor.isApplyingSuggestedCategory else { return }
            editor.hasManuallySelectedCategory = true
            if newValue == .transaction {
                applyTransactionModeDefaults()
            }
        }
        .onChange(of: editor.selectedPayerID) { _, newValue in
            guard isTransactionCategory else { return }
            editor.selectedParticipantIDs.remove(newValue)
            editor.participantValues.removeValue(forKey: newValue)
            applyAutoTransactionRecipientSelection(for: newValue)
            syncSingleTransactionRecipientAmount()
        }
        .onChange(of: editor.splitMethod) { _, newValue in
            if isTransactionCategory && newValue != .fixed {
                editor.splitMethod = .fixed
                return
            }
            if newValue == .equal && !editor.showAdvancedOptions {
                editor.participantValues = [:]
            }
        }
        .toolbar { toolbarContent }
    }

    @ViewBuilder
    private var screenContent: some View {
        if isEditing && editingExpenseDetail == nil {
            loadingExpenseContent
        } else if isSelectingGroup {
            groupSelectionContent
        } else {
            expenseFormContent
        }
    }

    private var navigationTitleText: String {
        isEditing ? "Edit Expense" : "Create Expense"
    }

    private var shouldCloseFromLeadingAction: Bool {
        isSelectingGroup || isEditing || fixedGroupID != nil
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(shouldCloseFromLeadingAction ? "Cancel" : "Back") {
                if shouldCloseFromLeadingAction {
                    closeSheet()
                } else {
                    editor.selectedGroupID = ""
                    editor.groupSearchText = ""
                }
            }
            .disabled(isSubmitting)
        }

        if !isSelectingGroup {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    submit()
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .tint(AppTheme.primary)
                    } else {
                        Text(isEditing ? "Save" : "Create")
                            .font(.body.weight(.semibold))
                    }
                }
                .foregroundStyle(AppTheme.primary)
                .disabled(isSubmitting || submissionRequest == nil)
            }
        }
    }

    private var loadingExpenseContent: some View {
        ExpenseLoadingStateView(
            message: isLoadingExpenseDetail ? "Loading expense..." : "Preparing expense..."
        )
    }

    private var groupSelectionContent: some View {
        ExpenseGroupSelectionView(
            groupSearchText: $editor.groupSearchText,
            filteredGroups: filteredGroups,
            onSelectGroup: { group in
                editor.selectedGroupID = group.id
                editor.groupSearchText = ""
            }
        )
    }

    private var expenseFormContent: some View {
        ExpenseFormView(
            isEditing: isEditing,
            fixedGroupID: fixedGroupID,
            selectedGroup: selectedGroup,
            isLoadingSelectedGroup: isLoadingSelectedGroup,
            selectedGroupMembers: selectedGroupMembers,
            draftName: $editor.draftName,
            selectedCategory: $editor.selectedCategory,
            draftAmount: $editor.draftAmount,
            draftNote: $editor.draftNote,
            selectedOccurredAt: $editor.selectedOccurredAt,
            selectedPayerID: $editor.selectedPayerID,
            splitMethod: $editor.splitMethod,
            showAdvancedOptions: $editor.showAdvancedOptions,
            selectedParticipantIDs: $editor.selectedParticipantIDs,
            isShowingAdvancedOptions: editor.isShowingAdvancedOptions,
            isTransactionCategory: isTransactionCategory,
            isAmountOptional: canInferTransactionAmount,
            equalSummaryText: equalSummaryText,
            participantsSectionTitle: participantsSectionTitle,
            participantOptions: participantOptions,
            validationMessage: validationMessage,
            fixedSplitRemainingText: fixedSplitRemainingText,
            fixedSplitRemainingTint: fixedSplitRemainingTint,
            onChooseAnotherGroup: {
                guard !isEditing && fixedGroupID == nil else { return }
                editor.groupSearchText = ""
                editor.selectedGroupID = ""
            },
            onToggleParticipant: toggleParticipant(_:),
            participantValueBinding: bindingForParticipantValue(_:),
            canApplyRemainingAmount: canApplyRemainingAmount(to:),
            onApplyRemainingAmount: applyRemainingAmount(to:)
        )
    }

    private func bindingForParticipantValue(_ userID: String) -> Binding<String> {
        Binding {
            editor.participantValues[userID, default: ""]
        } set: { newValue in
            editor.participantValues[userID] = newValue
        }
    }

    private func initializeSelectedGroupIfNeeded() {
        guard editor.selectedGroupID.isEmpty else { return }

        if let fixedGroupID {
            editor.selectedGroupID = fixedGroupID
            return
        }

        if let editingExpenseDetail {
            editor.selectedGroupID = editingExpenseDetail.groupID
        }
    }

    private func setSelectedGroup(_ groupID: String) {
        let isHydratingEditingExpense = isEditing && !editor.hasLoadedEditingExpense
        editor.resetForGroupChange(isHydratingEditingExpense: isHydratingEditingExpense)

        guard !groupID.isEmpty else { return }
        expenseVM.fetchGroupDetail(groupID: groupID)

        if let detail = expenseVM.groupDetail(for: groupID), !isHydratingEditingExpense {
            applyDefaults(from: detail)
        }
    }

    private func applyDefaults(from detail: GroupDetail) {
        let members = detail.members
        let memberIDs = Set(members.map(\.id))

        if !memberIDs.contains(editor.selectedPayerID) {
            editor.selectedPayerID = preferredDefaultPayerID(from: members)
        }

        editor.selectedParticipantIDs = editor.selectedParticipantIDs.filter { memberIDs.contains($0) }

        if editor.selectedParticipantIDs.isEmpty {
            if isTransactionCategory {
                editor.selectedParticipantIDs = Set(members.map(\.id).filter { $0 != editor.selectedPayerID })
            } else {
                editor.selectedParticipantIDs = memberIDs
            }
        }

        if isTransactionCategory {
            editor.selectedParticipantIDs.remove(editor.selectedPayerID)
            applyAutoTransactionRecipientSelection(for: editor.selectedPayerID)
        }

        editor.participantValues = editor.participantValues.filter { memberIDs.contains($0.key) }
        syncSingleTransactionRecipientAmount()
    }

    private func preferredDefaultPayerID(from members: [GroupMember]) -> String {
        if let currentUserID = profileVM.profile?.id,
           members.contains(where: { $0.id == currentUserID }) {
            return currentUserID
        }
        return members.first?.id ?? ""
    }

    private func applyEditingExpense(_ detail: ExpenseDetail) {
        initializeSelectedGroupIfNeeded()
        editor.applyEditingExpense(detail)
        expenseVM.fetchGroupDetail(groupID: detail.groupID)
    }

    private func toggleParticipant(_ userID: String) {
        editor.toggleParticipant(userID)
        syncSingleTransactionRecipientAmount()
    }

    private var participantOptions: [GroupMember] {
        if isTransactionCategory {
            return selectedGroupMembers.filter { $0.id != editor.selectedPayerID }
        }
        return selectedGroupMembers
    }

    private var participantsSectionTitle: String {
        ExpenseValidator.participantsSectionTitle(for: editor)
    }

    private func applyTransactionModeDefaults() {
        editor.splitMethod = .fixed
        editor.showAdvancedOptions = true

        let recipientIDs = Set(selectedGroupMembers.map(\.id).filter { $0 != editor.selectedPayerID })
        editor.selectedParticipantIDs = recipientIDs
        editor.participantValues.removeValue(forKey: editor.selectedPayerID)
        applyAutoTransactionRecipientSelection(for: editor.selectedPayerID)
        syncSingleTransactionRecipientAmount()
    }

    private func applyAutoTransactionRecipientSelection(for payerID: String) {
        guard isTransactionCategory, !payerID.isEmpty else { return }
        guard selectedGroupMembers.count == 2 else { return }

        editor.selectedParticipantIDs = Set(
            selectedGroupMembers
                .map(\.id)
                .filter { $0 != payerID }
        )
    }

    private func syncSingleTransactionRecipientAmount() {
        guard isTransactionCategory else { return }
        guard orderedSelectedParticipantIDs.count == 1 else { return }
        guard let recipientID = orderedSelectedParticipantIDs.first else { return }
        guard let normalizedAmount else { return }

        editor.participantValues[recipientID] = normalizedAmount
    }

    private func remainingAmountForParticipant(_ userID: String) -> Int? {
        ExpenseValidator.remainingAmountForParticipant(
            userID,
            state: editor,
            selectedGroupMembers: selectedGroupMembers
        )
    }

    private func canApplyRemainingAmount(to userID: String) -> Bool {
        guard let remainingCents = remainingAmountForParticipant(userID) else { return false }
        return remainingCents > 0
    }

    private func applyRemainingAmount(to userID: String) {
        guard let remainingCents = remainingAmountForParticipant(userID), remainingCents > 0 else { return }
        editor.participantValues[userID] = ExpenseValidator.formatCents(remainingCents)
    }

    private func applySuggestedCategory(for expenseName: String) {
        guard !editor.hasManuallySelectedCategory else { return }

        let suggestedCategory = ExpenseCategoryAutoClassifier.suggestCategory(for: expenseName)
        guard suggestedCategory != editor.selectedCategory else { return }

        editor.isApplyingSuggestedCategory = true
        editor.selectedCategory = suggestedCategory
        editor.isApplyingSuggestedCategory = false
    }

    private func submit() {
        guard let request = submissionRequest else { return }
        if let editingExpenseID {
            expenseVM.updateExpense(
                expenseID: editingExpenseID,
                groupID: editor.selectedGroupID,
                request: request
            ) {
                completeSheet()
            }
        } else {
            expenseVM.createExpense(groupID: editor.selectedGroupID, request: request) {
                let createdGroupID = editor.selectedGroupID
                completeSheet()
                guard fixedGroupID == nil else { return }
                DispatchQueue.main.async {
                    navigationState.openExpenseGroup(createdGroupID)
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
}

private struct ExpenseLoadingStateView: View {
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
            Text(message)
                .foregroundStyle(AppTheme.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
    }
}

private struct ExpenseGroupSelectionView: View {
    @Binding var groupSearchText: String

    let filteredGroups: [AppGroup]
    let onSelectGroup: (AppGroup) -> Void

    var body: some View {
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
                        onSelectGroup(group)
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
}

private struct ExpenseFormView: View {
    let isEditing: Bool
    let fixedGroupID: String?
    let selectedGroup: AppGroup?
    let isLoadingSelectedGroup: Bool
    let selectedGroupMembers: [GroupMember]

    @Binding var draftName: String
    @Binding var selectedCategory: ExpenseCategory
    @Binding var draftAmount: String
    @Binding var draftNote: String
    @Binding var selectedOccurredAt: Date
    @Binding var selectedPayerID: String
    @Binding var splitMethod: ExpenseSplitMethod
    @Binding var showAdvancedOptions: Bool
    @Binding var selectedParticipantIDs: Set<String>

    let isShowingAdvancedOptions: Bool
    let isTransactionCategory: Bool
    let isAmountOptional: Bool
    let equalSummaryText: String
    let participantsSectionTitle: String
    let participantOptions: [GroupMember]
    let validationMessage: String?
    let fixedSplitRemainingText: String?
    let fixedSplitRemainingTint: Color
    let onChooseAnotherGroup: () -> Void
    let onToggleParticipant: (String) -> Void
    let participantValueBinding: (String) -> Binding<String>
    let canApplyRemainingAmount: (String) -> Bool
    let onApplyRemainingAmount: (String) -> Void

    var body: some View {
        Form {
            ExpenseGroupSectionView(
                selectedGroup: selectedGroup,
                isLoadingSelectedGroup: isLoadingSelectedGroup,
                isEditing: isEditing,
                fixedGroupID: fixedGroupID,
                onChooseAnotherGroup: onChooseAnotherGroup
            )
            ExpenseBasicsSectionView(
                draftName: $draftName,
                selectedCategory: $selectedCategory,
                draftAmount: $draftAmount,
                draftNote: $draftNote,
                selectedOccurredAt: $selectedOccurredAt,
                selectedPayerID: $selectedPayerID,
                selectedGroupMembers: selectedGroupMembers,
                isLoadingSelectedGroup: isLoadingSelectedGroup,
                isAmountOptional: isAmountOptional
            )
            ExpenseSimpleSplitSectionView(
                splitMethod: splitMethod,
                isShowingAdvancedOptions: isShowingAdvancedOptions,
                equalSummaryText: equalSummaryText,
                showAdvancedOptions: $showAdvancedOptions
            )
            ExpenseAdvancedSplitSectionView(
                isShowingAdvancedOptions: isShowingAdvancedOptions,
                isTransactionCategory: isTransactionCategory,
                splitMethod: $splitMethod,
                showAdvancedOptions: $showAdvancedOptions,
                isLoadingSelectedGroup: isLoadingSelectedGroup,
                selectedGroupMembers: selectedGroupMembers,
                participantOptions: participantOptions,
                selectedParticipantIDs: selectedParticipantIDs,
                participantsSectionTitle: participantsSectionTitle,
                participantValueBinding: participantValueBinding,
                onToggleParticipant: onToggleParticipant,
                fixedSplitRemainingText: fixedSplitRemainingText,
                fixedSplitRemainingTint: fixedSplitRemainingTint,
                canApplyRemainingAmount: canApplyRemainingAmount,
                onApplyRemainingAmount: onApplyRemainingAmount
            )
            ExpenseValidationSectionView(validationMessage: validationMessage)
        }
    }
}

private struct ExpenseGroupSectionView: View {
    let selectedGroup: AppGroup?
    let isLoadingSelectedGroup: Bool
    let isEditing: Bool
    let fixedGroupID: String?
    let onChooseAnotherGroup: () -> Void

    var body: some View {
        Section("Group") {
            Button(action: onChooseAnotherGroup) {
                if let selectedGroup {
                    GroupRowView(
                        groupName: selectedGroup.groupName,
                        remoteAvatarURL: selectedGroup.resolvedAvatarURL,
                        subtitle: isLoadingSelectedGroup ? "Loading members..." : nil,
                        avatarSize: ComponentMetrics.rowAvatarSize,
                        showsChevron: !isEditing && fixedGroupID == nil
                    )
                } else {
                    HStack(spacing: 12) {
                        if isLoadingSelectedGroup {
                            ProgressView()
                        } else {
                            Image(systemName: "person.3.fill")
                                .foregroundStyle(AppTheme.secondary)
                        }

                        Text(isLoadingSelectedGroup ? "Loading group..." : "Choose a group")
                            .foregroundStyle(AppTheme.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(isEditing || fixedGroupID != nil)
        }
    }
}

private struct ExpenseBasicsSectionView: View {
    @Binding var draftName: String
    @Binding var selectedCategory: ExpenseCategory
    @Binding var draftAmount: String
    @Binding var draftNote: String
    @Binding var selectedOccurredAt: Date
    @Binding var selectedPayerID: String

    let selectedGroupMembers: [GroupMember]
    let isLoadingSelectedGroup: Bool
    let isAmountOptional: Bool

    var body: some View {
        Section("Expense") {
            TextField("Expense name", text: $draftName)

            Picker("Category", selection: $selectedCategory) {
                ForEach(ExpenseCategory.allCases) { category in
                    Label(category.title, systemImage: category.symbol)
                        .tag(category)
                }
            }

            TextField(
                isAmountOptional ? "Total amount (optional)" : "Total amount",
                text: $draftAmount
            )
                .keyboardType(.decimalPad)

            TextField("Note (optional)", text: $draftNote, axis: .vertical)
                .lineLimit(1...3)

            DatePicker("Date", selection: $selectedOccurredAt, displayedComponents: .date)

            if isLoadingSelectedGroup {
                ExpenseLoadingMembersRow()
            } else {
                Picker("Paid by", selection: $selectedPayerID) {
                    Text("Select payer").tag("")
                    ForEach(selectedGroupMembers) { member in
                        Text(member.username).tag(member.id)
                    }
                }
            }
        }
    }
}

private struct ExpenseSimpleSplitSectionView: View {
    let splitMethod: ExpenseSplitMethod
    let isShowingAdvancedOptions: Bool
    let equalSummaryText: String
    @Binding var showAdvancedOptions: Bool

    @ViewBuilder
    var body: some View {
        if splitMethod == .equal && !isShowingAdvancedOptions {
            Section {
                Text(equalSummaryText)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondary)

                Button("More Options") {
                    showAdvancedOptions = true
                }
                .buttonStyle(CoListFilledButtonStyle(tone: .butter))
            }
        }
    }
}

private struct ExpenseAdvancedSplitSectionView: View {
    let isShowingAdvancedOptions: Bool
    let isTransactionCategory: Bool
    @Binding var splitMethod: ExpenseSplitMethod
    @Binding var showAdvancedOptions: Bool
    let isLoadingSelectedGroup: Bool

    let selectedGroupMembers: [GroupMember]
    let participantOptions: [GroupMember]
    let selectedParticipantIDs: Set<String>
    let participantsSectionTitle: String
    let participantValueBinding: (String) -> Binding<String>
    let onToggleParticipant: (String) -> Void
    let fixedSplitRemainingText: String?
    let fixedSplitRemainingTint: Color
    let canApplyRemainingAmount: (String) -> Bool
    let onApplyRemainingAmount: (String) -> Void

    @ViewBuilder
    var body: some View {
        if isShowingAdvancedOptions {
            Section("Split") {
                splitSectionContent
            }

            Section(participantsSectionTitle) {
                participantsSectionContent
            }
        }
    }

    @ViewBuilder
    private var splitSectionContent: some View {
        if isTransactionCategory {
            Text("Transaction uses exact recipient amounts.")
                .font(.footnote)
                .foregroundStyle(AppTheme.secondary)
        } else {
            Picker("Split Method", selection: $splitMethod) {
                ForEach(ExpenseSplitMethod.allCases) { method in
                    Text(method.title).tag(method)
                }
            }
            .pickerStyle(.segmented)

            if splitMethod == .equal {
                Button("Back to Simple View") {
                    showAdvancedOptions = false
                }
                .buttonStyle(CoListTextActionButtonStyle(tone: .secondary))
            } else if splitMethod == .fixed, let fixedSplitRemainingText {
                HStack {
                    Text("Remaining to assign")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(AppTheme.secondary)

                    Spacer()

                    Text(fixedSplitRemainingText)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(fixedSplitRemainingTint)
                }
            }
        }
    }

    @ViewBuilder
    private var participantsSectionContent: some View {
        if isLoadingSelectedGroup {
            ExpenseLoadingMembersRow()
        } else if selectedGroupMembers.isEmpty {
            Text("No members available.")
                .foregroundStyle(AppTheme.secondary)
        } else {
            ForEach(participantOptions) { member in
                ExpenseParticipantRow(
                    member: member,
                    isSelected: selectedParticipantIDs.contains(member.id),
                    splitMethod: splitMethod,
                    value: participantValueBinding(member.id),
                    canUseRemainingAmount: canApplyRemainingAmount(member.id),
                    onToggle: { onToggleParticipant(member.id) },
                    onUseRemainingAmount: {
                        onApplyRemainingAmount(member.id)
                    }
                )
            }
        }
    }
}

private struct ExpenseValidationSectionView: View {
    let validationMessage: String?

    @ViewBuilder
    var body: some View {
        if let validationMessage {
            Section {
                Text(validationMessage)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.blush)
            }
        }
    }
}

private struct ExpenseLoadingMembersRow: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Loading members...")
                .foregroundStyle(AppTheme.secondary)
        }
    }
}

private struct ExpenseParticipantRow: View {
    let member: GroupMember
    let isSelected: Bool
    let splitMethod: ExpenseSplitMethod
    @Binding var value: String
    let canUseRemainingAmount: Bool
    let onToggle: () -> Void
    let onUseRemainingAmount: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    CircularAvatarView(
                        image: nil,
                        remoteAvatarURL: member.resolvedAvatarURL,
                        size: ComponentMetrics.rowAvatarSize,
                        placeholderSystemImage: "person.fill"
                    )

                    Text(member.username)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)

                    Spacer(minLength: 12)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? AppTheme.primary : AppTheme.border)
                }
            }
            .buttonStyle(.plain)

            if splitMethod != .equal && isSelected {
                VStack(alignment: .leading, spacing: 8) {
                    TextField(
                        splitMethod == .percentage ? "e.g. 33.33" : "e.g. 28.50",
                        text: $value
                    )
                    .keyboardType(splitMethod.keyboardType)
                    .colistInputField()

                    if splitMethod == .fixed {
                        HStack {
                            Spacer()

                            Button("Balance") {
                                onUseRemainingAmount()
                            }
                            .buttonStyle(CoListTextActionButtonStyle(tone: .secondary))
                            .disabled(!canUseRemainingAmount)
                        }
                    }
                }
                .padding(.leading, ComponentMetrics.rowAvatarSize + 12)
            }
        }
    }
}
