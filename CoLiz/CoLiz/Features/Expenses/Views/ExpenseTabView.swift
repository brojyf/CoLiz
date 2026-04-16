import SwiftUI

struct ExpenseTabView: View {
    @EnvironmentObject private var languageStore: LanguageStore

    var body: some View {
        NavigationStack {
            ExpenseListView()
        }
        .tabItem {
            Label(languageStore.text(.expenseTab), systemImage: "creditcard")
        }
    }
}
