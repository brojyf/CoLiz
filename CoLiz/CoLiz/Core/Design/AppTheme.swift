import SwiftUI
import UIKit

enum AppTheme {
    static let background = Color(uiColor: .systemGroupedBackground)
    static let primary = Color("ThemePrimary")
    static let secondary = Color("ThemeSecondary")
    static let butter = Color("ThemeButter")
    static let blush = Color("ThemeBlush")
    static let cream = Color("ThemeCream")
    static let creamStrong = Color("ThemeCreamStrong")
    static let surface = Color("ThemeSurface")
    static let border = Color("ThemeBorder")
    static let ink = Color("ThemeInk")
    static let lent = Color("ThemeLent")
    static let borrowed = Color("ThemeBorrowed")
    static let onBrand = Color.white
}

enum CoListMotion {
    static let press = Animation.timingCurve(0.2, 0.9, 0.22, 1.0, duration: 0.18)
    static let settle = Animation.spring(response: 0.48, dampingFraction: 0.84)
    static let screenReveal = Animation.timingCurve(0.16, 1.0, 0.3, 1.0, duration: 0.72)
    static let sectionToggle = Animation.timingCurve(0.22, 0.96, 0.3, 1.0, duration: 0.42)
    static func stagger(at index: Int, step: Double = 0.05) -> Animation {
        screenReveal.delay(Double(index) * step)
    }
}

enum CoListButtonTone {
    case primary
    case secondary
    case butter
    case blush
    case neutral

    fileprivate var fill: Color {
        switch self {
        case .primary:
            return AppTheme.primary
        case .secondary:
            return AppTheme.secondary
        case .butter:
            return AppTheme.butter
        case .blush:
            return AppTheme.blush
        case .neutral:
            return AppTheme.surface
        }
    }

    fileprivate var foreground: Color {
        switch self {
        case .primary, .secondary:
            return AppTheme.onBrand
        case .butter, .blush, .neutral:
            return AppTheme.ink
        }
    }

    fileprivate var stroke: Color {
        switch self {
        case .primary:
            return AppTheme.primary
        case .secondary:
            return AppTheme.secondary
        case .butter:
            return AppTheme.butter
        case .blush:
            return AppTheme.blush
        case .neutral:
            return AppTheme.border
        }
    }
}

struct CoListFilledButtonStyle: ButtonStyle {
    var tone: CoListButtonTone = .primary
    var horizontalPadding: CGFloat = 14
    var verticalPadding: CGFloat = 10

    func makeBody(configuration: Configuration) -> some View {
        FilledButtonBody(
            configuration: configuration,
            tone: tone,
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding
        )
    }

    private struct FilledButtonBody: View {
        let configuration: Configuration
        let tone: CoListButtonTone
        let horizontalPadding: CGFloat
        let verticalPadding: CGFloat

        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tone.foreground)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(tone.fill.opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1.0) : 0.45))
                )
                .shadow(
                    color: tone.stroke.opacity(configuration.isPressed ? 0.08 : 0.16),
                    radius: configuration.isPressed ? 8 : 18,
                    x: 0,
                    y: configuration.isPressed ? 4 : 10
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(tone.stroke.opacity(isEnabled ? 1.0 : 0.45), lineWidth: 1)
                )
                .scaleEffect(configuration.isPressed ? 0.982 : 1.0)
                .animation(CoListMotion.press, value: configuration.isPressed)
        }
    }
}

struct CoListOutlineButtonStyle: ButtonStyle {
    var tone: CoListButtonTone = .neutral

    func makeBody(configuration: Configuration) -> some View {
        OutlineButtonBody(configuration: configuration, tone: tone)
    }

    private struct OutlineButtonBody: View {
        let configuration: Configuration
        let tone: CoListButtonTone

        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tone.stroke.opacity(isEnabled ? 1.0 : 0.45))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppTheme.surface.opacity(configuration.isPressed ? 0.88 : 1.0))
                )
                .shadow(
                    color: tone.stroke.opacity(configuration.isPressed ? 0.04 : 0.08),
                    radius: configuration.isPressed ? 6 : 14,
                    x: 0,
                    y: configuration.isPressed ? 2 : 8
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(tone.stroke.opacity(isEnabled ? 1.0 : 0.45), lineWidth: 1)
                )
                .scaleEffect(configuration.isPressed ? 0.984 : 1.0)
                .animation(CoListMotion.press, value: configuration.isPressed)
        }
    }
}

struct CoListTextActionButtonStyle: ButtonStyle {
    var tone: CoListButtonTone = .primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .foregroundStyle(tone.stroke.opacity(configuration.isPressed ? 0.72 : 1.0))
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(CoListMotion.press, value: configuration.isPressed)
    }
}

struct CoListInputFieldModifier: ViewModifier {
    var fill: Color = AppTheme.surface

    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
    }
}

struct CoListCardModifier: ViewModifier {
    var fill: Color = AppTheme.surface
    var cornerRadius: CGFloat = ComponentMetrics.cardCornerRadius

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.22),
                                        Color.white.opacity(0.0)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppTheme.border.opacity(0.85), lineWidth: 1)
            )
            .shadow(color: AppTheme.ink.opacity(0.06), radius: 20, x: 0, y: 10)
    }
}

struct CoListScreenBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(CoListAmbientBackdrop())
    }
}

struct CoListTintBadgeModifier: ViewModifier {
    var fill: Color
    var foreground: Color = AppTheme.ink
    var cornerRadius: CGFloat = 10

    func body(content: Content) -> some View {
        content
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
            )
    }
}

struct CoListDisclosureIndicator: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(AppTheme.border)
    }
}

private struct CoListRevealEnabledKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var colistRevealEnabled: Bool {
        get { self[CoListRevealEnabledKey.self] }
        set { self[CoListRevealEnabledKey.self] = newValue }
    }
}

private struct CoListAmbientBackdrop: View {
    var body: some View {
        ZStack {
            AppTheme.background

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            AppTheme.butter.opacity(0.34),
                            AppTheme.blush.opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 320, height: 320)
                .blur(radius: 18)
                .offset(x: 124, y: -248)
                .scaleEffect(1.12)

            RoundedRectangle(cornerRadius: 120, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            AppTheme.primary.opacity(0.14),
                            AppTheme.secondary.opacity(0.08)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 260, height: 360)
                .rotationEffect(.degrees(24))
                .blur(radius: 36)
                .offset(x: 164, y: 248)

            Circle()
                .fill(AppTheme.creamStrong.opacity(0.45))
                .frame(width: 180, height: 180)
                .blur(radius: 42)
                .offset(x: -164, y: 268)
        }
        .ignoresSafeArea()
    }
}

private struct CoListRevealModifier: ViewModifier {
    let animation: Animation
    let yOffset: CGFloat
    let xOffset: CGFloat
    let startScale: CGFloat

    @Environment(\.colistRevealEnabled) private var colistRevealEnabled
    @State private var isVisible = false

    func body(content: Content) -> some View {
        let shouldRenderVisible = isVisible || !colistRevealEnabled

        content
            .opacity(shouldRenderVisible ? 1 : 0.02)
            .scaleEffect(shouldRenderVisible ? 1 : startScale)
            .offset(x: shouldRenderVisible ? 0 : xOffset, y: shouldRenderVisible ? 0 : yOffset)
            .animation(colistRevealEnabled ? animation : nil, value: isVisible)
            .task {
                if !colistRevealEnabled {
                    isVisible = true
                    return
                }
                guard !isVisible else { return }
                isVisible = true
            }
            .onChange(of: colistRevealEnabled) { _, isEnabled in
                if !isEnabled {
                    isVisible = true
                }
            }
    }
}

extension View {
    func colistInputField(fill: Color = AppTheme.surface) -> some View {
        modifier(CoListInputFieldModifier(fill: fill))
    }

    func colistRowCard(
        fill: Color = AppTheme.surface,
        horizontalPadding: CGFloat = 14,
        verticalPadding: CGFloat = 14,
        cornerRadius: CGFloat = ComponentMetrics.largeCardCornerRadius
    ) -> some View {
        padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .colistCard(fill: fill, cornerRadius: cornerRadius)
            .contentShape(Rectangle())
    }

    func colistCardListRow(
        top: CGFloat = 6,
        leading: CGFloat = 16,
        bottom: CGFloat = 6,
        trailing: CGFloat = 16
    ) -> some View {
        listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: top, leading: leading, bottom: bottom, trailing: trailing))
    }

    func colistCard(
        fill: Color = AppTheme.surface,
        cornerRadius: CGFloat = ComponentMetrics.cardCornerRadius
    ) -> some View {
        modifier(CoListCardModifier(fill: fill, cornerRadius: cornerRadius))
    }

    func colistScreenBackground() -> some View {
        modifier(CoListScreenBackgroundModifier())
    }

    func colistTintBadge(
        fill: Color,
        foreground: Color = AppTheme.ink,
        cornerRadius: CGFloat = 10
    ) -> some View {
        modifier(CoListTintBadgeModifier(fill: fill, foreground: foreground, cornerRadius: cornerRadius))
    }

    func colistReveal(
        animation: Animation = CoListMotion.screenReveal,
        yOffset: CGFloat = 22,
        xOffset: CGFloat = 0,
        startScale: CGFloat = 0.985
    ) -> some View {
        modifier(
            CoListRevealModifier(
                animation: animation,
                yOffset: yOffset,
                xOffset: xOffset,
                startScale: startScale
            )
        )
    }
}
