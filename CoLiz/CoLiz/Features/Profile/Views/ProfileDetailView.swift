import PhotosUI
import SwiftUI
import UIKit

@MainActor
struct ProfileDetailView: View {
    @EnvironmentObject private var languageStore: LanguageStore
    @EnvironmentObject private var profileVM: ProfileVM

    @State private var showChangePassword = false
    @State private var username = ""
    @State private var email = ""
    @State private var avatarImage: UIImage?
    @State private var draftUsername = ""
    @State private var isUsernameEditorPresented = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var pendingAvatarCrop: AvatarCropRequest?

    var body: some View {
        let currentAvatarImage = avatarImage
        let currentRemoteAvatarURL = profileVM.profile?.resolvedAvatarURL
        let isUploadingAvatar = profileVM.isUploadingAvatar
        let isUpdatingUsername = profileVM.isUpdatingUsername

        return List {
            Section {
                PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                    HStack(spacing: 16) {
                        Text(languageStore.text(.avatar))
                            .foregroundStyle(AppTheme.ink)

                        Spacer()

                        ZStack {
                            CircularAvatarView(
                                image: currentAvatarImage,
                                remoteAvatarURL: currentRemoteAvatarURL,
                                size: 56,
                                placeholderSystemImage: "camera.fill"
                            )

                            if isUploadingAvatar {
                                Circle()
                                    .fill(AppTheme.surface.opacity(0.92))
                                    .frame(width: 56, height: 56)

                                ProgressView()
                                    .controlSize(.small)
                            }
                        }

                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.border)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .disabled(isUploadingAvatar)

                Button {
                    openUsernameEditor()
                } label: {
                    HStack {
                        Text(languageStore.text(.name))
                            .foregroundStyle(AppTheme.ink)

                        Spacer()

                        Text(username)
                            .foregroundStyle(AppTheme.secondary)
                            .lineLimit(1)

                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.border)
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("profile.editUsername")

                LabeledContent(languageStore.text(.email), value: email)

                Button {
                    showChangePassword = true
                } label: {
                    HStack {
                        Text(languageStore.text(.changePassword))
                            .foregroundStyle(AppTheme.ink)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.border)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("profile.changePassword")
            }

        }
        .navigationTitle(languageStore.text(.personalInfoTitle))
        .navigationDestination(isPresented: $showChangePassword) {
            ChangePasswordView()
        }
        .scrollContentBackground(.hidden)
        .colistScreenBackground()
        .colistReveal(yOffset: 14, startScale: 0.994)
        .task {
            profileVM.loadProfileIfNeeded()
            syncProfile()
        }
        .onChange(of: profileVM.profile) { _, _ in
            syncProfile()
        }
        .onChange(of: selectedPhoto) { _, newValue in
            handleSelectedPhoto(newValue)
        }
        .onChange(of: avatarImage) { _, newValue in
            guard
                let newValue,
                let data = AvatarUploadImageProcessor.prepareJPEGData(from: newValue)
            else { return }
            profileVM.uploadAvatar(data: data)
        }
        .sheet(item: $pendingAvatarCrop) { request in
            SquareAvatarCropperSheet(
                image: request.image,
                onCancel: {
                    pendingAvatarCrop = nil
                },
                onConfirm: { croppedImage in
                    avatarImage = croppedImage
                    pendingAvatarCrop = nil
                }
            )
        }
        .alert(languageStore.text(.editNameTitle), isPresented: $isUsernameEditorPresented) {
            TextField(languageStore.text(.editNamePlaceholder), text: $draftUsername)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)

            Button(languageStore.text(.cancel), role: .cancel) {}

            Button(isUpdatingUsername ? languageStore.text(.saving) : languageStore.text(.save)) {
                submitUsernameUpdate()
            }
            .disabled(!canSubmitUsername || isUpdatingUsername)
        } message: {
            Text(languageStore.text(.updateProfileNameMessage))
        }
    }

    private func syncProfile() {
        guard let profile = profileVM.profile else { return }
        username = profile.username
        email = profile.email
        if !isUsernameEditorPresented {
            draftUsername = profile.username
        }
    }

    private func openUsernameEditor() {
        draftUsername = username
        isUsernameEditorPresented = true
    }

    private func submitUsernameUpdate() {
        let trimmed = draftUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        profileVM.updateUsername(trimmed) {
            isUsernameEditorPresented = false
        }
    }

    private func handleSelectedPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }

        Task {
            guard
                let data = try? await item.loadTransferable(type: Data.self),
                let image = UIImage(data: data)
            else {
                await MainActor.run {
                    selectedPhoto = nil
                }
                return
            }

            await MainActor.run {
                pendingAvatarCrop = AvatarCropRequest(image: image)
                selectedPhoto = nil
            }
        }
    }

    private var canSubmitUsername: Bool {
        !draftUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageStore: LanguageStore
    @EnvironmentObject private var profileVM: ProfileVM

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""

    private var trimmedCurrentPassword: String {
        currentPassword.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedNewPassword: String {
        newPassword.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedConfirmPassword: String {
        confirmPassword.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasUpperAndLowercase: Bool {
        trimmedNewPassword.rangeOfCharacter(from: .uppercaseLetters) != nil
            && trimmedNewPassword.rangeOfCharacter(from: .lowercaseLetters) != nil
    }

    private var hasDigit: Bool {
        trimmedNewPassword.rangeOfCharacter(from: .decimalDigits) != nil
    }

    private var hasSymbol: Bool {
        let symbols = CharacterSet.punctuationCharacters.union(.symbols)
        return trimmedNewPassword.rangeOfCharacter(from: symbols) != nil
    }

    private var hasValidLength: Bool {
        trimmedNewPassword.count >= 8 && trimmedNewPassword.count <= 20
    }

    private var passwordsMatch: Bool {
        !trimmedNewPassword.isEmpty && trimmedNewPassword == trimmedConfirmPassword
    }

    private var canSubmit: Bool {
        !trimmedCurrentPassword.isEmpty
            && hasValidLength
            && hasUpperAndLowercase
            && hasDigit
            && hasSymbol
            && passwordsMatch
    }

    var body: some View {
        Form {
            Section(languageStore.text(.currentPasswordSectionTitle)) {
                SecureField(languageStore.text(.currentPasswordPlaceholder), text: $currentPassword)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            }

            Section(languageStore.text(.newPasswordSectionTitle)) {
                SecureField(languageStore.text(.newPasswordPlaceholder), text: $newPassword)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)

                SecureField(languageStore.text(.confirmNewPasswordPlaceholder), text: $confirmPassword)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            }

            Section(languageStore.text(.requirementsSectionTitle)) {
                ChangePasswordRequirementRow(
                    title: languageStore.text(.requirementLength),
                    isSatisfied: hasValidLength
                )
                ChangePasswordRequirementRow(
                    title: languageStore.text(.requirementUpperLower),
                    isSatisfied: hasUpperAndLowercase
                )
                ChangePasswordRequirementRow(
                    title: languageStore.text(.requirementDigit),
                    isSatisfied: hasDigit
                )
                ChangePasswordRequirementRow(
                    title: languageStore.text(.requirementSymbol),
                    isSatisfied: hasSymbol
                )
                ChangePasswordRequirementRow(
                    title: languageStore.text(.requirementMatch),
                    isSatisfied: passwordsMatch,
                    isPending: trimmedConfirmPassword.isEmpty
                )
            }
        }
        .navigationTitle(languageStore.text(.changePassword))
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    profileVM.changePassword(old: trimmedCurrentPassword, new: trimmedNewPassword) {
                        dismiss()
                    }
                } label: {
                    if profileVM.isChangingPassword {
                        ProgressView()
                            .tint(AppTheme.primary)
                    } else {
                        Text(languageStore.text(.save))
                            .font(.body.weight(.semibold))
                    }
                }
                .disabled(profileVM.isChangingPassword || !canSubmit)
            }
        }
    }
}

private struct ChangePasswordRequirementRow: View {
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
