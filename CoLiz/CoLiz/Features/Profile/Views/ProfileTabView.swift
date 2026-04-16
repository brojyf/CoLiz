import SwiftUI

struct ProfileTabView: View {
    @EnvironmentObject private var languageStore: LanguageStore

    var body: some View {
        NavigationStack {
            ProfileView()
        }
        .tabItem {
            Label(languageStore.text(.profileTab), systemImage: "person.crop.circle")
        }
    }
}
