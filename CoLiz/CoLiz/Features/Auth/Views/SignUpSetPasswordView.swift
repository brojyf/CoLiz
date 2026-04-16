import SwiftUI

struct SignUpSetPasswordView: View {
    @EnvironmentObject private var vm: LoginVM

    let email: String
    let title: String
    let subtitle: String
    let navigationTitle: String
    let actionTitle: String
    let passwordAccessibilityID: String
    let confirmPasswordAccessibilityID: String
    let submitAccessibilityID: String
    var requiresTermsAgreement = false
    let onSubmit: (String) -> Void

    @State private var password = ""
    @State private var passwordConfirmation = ""
    @State private var hasAcceptedTerms = false
    @State private var isShowingTermsOfService = false

    private var trimmedPassword: String {
        password.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedPasswordConfirmation: String {
        passwordConfirmation.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasUpperAndLowercase: Bool {
        trimmedPassword.rangeOfCharacter(from: .uppercaseLetters) != nil
            && trimmedPassword.rangeOfCharacter(from: .lowercaseLetters) != nil
    }

    private var hasDigit: Bool {
        trimmedPassword.rangeOfCharacter(from: .decimalDigits) != nil
    }

    private var hasSymbol: Bool {
        let symbols = CharacterSet.punctuationCharacters.union(.symbols)
        return trimmedPassword.rangeOfCharacter(from: symbols) != nil
    }

    private var hasValidLength: Bool {
        trimmedPassword.count >= 8 && trimmedPassword.count <= 20
    }

    private var passwordsMatch: Bool {
        !trimmedPassword.isEmpty
            && trimmedPassword == trimmedPasswordConfirmation
    }

    private var canCreateAccount: Bool {
        hasValidLength
            && hasUpperAndLowercase
            && hasDigit
            && hasSymbol
            && passwordsMatch
            && (!requiresTermsAgreement || hasAcceptedTerms)
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

                SecureField("Password", text: $password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .colistInputField()
                    .accessibilityIdentifier(passwordAccessibilityID)

                SecureField("Confirm Password", text: $passwordConfirmation)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .colistInputField()
                    .accessibilityIdentifier(confirmPasswordAccessibilityID)

                VStack(alignment: .leading, spacing: 10) {
                    PasswordRequirementRow(
                        title: "8-20 characters",
                        isSatisfied: hasValidLength
                    )
                    PasswordRequirementRow(
                        title: "At least one upper case and one lower case character",
                        isSatisfied: hasUpperAndLowercase
                    )
                    PasswordRequirementRow(
                        title: "At least one digit",
                        isSatisfied: hasDigit
                    )
                    PasswordRequirementRow(
                        title: "At least one special symbol",
                        isSatisfied: hasSymbol
                    )
                    PasswordRequirementRow(
                        title: "Same password.",
                        isSatisfied: passwordsMatch,
                        isPending: trimmedPasswordConfirmation.isEmpty
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .colistCard(fill: AppTheme.creamStrong.opacity(0.5), cornerRadius: 16)

                if requiresTermsAgreement {
                    VStack(alignment: .leading, spacing: 10) {
                        Button {
                            hasAcceptedTerms.toggle()
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: hasAcceptedTerms ? "checkmark.square.fill" : "square")
                                    .font(.headline)
                                    .foregroundStyle(hasAcceptedTerms ? AppTheme.primary : AppTheme.border)

                                Text("I agree to the Terms of Service.")
                                    .font(.footnote)
                                    .foregroundStyle(AppTheme.ink.opacity(0.78))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("auth.signup.acceptTerms")

                        Button("Read Terms of Service") {
                            isShowingTermsOfService = true
                        }
                        .buttonStyle(CoListTextActionButtonStyle(tone: .secondary))
                        .accessibilityIdentifier("auth.signup.readTerms")
                    }
                }

                Button {
                    onSubmit(trimmedPassword)
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
                .disabled(vm.isLoading || !canCreateAccount)
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
        .sheet(isPresented: $isShowingTermsOfService) {
            NavigationStack {
                TermsOfServiceView()
            }
        }
    }
}

private struct PasswordRequirementRow: View {
    let title: String
    let isSatisfied: Bool
    var isPending = false

    private var iconName: String {
        if isPending {
            return "circle"
        }
        return isSatisfied ? "checkmark.circle.fill" : "xmark.circle.fill"
    }

    private var iconColor: Color {
        if isPending {
            return AppTheme.border
        }
        return isSatisfied ? AppTheme.secondary : .red
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)

            Text(title)
                .font(.footnote)
                .foregroundStyle(AppTheme.ink.opacity(0.72))
        }
    }
}
