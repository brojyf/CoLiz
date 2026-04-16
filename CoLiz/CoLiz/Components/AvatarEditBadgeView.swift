import SwiftUI

struct AvatarEditBadgeView: View {
    var size: CGFloat = ComponentMetrics.avatarEditBadgeSize

    var body: some View {
        ZStack {
            Circle()
                .fill(AppTheme.primary)

            Image(systemName: "pencil")
                .font(.system(size: size * 0.44, weight: .bold))
                .foregroundStyle(AppTheme.onBrand)
        }
        .frame(width: size, height: size)
        .overlay(
            Circle()
                .stroke(AppTheme.butter.opacity(0.9), lineWidth: 2)
        )
    }
}

#Preview {
    AvatarEditBadgeView()
        .padding()
}
