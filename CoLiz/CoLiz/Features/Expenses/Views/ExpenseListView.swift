import SwiftUI

private struct ExpenseNavigationTarget: Identifiable, Hashable {
    let id = UUID()
    let groupID: String
}

struct ExpenseListView: View {
    @EnvironmentObject private var expenseVM: ExpenseViewModel
    @EnvironmentObject private var navigationState: MainTabNavigationState
    @State private var selectedExpenseGroup: ExpenseNavigationTarget?
    @State private var isShowingCreateExpenseSheet = false
    @State private var searchText = ""
    @State private var isShowingSearch = false
    @FocusState private var isSearchFieldFocused: Bool

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredGroupExpenses: [GroupExpense] {
        guard !trimmedSearchText.isEmpty else { return expenseVM.groupExpenses }
        return expenseVM.groupExpenses.filter(matchesSearch(_:))
    }

    private var groupExpenseIDs: [String] {
        filteredGroupExpenses.map(\.id)
    }

    var body: some View {
        List {
            if isShowingSearch {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(AppTheme.secondary)

                        TextField("Search expense groups", text: $searchText)
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

            Section {
                if expenseVM.isLoadingGroupExpenses && expenseVM.groupExpenses.isEmpty {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Loading balances...")
                            .foregroundStyle(AppTheme.secondary)
                    }
                    .colistRowCard(fill: AppTheme.surface, horizontalPadding: 16, verticalPadding: 18)
                    .colistReveal(yOffset: 14, startScale: 0.994)
                    .colistCardListRow()
                } else if filteredGroupExpenses.isEmpty {
                    ContentUnavailableView(
                        trimmedSearchText.isEmpty ? "No expenses yet" : "No matching groups",
                        systemImage: "creditcard",
                        description: Text(
                            trimmedSearchText.isEmpty
                            ? "Your group balances will show up here."
                            : "Try another keyword."
                        )
                    )
                    .colistReveal(yOffset: 14, startScale: 0.994)
                    .colistCardListRow()
                } else {
                    ForEach(Array(filteredGroupExpenses.enumerated()), id: \.element.id) { index, expense in
                        Button {
                            selectedExpenseGroup = ExpenseNavigationTarget(groupID: expense.id)
                        } label: {
                            ExpenseBalanceRowView(expense: expense, showsChevron: true)
                                .colistReveal(animation: CoListMotion.stagger(at: index), yOffset: 18, startScale: 0.992)
                        }
                        .buttonStyle(.plain)
                        .colistCardListRow()
                    }
                }
            } header: {
                HStack {
                    Text("My Group Balances")
                    Spacer()
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
                        Image(systemName: isShowingSearch ? "magnifyingglass.circle.fill" : "magnifyingglass")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listStyle(.plain)
        .listSectionSpacing(.compact)
        .contentMargins(.top, 0, for: .scrollContent)
        .navigationTitle("Expenses")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .colistScreenBackground()
        .navigationDestination(item: $selectedExpenseGroup) { target in
            GroupExpenseSummaryView(groupID: target.groupID)
        }
        .animation(CoListMotion.sectionToggle, value: isShowingSearch)
        .animation(CoListMotion.sectionToggle, value: groupExpenseIDs)
        .task {
            expenseVM.prefetchGroupExpensesIfNeeded()
            handlePendingExpenseNavigation()
        }
        .refreshable {
            await expenseVM.refreshExpenses()
        }
        .onChange(of: navigationState.expenseGroupIDToOpen) { _, _ in
            handlePendingExpenseNavigation()
        }
        .toolbar {
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
                CreateExpenseSheetView()
            }
        }
    }

    private func handlePendingExpenseNavigation() {
        guard let groupID = navigationState.expenseGroupIDToOpen else { return }
        selectedExpenseGroup = ExpenseNavigationTarget(groupID: groupID)
        navigationState.consumeExpenseGroup()
    }

    private func matchesSearch(_ expense: GroupExpense) -> Bool {
        let keyword = trimmedSearchText
        guard !keyword.isEmpty else { return true }

        return expense.groupName.localizedCaseInsensitiveContains(keyword)
            || expense.summaryText.localizedCaseInsensitiveContains(keyword)
    }
}

private struct ExpenseBalanceRowView: View {
    let expense: GroupExpense
    var showsChevron = false
    var showsCard = true

    private var balanceText: String {
        if expense.lentDecimal > .zero {
            return "You lent \(expense.balanceAmountText)"
        }
        if expense.borrowDecimal > .zero {
            return "You borrowed \(expense.balanceAmountText)"
        }
        return "All settled up"
    }

    var body: some View {
        HStack(spacing: ComponentMetrics.rowSpacing) {
            CircularAvatarView(
                image: nil,
                remoteAvatarURL: expense.resolvedAvatarURL,
                size: ComponentMetrics.rowAvatarSize,
                placeholderSystemImage: "person.3.fill"
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(expense.groupName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Text(balanceText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(expense.balanceTint)

            if showsChevron {
                CoListDisclosureIndicator()
            }
        }
        .modifier(ExpenseBalanceRowCardModifier(showsCard: showsCard))
    }
}

private struct ExpenseBalanceRowCardModifier: ViewModifier {
    let showsCard: Bool

    func body(content: Content) -> some View {
        if showsCard {
            content.colistRowCard(fill: AppTheme.surface, verticalPadding: 14)
        } else {
            content.padding(.vertical, 4)
        }
    }
}
