import SwiftUI

struct FriendRowView: View {
    let username: String
    let remoteAvatarURL: URL?
    var trailingText: String? = nil
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
                placeholderSystemImage: "person.fill"
            )

            Text(username)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)

            Spacer(minLength: 0)

            if let trailingText, !trailingText.isEmpty {
                Text(trailingText)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondary)
                    .lineLimit(1)
            }

            if showsChevron {
                CoListDisclosureIndicator()
            }
        }
        .modifier(
            FriendRowCardModifier(
                showsCard: showsCard,
                cardFill: cardFill,
                verticalPadding: verticalPadding
            )
        )
    }
}

private struct FriendRowCardModifier: ViewModifier {
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
        FriendRowView(username: "Alex Chen", remoteAvatarURL: nil)
        FriendRowView(username: "Jordan Park", remoteAvatarURL: nil, trailingText: "owner")
    }
    .padding()
}
