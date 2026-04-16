import SwiftUI

struct GroupRowView: View {
    let groupName: String
    let remoteAvatarURL: URL?
    var subtitle: String? = nil
    var avatarSize: CGFloat = ComponentMetrics.rowAvatarSize
    var verticalPadding: CGFloat = 0
    var showsChevron: Bool = false
    var showsCard: Bool = true
    var cardFill: Color = AppTheme.surface

    var body: some View {
        rowContent
    }

    private var rowContent: some View {
        HStack(spacing: ComponentMetrics.rowSpacing) {
            CircularAvatarView(
                image: nil,
                remoteAvatarURL: remoteAvatarURL,
                size: avatarSize,
                placeholderSystemImage: "person.3.fill"
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(groupName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if showsChevron {
                CoListDisclosureIndicator()
            }
        }
        .modifier(
            GroupRowCardModifier(
                showsCard: showsCard,
                cardFill: cardFill,
                verticalPadding: verticalPadding
            )
        )
    }
}

private struct GroupRowCardModifier: ViewModifier {
    let showsCard: Bool
    let cardFill: Color
    let verticalPadding: CGFloat

    func body(content: Content) -> some View {
        if showsCard {
            content.colistRowCard(fill: cardFill, verticalPadding: 14 + verticalPadding)
        } else {
            content.padding(.vertical, verticalPadding)
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        GroupRowView(groupName: "Roommates", remoteAvatarURL: nil)
        GroupRowView(
            groupName: "Weekend Plan",
            remoteAvatarURL: nil,
            subtitle: "Tap to edit avatar"
        )
    }
    .padding()
}
