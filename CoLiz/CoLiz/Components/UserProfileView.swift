import SwiftUI
import PhotosUI
import UIKit

struct UserProfileView: View {
    @Binding var username: String
    @Binding var avatarImage: UIImage?

    let email: String
    let remoteAvatarURL: URL?
    let isUploadingAvatar: Bool
    let onEditUsername: () -> Void
    var avatarSize: CGFloat = ComponentMetrics.profileAvatarSize

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var pendingAvatarCrop: AvatarCropRequest?

    var body: some View {
        HStack(spacing: 14) {
            avatarPicker

            VStack(alignment: .leading, spacing: 6) {
                usernameRow

                if !email.isEmpty {
                    Text(email)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .colistCard(cornerRadius: ComponentMetrics.largeCardCornerRadius)
        .onChange(of: selectedPhoto) { _, newValue in
            guard let newValue else { return }
            Task {
                guard let data = try? await newValue.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
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
    }

    private var avatarPicker: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                CircularAvatarView(
                    image: avatarImage,
                    remoteAvatarURL: remoteAvatarURL,
                    size: avatarSize,
                    placeholderSystemImage: "camera.fill"
                )

                if isUploadingAvatar {
                    Circle()
                        .fill(AppTheme.surface.opacity(0.92))
                        .frame(width: avatarSize, height: avatarSize)

                    ProgressView()
                }
            }

            PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                AvatarEditBadgeView()
            }
            .buttonStyle(.plain)
            .disabled(isUploadingAvatar)
        }
    }

    @ViewBuilder
    private var usernameRow: some View {
        HStack(spacing: 8) {
            Text(username)
                .font(.headline)
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)

            Button(action: onEditUsername) {
                Image(systemName: "pencil")
                    .foregroundStyle(AppTheme.primary)
                    .padding(6)
                    .background(Circle().fill(AppTheme.creamStrong))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profile.editUsername")
        }
    }
}

#Preview {
    UserProfileView(
        username: .constant("Pat Jiang"),
        avatarImage: .constant(nil),
        email: "pat@example.com",
        remoteAvatarURL: nil,
        isUploadingAvatar: false,
        onEditUsername: {}
    )
    .padding()
}
