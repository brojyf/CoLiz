import SwiftUI

struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                Text("Effective Date: [Insert Date]")
                Text("Operator: [Insert Legal Entity Name]")
            }

            termsSection(
                "Scope of Service",
                [
                    "CoList is a collaboration app for friends, groups, shared todos, and shared expenses.",
                    "The service may include account registration, sign-in, password reset, profile management, friend requests, group management, todo tracking, expense tracking, and settlement planning.",
                    "Features may change over time."
                ]
            )

            termsSection(
                "Accounts and Security",
                [
                    "You must provide accurate account information and keep it up to date.",
                    "You are responsible for your password, verification codes, sessions, and activity under your account.",
                    "You may not transfer, sell, lend, or share your account with another person.",
                    "If you suspect unauthorized access, you must change your password promptly."
                ]
            )

            termsSection(
                "User Content",
                [
                    "You are responsible for content you create or upload, including usernames, avatars, friend requests, group names, todos, expense details, notes, and related data.",
                    "You must have the rights to any content you upload.",
                    "You may not upload unlawful, infringing, abusive, deceptive, or harmful content."
                ]
            )

            termsSection(
                "Friends, Groups, and Shared Collaboration",
                [
                    "Group members may be able to view and interact with shared todos, expenses, balances, and related group data.",
                    "You should only invite people where you have a legitimate social or collaboration purpose.",
                    "You are responsible for deciding what information you share with other users.",
                    "Disputes between users are the responsibility of the users involved."
                ]
            )

            termsSection(
                "Expense Disclaimer",
                [
                    "CoList is an organizational and calculation tool only.",
                    "CoList is not a bank, payment processor, legal adviser, tax adviser, or financial institution.",
                    "Expense balances, splits, and settlement suggestions depend on user input and may be inaccurate if the input is inaccurate.",
                    "Real-world money transfers and reimbursements happen entirely between users and at their own risk."
                ]
            )

            termsSection(
                "Prohibited Use",
                [
                    "You may not use CoList to violate the law, harass others, send spam, impersonate another person, abuse the service, scrape data, reverse engineer the app, or exploit bugs.",
                    "You may not use CoList for fraud, deceptive activity, unlawful financial activity, or malicious conduct."
                ]
            )

            termsSection(
                "Availability and Data",
                [
                    "CoList is provided on an \"as is\" and \"as available\" basis.",
                    "We do not guarantee uninterrupted service, error-free operation, or permanent data availability.",
                    "You should keep your own records if todo or expense data is important to you."
                ]
            )

            termsSection(
                "Privacy",
                [
                    "CoList may process account, profile, friend, group, todo, expense, avatar, and verification email data as necessary to operate the service.",
                    "Your use of CoList is also subject to the Privacy Policy when one is provided."
                ]
            )

            termsSection(
                "Intellectual Property",
                [
                    "The CoList service, software, design, branding, and related materials belong to the operator or its licensors.",
                    "You may not copy, sell, reverse engineer, or otherwise exploit the service except as permitted by law or with written permission.",
                    "You retain ownership of content you submit, but you grant CoList the limited rights needed to host, process, and display it to operate the service."
                ]
            )

            termsSection(
                "Liability and Termination",
                [
                    "CoList may suspend or terminate accounts that violate these terms or create legal, security, or operational risk.",
                    "To the maximum extent permitted by law, CoList is not liable for indirect, incidental, special, consequential, or punitive damages.",
                    "CoList is not responsible for disputes between users relating to todos, expenses, repayment expectations, invitations, or offline conduct."
                ]
            )

            termsSection(
                "Governing Law and Contact",
                [
                    "These Terms are governed by the laws of [Insert Jurisdiction].",
                    "Disputes will be resolved in [Insert Venue], unless applicable law requires otherwise.",
                    "Contact: [Insert Contact Email]"
                ]
            )
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }

    private func termsSection(_ title: String, _ paragraphs: [String]) -> some View {
        Section(title) {
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.ink)
                    .padding(.vertical, 2)
            }
        }
    }
}

#Preview {
    NavigationStack {
        TermsOfServiceView()
    }
}
