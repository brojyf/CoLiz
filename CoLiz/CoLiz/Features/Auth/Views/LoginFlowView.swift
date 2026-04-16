//
//  LoginView.swift
//  CoList
//
//  Created by 江逸帆 on 2/14/26.
//

import SwiftUI

private enum AuthRoute: Hashable {
    case signUpEmail
    case signUpVerify(email: String)
    case signUpPassword(email: String)
    case resetEmail
    case resetVerify(email: String)
    case resetPassword(email: String)
}

struct LoginFlowView: View {
    @EnvironmentObject private var vm: LoginVM
    @State private var path = NavigationPath()
    @State private var didPrepare = false

    var body: some View {
        NavigationStack(path: $path) {
            LoginView(
                onSignUp: {
                    vm.startSignUpFlow()
                    path.append(AuthRoute.signUpEmail)
                },
                onForgotPassword: {
                    vm.startResetPasswordFlow()
                    path.append(AuthRoute.resetEmail)
                }
            )
            .navigationDestination(for: AuthRoute.self) { route in
                switch route {
                case .signUpEmail:
                    SignUpEmailView(
                        title: "Create your account",
                        subtitle: "Step 1/3: enter your email to receive a verification code.",
                        navigationTitle: "Signup",
                        actionTitle: "Send Code",
                        emailAccessibilityID: "auth.signup.email",
                        submitAccessibilityID: "auth.signup.sendCode",
                        onSubmit: { email, onSuccess in
                            vm.requestSignUpCode(email: email, onSuccess: onSuccess)
                        }
                    ) { email in
                        path.append(AuthRoute.signUpVerify(email: email))
                    }
                case let .signUpVerify(email):
                    SignUpVerifyCodeView(
                        email: email,
                        title: "Verify your email",
                        subtitle: "Step 2/3: enter the 6-digit code sent to \(email).",
                        navigationTitle: "Verify Code",
                        actionTitle: "Verify Code",
                        resendTitle: "Resend Code",
                        otpAccessibilityID: "auth.signup.otp",
                        submitAccessibilityID: "auth.signup.verifyCode",
                        resendAccessibilityID: "auth.signup.resendCode",
                        onSubmit: { email, otp, onSuccess in
                            vm.verifySignUpCode(email: email, otp: otp, onSuccess: onSuccess)
                        },
                        onResend: { email, onSuccess in
                            vm.requestSignUpCode(email: email, onSuccess: onSuccess)
                        }
                    ) {
                        path.append(AuthRoute.signUpPassword(email: email))
                    }
                case let .signUpPassword(email):
                    SignUpSetPasswordView(
                        email: email,
                        title: "Set your password",
                        subtitle: "Step 3/3: create a password for \(email).",
                        navigationTitle: "Set Password",
                        actionTitle: "Create Account",
                        passwordAccessibilityID: "auth.signup.password",
                        confirmPasswordAccessibilityID: "auth.signup.confirmPassword",
                        submitAccessibilityID: "auth.signup.createAccount",
                        requiresTermsAgreement: true,
                        onSubmit: { password in
                            vm.createAccount(password: password)
                        }
                    )
                case .resetEmail:
                    SignUpEmailView(
                        title: "Reset your password",
                        subtitle: "Step 1/3: enter your email to receive a verification code.",
                        navigationTitle: "Forgot Password",
                        actionTitle: "Send Code",
                        emailAccessibilityID: "auth.reset.email",
                        submitAccessibilityID: "auth.reset.sendCode",
                        onSubmit: { email, onSuccess in
                            vm.requestResetCode(email: email, onSuccess: onSuccess)
                        }
                    ) { email in
                        path.append(AuthRoute.resetVerify(email: email))
                    }
                case let .resetVerify(email):
                    SignUpVerifyCodeView(
                        email: email,
                        title: "Verify your email",
                        subtitle: "Step 2/3: enter the 6-digit code sent to \(email).",
                        navigationTitle: "Verify Code",
                        actionTitle: "Verify Code",
                        resendTitle: "Resend Code",
                        otpAccessibilityID: "auth.reset.otp",
                        submitAccessibilityID: "auth.reset.verifyCode",
                        resendAccessibilityID: "auth.reset.resendCode",
                        onSubmit: { email, otp, onSuccess in
                            vm.verifyResetCode(email: email, otp: otp, onSuccess: onSuccess)
                        },
                        onResend: { email, onSuccess in
                            vm.requestResetCode(email: email, onSuccess: onSuccess)
                        }
                    ) {
                        path.append(AuthRoute.resetPassword(email: email))
                    }
                case let .resetPassword(email):
                    SignUpSetPasswordView(
                        email: email,
                        title: "Set your new password",
                        subtitle: "Step 3/3: create a new password for \(email).",
                        navigationTitle: "Set Password",
                        actionTitle: "Reset Password",
                        passwordAccessibilityID: "auth.reset.password",
                        confirmPasswordAccessibilityID: "auth.reset.confirmPassword",
                        submitAccessibilityID: "auth.reset.submit",
                        requiresTermsAgreement: false,
                        onSubmit: { password in
                            vm.resetPassword(password: password)
                        }
                    )
                }
            }
        }
        .onAppear {
            guard !didPrepare else { return }
            didPrepare = true
            vm.prepareForLoginEntry()
            path = NavigationPath()
        }
    }
}

#Preview {
    let store = DefaultAuthStore()
    let base = BaseClient()
    let refresher = DefaultAuthRefresher(c: base)
    let tokenProvider = DefaultTokenProvider(store: store, refresher: refresher)
    let authState = AuthStateStore(tp: tokenProvider)
    let presenter = ErrorPresenter()
    let authService = AuthService(c: base, store: store)

    LoginFlowView()
        .environmentObject(LoginVM(s: authService, tp: tokenProvider, auth: authState, ep: presenter))
}
