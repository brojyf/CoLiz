import SwiftUI

struct TodoTabView: View {
    @EnvironmentObject private var languageStore: LanguageStore

    var body: some View {
        NavigationStack {
            TodoView()
        }
        .tabItem {
            Label(languageStore.text(.todoTab), systemImage: "checklist")
        }
    }
}
