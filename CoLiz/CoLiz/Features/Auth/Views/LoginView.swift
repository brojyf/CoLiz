import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var vm: LoginVM

    let onSignUp: () -> Void
    let onForgotPassword: () -> Void

    @State private var email = ""
    @State private var password = ""

    private var canLogin: Bool {
        !trimmedEmail.isEmpty && !trimmedPassword.isEmpty
    }

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedPassword: String {
        password.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 24)

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome to CoList")
                        .font(.title.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)
                        .accessibilityIdentifier("auth.login.title")
                }

                VStack(spacing: 14) {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .keyboardType(.emailAddress)
                        .textContentType(.username)
                        .colistInputField()
                        .accessibilityIdentifier("auth.login.email")

                    SecureField("Password", text: $password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .textContentType(.password)
                        .colistInputField()
                        .accessibilityIdentifier("auth.login.password")

                    Button {
                        vm.login(email: trimmedEmail, password: trimmedPassword)
                    } label: {
                        if vm.isLoading {
                            ProgressView()
                                .tint(AppTheme.onBrand)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Login")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(CoListFilledButtonStyle())
                    .disabled(vm.isLoading || !canLogin)
                    .accessibilityIdentifier("auth.login.submit")
                }

                HStack {
                    Button("Forgot Password", action: onForgotPassword)
                        .buttonStyle(CoListTextActionButtonStyle(tone: .secondary))
                        .disabled(vm.isLoading)
                        .accessibilityIdentifier("auth.login.forgotPassword")

                    Spacer()

                    Button("Signup", action: onSignUp)
                        .buttonStyle(CoListTextActionButtonStyle())
                        .disabled(vm.isLoading)
                        .accessibilityIdentifier("auth.login.signup")
                }
            }
            .padding(24)
            .colistCard(cornerRadius: ComponentMetrics.largeCardCornerRadius)
            .colistReveal(yOffset: 28, startScale: 0.975)

            Spacer()
        }
        .padding(20)
        .colistScreenBackground()
    }
}
