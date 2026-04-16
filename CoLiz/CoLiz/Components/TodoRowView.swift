import SwiftUI

struct TodoRowView: View {
    let todo: Todo
    let remoteAvatarURL: URL?
    var subtitle: String? = nil
    var verticalPadding: CGFloat = 0
    let onToggle: () -> Void

    @State private var stagedDone: Bool?
    @State private var isToggling = false

    private var done: Bool {
        stagedDone ?? todo.done
    }

    private func resetTransientState() {
        stagedDone = nil
        isToggling = false
    }

    var body: some View {
        HStack(spacing: ComponentMetrics.rowSpacing) {
            CircularAvatarView(
                image: nil,
                remoteAvatarURL: remoteAvatarURL,
                size: ComponentMetrics.rowAvatarSize,
                placeholderSystemImage: "checklist"
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(todo.message)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(2)
                    .opacity(done ? 0.7 : 1)
                    .strikethrough(done, color: AppTheme.ink.opacity(0.35))

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 12)

            Button {
                guard !isToggling else { return }

                isToggling = true
                let target = !done

                withAnimation(CoListMotion.sectionToggle) {
                    stagedDone = target
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    onToggle()

                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        if isToggling {
                            withAnimation(CoListMotion.press) {
                                stagedDone = nil
                            }
                            isToggling = false
                        }
                    }
                }

            } label: {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(done ? AppTheme.secondary : AppTheme.primary)
                    .contentTransition(.symbolEffect(.replace))
                    .scaleEffect(done ? 1.06 : 0.96)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill((done ? AppTheme.butter : AppTheme.creamStrong).opacity(0.35))
                    )
            }
            .buttonStyle(.plain)
            .disabled(isToggling)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14 + verticalPadding)
        .colistCard(fill: AppTheme.surface, cornerRadius: ComponentMetrics.largeCardCornerRadius)
        .contentShape(Rectangle())
        .animation(CoListMotion.sectionToggle, value: done)
        .onChange(of: todo.id) { _, _ in
            resetTransientState()
        }
        .onChange(of: todo.done) { _, _ in
            resetTransientState()
        }
        .onDisappear {
            resetTransientState()
        }
    }
}
