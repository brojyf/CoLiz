import SwiftUI

struct SocialTabView: View {
    @EnvironmentObject private var languageStore: LanguageStore

    var body: some View {
        NavigationStack {
            SocialHomeView()
        }
        .tabItem {
            Label(languageStore.text(.socialTab), systemImage: "person.3")
        }
    }
}
