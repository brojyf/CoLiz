import SwiftUI

struct SignUpVerifyCodeView: View {
    @EnvironmentObject private var vm: LoginVM

    let email: String
    let title: String
    let subtitle: String
    let navigationTitle: String
    let actionTitle: String
    let resendTitle: String
    let otpAccessibilityID: String
    let submitAccessibilityID: String
    let resendAccessibilityID: String
    let onSubmit: (String, String, @escaping @MainActor () -> Void) -> Void
    let onResend: (String, @escaping @MainActor () -> Void) -> Void
    let onNext: () -> Void

    @State private var otp = ""

    private var trimmedOTP: String {
        otp.trimmingCharacters(in: .whitespacesAndNewlines)
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

                TextField("6-digit Code", text: $otp)
                    .keyboardType(.numberPad)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .colistInputField()
                    .accessibilityIdentifier(otpAccessibilityID)

                Button {
                    onSubmit(email, trimmedOTP, { @MainActor in
                        onNext()
                    })
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
                .disabled(vm.isLoading || trimmedOTP.count != 6)
                .accessibilityIdentifier(submitAccessibilityID)

                Button(resendTitle) {
                    onResend(email) { @MainActor in }
                }
                .buttonStyle(CoListTextActionButtonStyle(tone: .secondary))
                .disabled(vm.isLoading)
                .accessibilityIdentifier(resendAccessibilityID)
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
