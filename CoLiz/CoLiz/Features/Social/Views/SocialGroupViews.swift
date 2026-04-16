import SwiftUI

private func groupPossessiveTitle(_ groupName: String, suffix: String) -> String {
    let trimmed = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return suffix }
    if trimmed.lowercased().hasSuffix("s") {
        return "\(trimmed)' \(suffix)"
    }
    return "\(trimmed)'s \(suffix)"
}

struct GroupTodosView: View {
    @EnvironmentObject private var vm: TodoVM
    let group: AppGroup

    private var todos: [Todo] {
        vm.groupTodos(for: group.id)
    }

    private var isLoading: Bool {
        vm.loadingGroupTodoIDs.contains(group.id)
    }

    private var pendingCount: Int {
        todos.filter { !$0.done }.count
    }

    private var todoSummaryText: String {
        if isLoading && todos.isEmpty {
            return "Loading todos..."
        }
        if todos.isEmpty {
            return "No todos yet"
        }
        return "\(pendingCount) open · \(todos.count) total"
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    GroupRowView(
                        groupName: group.groupName,
                        remoteAvatarURL: group.resolvedAvatarURL,
                        subtitle: todoSummaryText,
                        avatarSize: 52,
                        verticalPadding: 0,
                        showsCard: false
                    )

                    todoCountCard
                }
                .padding(16)
                .colistCard(fill: AppTheme.surface, cornerRadius: ComponentMetrics.largeCardCornerRadius)
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
            }

            Section("Todos") {
                if isLoading && todos.isEmpty {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Loading todos...")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                } else if todos.isEmpty {
                    Text("No todos in this group yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(todos) { todo in
                        TodoRowView(
                            todo: todo,
                            remoteAvatarURL: group.resolvedAvatarURL,
                            subtitle: todoSubtitle(for: todo),
                            verticalPadding: 0
                        ) {
                            vm.toggle(id: todo.id)
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                }
            }
        }
        .navigationTitle(groupPossessiveTitle(group.groupName, suffix: "Todos"))
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .task {
            vm.fetchGroupTodos(groupID: group.id)
        }
    }

    private var todoCountCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Todo Snapshot")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)

            Text(todoSummaryText)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.primary.opacity(0.10))
        )
    }

    private func todoSubtitle(for todo: Todo) -> String {
        let creator = todo.createdByName.trimmingCharacters(in: .whitespacesAndNewlines)
        if creator.isEmpty {
            return todo.done ? "Completed" : "Pending"
        }
        return todo.done ? "Completed by \(creator)" : "Created by \(creator)"
    }
}

struct GroupExpenseSummaryView: View {
    @EnvironmentObject private var expenseVM: ExpenseViewModel

    let groupID: String
    var showsGroupLink: Bool = true
    @State private var isStatsExpanded = false
    @State private var editingExpense: EditableExpenseSheetTarget?
    @State private var isShowingCreateExpenseSheet = false
    @State private var searchText = ""
    @State private var isShowingSearch = false
    @FocusState private var isSearchFieldFocused: Bool

    private var group: AppGroup? {
        expenseVM.groups.first(where: { $0.id == groupID })
    }

    private var groupName: String {
        expenseVM.groupExpense(for: groupID)?.groupName ?? group?.groupName ?? "Expense Summary"
    }

    private var expenseHistory: [ExpenseHistoryItem] {
        expenseVM.groupExpenseHistory(for: groupID)
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredExpenseHistory: [ExpenseHistoryItem] {
        guard !trimmedSearchText.isEmpty else { return expenseHistory }
        return expenseHistory.filter(matchesExpenseSearch(_:))
    }

    private var filteredExpenseIDs: [String] {
        filteredExpenseHistory.map(\.id)
    }

    private var isLoadingHistory: Bool {
        expenseVM.loadingGroupExpenseHistoryIDs.contains(groupID)
    }

    private var transactionPlan: GroupTransactionPlan? {
        expenseVM.groupTransactionPlan(for: groupID)
    }

    private var isLoadingTransactionPlan: Bool {
        expenseVM.loadingGroupTransactionPlanIDs.contains(groupID)
    }

    private var isApplyingTransactionPlan: Bool {
        expenseVM.applyingGroupTransactionPlanIDs.contains(groupID)
    }

    private var primaryBalanceTitle: String {
        guard let expense = expenseVM.groupExpense(for: groupID) else { return "All settled up" }
        if expense.lentDecimal > .zero {
            return "You lent"
        }
        if expense.borrowDecimal > .zero {
            return "You borrowed"
        }
        return "All settled up"
    }

    private var primaryBalanceAmount: String {
        guard let expense = expenseVM.groupExpense(for: groupID) else { return "$0.00" }
        if expense.lentDecimal > .zero {
            return expense.formattedLentAmount
        }
        if expense.borrowDecimal > .zero {
            return expense.formattedBorrowAmount
        }
        return "$0.00"
    }

    private var primaryBalanceTint: Color {
        guard let expense = expenseVM.groupExpense(for: groupID) else { return .secondary }
        if expense.lentDecimal > .zero {
            return AppTheme.lent
        }
        if expense.borrowDecimal > .zero {
            return AppTheme.borrowed
        }
        return .secondary
    }

    var body: some View {
        List {
            if isShowingSearch {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(AppTheme.secondary)

                        TextField("Search expenses", text: $searchText)
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
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 4, trailing: 16))
                }
            }

            if let expense = expenseVM.groupExpense(for: groupID) {
                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        groupHeader(for: expense)

                        balanceCard(
                            title: primaryBalanceTitle,
                            amount: primaryBalanceAmount,
                            tint: primaryBalanceTint
                        )
                    }
                    .padding(16)
                    .colistCard(fill: AppTheme.surface, cornerRadius: ComponentMetrics.largeCardCornerRadius)
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                }

                Section {
                    if isStatsExpanded {
                        VStack(spacing: 10) {
                            if isLoadingHistory && expenseHistory.isEmpty {
                                HStack(spacing: 12) {
                                    ProgressView()
                                    Text("Preparing monthly breakdown...")
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .colistCard(fill: AppTheme.surface, cornerRadius: ComponentMetrics.largeCardCornerRadius)
                            } else {
                                MonthlyExpenseBreakdownCard(items: expenseHistory)
                            }

                            transactionPlanCard(for: expense)
                        }
                        .colistCardListRow(top: 10, bottom: 10)
                    }
                } header: {
                    Button {
                        withAnimation(.easeInOut(duration: 0.32)) {
                            isStatsExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Text("Stats")

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .rotationEffect(.degrees(isStatsExpanded ? 90 : 0))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .textCase(nil)
                }

                Section("Expenses") {
                    if isLoadingHistory && expenseHistory.isEmpty {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Loading expenses...")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                    } else if filteredExpenseHistory.isEmpty {
                        Text(trimmedSearchText.isEmpty ? "No expenses yet." : "No matching expenses.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredExpenseHistory) { item in
                            ExpenseHistoryRowView(item: item)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    
                                    Button(role: .destructive) {
                                        expenseVM.deleteExpense(groupID: groupID, expenseID: item.id)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .disabled(expenseVM.deletingExpenseIDs.contains(item.id))

                                    Button {
                                        expenseVM.fetchExpenseDetail(expenseID: item.id)
                                        editingExpense = EditableExpenseSheetTarget(
                                            groupID: groupID,
                                            expenseID: item.id
                                        )
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(AppTheme.secondary)
                                }
                        }
                    }
                }
            } else if expenseVM.isLoadingGroupExpenses {
                Section {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Loading expense summary...")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
            } else {
                ContentUnavailableView(
                    "No expense summary yet",
                    systemImage: "creditcard",
                    description: Text("This group's current balance will appear here once expenses exist.")
                )
            }
        }
        .navigationTitle(groupPossessiveTitle(groupName, suffix: "Expenses"))
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .animation(CoListMotion.sectionToggle, value: isShowingSearch)
        .animation(CoListMotion.sectionToggle, value: filteredExpenseIDs)
        .task {
            expenseVM.prefetchGroupExpensesIfNeeded()
            expenseVM.fetchGroupExpenseHistory(groupID: groupID)
            expenseVM.fetchGroupTransactionPlan(groupID: groupID)
        }
        .refreshable {
            await expenseVM.refreshGroupExpenseSummary(groupID: groupID)
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
                    isShowingCreateExpenseSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $isShowingCreateExpenseSheet) {
            NavigationStack {
                CreateExpenseSheetView(
                    fixedGroupID: groupID,
                    onSuccess: {
                        isShowingCreateExpenseSheet = false
                        Task {
                            await expenseVM.refreshGroupExpenseSummary(groupID: groupID)
                        }
                    }
                )
            }
        }
        .sheet(item: $editingExpense) { target in
            NavigationStack {
                CreateExpenseSheetView(
                    fixedGroupID: target.groupID,
                    editingExpenseID: target.expenseID,
                    onSuccess: {
                        editingExpense = nil
                        Task {
                            await expenseVM.refreshGroupExpenseSummary(groupID: target.groupID)
                        }
                    }
                )
            }
        }
    }

    private func matchesExpenseSearch(_ item: ExpenseHistoryItem) -> Bool {
        let keyword = trimmedSearchText
        guard !keyword.isEmpty else { return true }

        return item.name.localizedCaseInsensitiveContains(keyword)
            || item.paidByName.localizedCaseInsensitiveContains(keyword)
            || item.expenseCategory.title.localizedCaseInsensitiveContains(keyword)
            || item.amount.localizedCaseInsensitiveContains(keyword)
    }

    @ViewBuilder
    private func groupHeader(for expense: GroupExpense) -> some View {
        if showsGroupLink {
            NavigationLink {
                GroupDetailView(groupID: groupID)
            } label: {
                groupHeaderLabel(for: expense)
            }
            .buttonStyle(.plain)
        } else {
            groupHeaderLabel(for: expense)
        }
    }

    private func groupHeaderLabel(for expense: GroupExpense) -> some View {
        HStack(spacing: 12) {
            CircularAvatarView(
                image: nil,
                remoteAvatarURL: expense.resolvedAvatarURL,
                size: 52,
                placeholderSystemImage: "person.3.fill"
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(expense.groupName)
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
            }
        }
        .contentShape(Rectangle())
    }

    private func balanceCard(title: String, amount: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
            Text(amount)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.10))
        )
    }

    private func transactionPlanCard(for expense: GroupExpense) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(
                expense.borrowDecimal > .zero
                ? "Generate the group transfer plan, then apply it to write the required transaction expenses."
                : "Preview the full-group transfer plan and apply it when everyone is ready to settle up."
            )
            .font(.footnote)
            .foregroundStyle(AppTheme.secondary)

            if isLoadingTransactionPlan && transactionPlan == nil {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Generating transfer plan...")
                        .foregroundStyle(.secondary)
                }
            } else if let transactionPlan {
                if transactionPlan.transfers.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppTheme.secondary)
                        Text("Everyone in this group is already settled up.")
                            .foregroundStyle(AppTheme.secondary)
                    }
                } else {
                    VStack(spacing: 10) {
                        ForEach(transactionPlan.transfers) { transfer in
                            TransactionTransferRowView(transfer: transfer)
                        }
                    }
                }
            } else {
                Text("No transfer plan loaded yet.")
                    .foregroundStyle(AppTheme.secondary)
            }

            HStack(spacing: 12) {
                Button {
                    expenseVM.fetchGroupTransactionPlan(groupID: groupID, force: true)
                } label: {
                    Text(transactionPlan == nil ? "Generate Plan" : "Refresh Plan")
                }
                .buttonStyle(CoListTextActionButtonStyle(tone: .secondary))
                .disabled(isLoadingTransactionPlan || isApplyingTransactionPlan)

                if let transactionPlan, !transactionPlan.transfers.isEmpty {
                    Button {
                        expenseVM.applyGroupTransactionPlan(groupID: groupID)
                    } label: {
                        if isApplyingTransactionPlan {
                            ProgressView()
                        } else {
                            Text("Apply Transactions")
                        }
                    }
                    .buttonStyle(CoListFilledButtonStyle(tone: .butter))
                    .disabled(isApplyingTransactionPlan || isLoadingTransactionPlan)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .colistCard(fill: AppTheme.surface, cornerRadius: ComponentMetrics.largeCardCornerRadius)
    }
}

private struct EditableExpenseSheetTarget: Identifiable {
    let groupID: String
    let expenseID: String

    var id: String { expenseID }
}

private struct ExpenseHistoryRowView: View {
    let item: ExpenseHistoryItem

    private static let amountLocale = Locale(identifier: "en_US_POSIX")
    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = .current
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private var formattedAmount: String {
        let decimal = Decimal(string: item.amount, locale: Self.amountLocale) ?? .zero
        return Self.currencyFormatter.string(from: NSDecimalNumber(decimal: decimal)) ?? "$0.00"
    }

    private var formattedDay: String {
        Self.dayFormatter.string(from: item.occurredAt)
    }

    private var categorySymbol: String {
        item.categorySymbol.isEmpty ? item.expenseCategory.symbol : item.categorySymbol
    }

    private var personalBalanceText: String {
        if item.lentDecimal > .zero {
            return "You lent \(formatCurrency(item.lentDecimal))"
        }
        if item.borrowDecimal > .zero {
            return "You borrowed \(formatCurrency(item.borrowDecimal))"
        }
        return "You are settled up"
    }

    private var personalBalanceTint: Color {
        if item.lentDecimal > .zero {
            return AppTheme.lent
        }
        if item.borrowDecimal > .zero {
            return AppTheme.borrowed
        }
        return .secondary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(formattedAmount)
                    .font(.headline)
                Spacer()
                Text(personalBalanceText)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(personalBalanceTint)
            }

            HStack(spacing: 8) {
                Image(systemName: categorySymbol)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.secondary)

                Text(item.name)
                    .font(.subheadline.weight(.semibold))
            }

            HStack(spacing: 8) {
                CircularAvatarView(
                    image: nil,
                    remoteAvatarURL: item.paidByAvatarURL,
                    size: 22,
                    placeholderSystemImage: "person.fill",
                    placeholderImageScale: 0.38
                )

                Text("\(item.paidByName) paid at \(formattedDay)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        Self.currencyFormatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$0.00"
    }
}

private struct TransactionTransferRowView: View {
    let transfer: TransactionTransfer

    private static let amountLocale = Locale(identifier: "en_US_POSIX")
    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = .current
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    private var formattedAmount: String {
        let decimal = Decimal(string: transfer.amount, locale: Self.amountLocale) ?? .zero
        return Self.currencyFormatter.string(from: NSDecimalNumber(decimal: decimal)) ?? "$0.00"
    }

    var body: some View {
        HStack(spacing: 12) {
            CircularAvatarView(
                image: nil,
                remoteAvatarURL: transfer.fromAvatarURL,
                size: 28,
                placeholderSystemImage: "person.fill"
            )

            VStack(alignment: .leading, spacing: 2) {
                Text("\(transfer.fromUsername) pays \(transfer.toUsername)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                Text(formattedAmount)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppTheme.secondary)
            }

            Spacer(minLength: 12)

            CircularAvatarView(
                image: nil,
                remoteAvatarURL: transfer.toAvatarURL,
                size: 28,
                placeholderSystemImage: "person.fill"
            )
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.background.opacity(0.8))
        )
    }
}

#Preview {
    NavigationStack {
        GroupTodosView(group: AppGroup.mockList()[0])
    }
}
