import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var auth: AuthStateStore
    @EnvironmentObject private var languageStore: LanguageStore
    @EnvironmentObject private var profileVM: ProfileVM
    @State private var showProfileDetail = false
    @State private var showExpenseNameMapping = false

    var body: some View {
        List {
            Section {
                Button {
                    showProfileDetail = true
                } label: {
                    ProfileSummaryRow(profile: profileVM.profile)
                        .colistRowCard(fill: AppTheme.surface, verticalPadding: 14)
                        .colistReveal(yOffset: 16, startScale: 0.992)
                }
                .buttonStyle(.plain)
                .colistCardListRow()
            }

            Section(languageStore.text(.settingsSectionTitle)) {
                Button {
                    showExpenseNameMapping = true
                } label: {
                    HStack(spacing: 14) {
                        Text(languageStore.text(.expenseNameMapping))
                            .font(.headline)
                            .foregroundStyle(AppTheme.secondary)

                        Spacer()

                        CoListDisclosureIndicator()
                    }
                    .colistRowCard(fill: AppTheme.surface, verticalPadding: 14)
                }
                .buttonStyle(.plain)
                .colistCardListRow()
            }

            Section(languageStore.text(.signOutSectionTitle)) {
                Button(languageStore.text(.signOutButton), role: .destructive) {
                    auth.signOut()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .colistRowCard(fill: AppTheme.surface, verticalPadding: 14)
                .colistReveal(animation: CoListMotion.screenReveal.delay(0.08), yOffset: 18, startScale: 0.992)
                .accessibilityIdentifier("profile.signOut")
                .colistCardListRow()
            }
        }
        .listStyle(.plain)
        .listSectionSpacing(.compact)
        .contentMargins(.top, 0, for: .scrollContent)
        .navigationTitle(languageStore.text(.profileTitle))
        .scrollContentBackground(.hidden)
        .colistScreenBackground()
        .navigationDestination(isPresented: $showProfileDetail) {
            ProfileDetailView()
        }
        .navigationDestination(isPresented: $showExpenseNameMapping) {
            ExpenseNameMappingView()
        }
        .task {
            profileVM.loadProfileIfNeeded()
        }
        .refreshable {
            profileVM.loadProfile()
        }
    }
}

private struct ProfileSummaryRow: View {
    @EnvironmentObject private var languageStore: LanguageStore
    let profile: UserProfile?

    var body: some View {
        HStack(spacing: 14) {
            CircularAvatarView(
                image: nil,
                remoteAvatarURL: profile?.resolvedAvatarURL,
                size: 54,
                placeholderSystemImage: "person.crop.circle.fill"
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(profile?.username ?? languageStore.text(.loadingProfile))
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)

                if let email = profile?.email, !email.isEmpty {
                    Text(email)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondary)
                        .lineLimit(1)
                } else {
                    Text(languageStore.text(.tapToViewProfileDetails))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondary)
                }
            }

            Spacer()

            if profile == nil {
                ProgressView()
                    .controlSize(.small)
            }

            CoListDisclosureIndicator()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let store = DefaultAuthStore()
    let base = BaseClient()
    let refresher = DefaultAuthRefresher(c: base)
    let tp = DefaultTokenProvider(store: store, refresher: refresher)
    let authedClient = AuthedClient(base: base, tp: tp)
    let profileService = ProfileService(c: authedClient, tp: tp)
    let presenter = ErrorPresenter()
    let auth = AuthStateStore(tp: tp, initialState: .signedIn)

    NavigationStack {
        ProfileView()
    }
    .environmentObject(auth)
    .environmentObject(LanguageStore())
    .environmentObject(ProfileVM(s: profileService, ep: presenter))
}
