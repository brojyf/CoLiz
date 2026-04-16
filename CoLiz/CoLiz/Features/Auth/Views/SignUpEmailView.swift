import SwiftUI

struct SignUpEmailView: View {
    @EnvironmentObject private var vm: LoginVM
    @State private var email = ""

    let title: String
    let subtitle: String
    let navigationTitle: String
    let actionTitle: String
    let emailAccessibilityID: String
    let submitAccessibilityID: String
    let onSubmit: (String, @escaping @MainActor () -> Void) -> Void
    let onNext: (String) -> Void

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack {
            Spacer()

            VStack(alignment: .leading, spacing: 18) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.ink.opacity(0.68))
                    .frame(maxWidth: .infinity, alignment: .leading)

                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .keyboardType(.emailAddress)
                    .colistInputField()
                    .accessibilityIdentifier(emailAccessibilityID)

                Button {
                    onSubmit(trimmedEmail) { @MainActor in
                        onNext(trimmedEmail)
                    }
                } label: {
                    if vm.isLoading {
                        ProgressView()
                            .tint(AppTheme.onBrand)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(actionTitle)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(CoListFilledButtonStyle())
                .disabled(vm.isLoading || trimmedEmail.isEmpty)
                .accessibilityIdentifier(submitAccessibilityID)
            }
            .padding(24)
            .colistCard(cornerRadius: ComponentMetrics.largeCardCornerRadius)
            .colistReveal(yOffset: 28, startScale: 0.975)

            Spacer()
        }
        .padding(20)
        .colistScreenBackground()
        .navigationTitle(navigationTitle)
    }
}
