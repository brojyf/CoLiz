import SwiftUI

struct SocialRequestRowView: View {
    let req: FriendRequest
    let displayName: String
    let avatarURL: URL?
    let canAccept: Bool
    let isAccepting: Bool
    let canDecline: Bool
    let isDeclining: Bool
    let canCancel: Bool
    let isCancelling: Bool
    let onAccept: () -> Void
    let onDecline: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: ComponentMetrics.rowSpacing) {
                CircularAvatarView(
                    image: nil,
                    remoteAvatarURL: avatarURL,
                    size: ComponentMetrics.rowAvatarSize,
                    placeholderSystemImage: "person.fill"
                )

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.ink)
                            .lineLimit(1)
                        
                        Text(req.statusText)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(statusTint)
                    }

                    if let message = trimmedMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.secondary)
                    }
                }

                Spacer(minLength: 0)

                if showsInlineActions {
                    inlineActions
                }
            }
        }
        .colistRowCard(fill: AppTheme.surface, verticalPadding: 14)
    }

    private var trimmedMessage: String? {
        let message = req.msg?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return message.isEmpty ? nil : message
    }

    private var showsActions: Bool {
        canAccept || canDecline || canCancel
    }

    private var showsInlineActions: Bool {
        showsActions
    }

    private var inlineActions: some View {
        HStack(spacing: 8) {
            if canAccept {
                inlineActionButton(
                    systemImage: "checkmark",
                    tint: AppTheme.primary,
                    isLoading: isAccepting,
                    progressTint: AppTheme.onBrand,
                    action: onAccept
                )
            }

            if canDecline {
                inlineActionButton(
                    systemImage: "xmark",
                    tint: AppTheme.blush,
                    isLoading: isDeclining,
                    progressTint: AppTheme.ink,
                    action: onDecline
                )
            }

            if canCancel {
                inlineActionButton(
                    systemImage: "xmark",
                    tint: AppTheme.surface,
                    stroke: AppTheme.border,
                    foreground: AppTheme.secondary,
                    isLoading: isCancelling,
                    progressTint: AppTheme.secondary,
                    action: onCancel
                )
            }
        }
    }

    private func inlineActionButton(
        systemImage: String,
        tint: Color,
        stroke: Color? = nil,
        foreground: Color? = nil,
        isLoading: Bool,
        progressTint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(tint)
                    .overlay(
                        Circle()
                            .stroke(stroke ?? tint, lineWidth: 1)
                    )
                    .frame(width: 32, height: 32)

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(progressTint)
                } else {
                    Image(systemName: systemImage)
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(foreground ?? AppTheme.onBrand)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isAccepting || isDeclining || isCancelling)
    }

    private var statusTint: Color {
        switch req.status.lowercased() {
        case "pending":
            return AppTheme.secondary
        case "accepted":
            return AppTheme.lent
        case "rejected":
            return AppTheme.borrowed
        default:
            return AppTheme.secondary
        }
    }
}

#Preview {
    SocialRequestRowView(
        req: FriendRequest.mockList()[0],
        displayName: FriendRequest.mockList()[0].fromUsername ?? FriendRequest.mockList()[0].from,
        avatarURL: nil,
        canAccept: true,
        isAccepting: false,
        canDecline: true,
        isDeclining: false,
        canCancel: false,
        isCancelling: false,
        onAccept: {},
        onDecline: {},
        onCancel: {}
    )
    .padding()
}
