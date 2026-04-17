import SwiftUI

enum AppTheme {
    static let heroRadius: CGFloat = 24
    static let panelRadius: CGFloat = 20
    static let tileRadius: CGFloat = 16
    static let pillRadius: CGFloat = 12

    static func heroFill(for colorScheme: ColorScheme) -> LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    Color(red: 0.11, green: 0.14, blue: 0.18),
                    Color(red: 0.10, green: 0.18, blue: 0.18),
                    Color(red: 0.16, green: 0.18, blue: 0.24),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [
                Color(red: 0.95, green: 0.97, blue: 1.00),
                Color(red: 0.90, green: 0.96, blue: 0.94),
                Color(red: 0.98, green: 0.95, blue: 0.90),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func panelFill(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(nsColor: .controlBackgroundColor)
            : Color(red: 0.974, green: 0.966, blue: 0.954)
    }

    static func elevatedPanelFill(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(nsColor: .windowBackgroundColor)
            : .white
    }

    static func insetFill(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.045)
            : Color.black.opacity(0.022)
    }

    static func warningFill(for colorScheme: ColorScheme) -> Color {
        Color.orange.opacity(colorScheme == .dark ? 0.17 : 0.10)
    }

    static func border(for colorScheme: ColorScheme, emphasized: Bool = false) -> Color {
        if colorScheme == .dark {
            return Color.white.opacity(emphasized ? 0.12 : 0.08)
        }

        return Color.black.opacity(emphasized ? 0.10 : 0.07)
    }

    static func shadow(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.black.opacity(0.22)
            : Color.black.opacity(0.07)
    }

    static func badgeFill(_ tint: Color, colorScheme: ColorScheme) -> Color {
        tint.opacity(colorScheme == .dark ? 0.24 : 0.14)
    }

    static func badgeBorder(_ tint: Color, colorScheme: ColorScheme) -> Color {
        tint.opacity(colorScheme == .dark ? 0.34 : 0.18)
    }

    static func menuPresetFill(
        for colorScheme: ColorScheme,
        isLive: Bool,
        isSelected: Bool
    ) -> Color {
        if isLive {
            return Color.accentColor.opacity(colorScheme == .dark ? 0.22 : 0.14)
        }

        if isSelected {
            return Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.06)
        }

        return insetFill(for: colorScheme)
    }
}

struct AppPanelGroupBoxStyle: GroupBoxStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            configuration.label
                .font(.headline.weight(.semibold))

            configuration.content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.panelRadius)
                .fill(AppTheme.elevatedPanelFill(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.panelRadius)
                .stroke(AppTheme.border(for: colorScheme), lineWidth: 1)
        )
    }
}

struct AppSecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.pillRadius)
                    .fill(
                        configuration.isPressed
                            ? AppTheme.insetFill(for: colorScheme)
                            : AppTheme.elevatedPanelFill(for: colorScheme)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.pillRadius)
                    .stroke(AppTheme.border(for: colorScheme), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private struct AppHoverLiftModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false

    let enabled: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(enabled && isHovering ? 1.01 : 1)
            .offset(y: enabled && isHovering ? -1 : 0)
            .shadow(
                color: enabled && isHovering ? AppTheme.shadow(for: colorScheme) : .clear,
                radius: enabled && isHovering ? 12 : 0,
                x: 0,
                y: enabled && isHovering ? 8 : 0
            )
            .animation(.easeOut(duration: 0.16), value: isHovering)
            .onHover { hover in
                guard enabled else { return }
                isHovering = hover
            }
    }
}

extension View {
    func appHoverLift(enabled: Bool = true) -> some View {
        modifier(AppHoverLiftModifier(enabled: enabled))
    }
}
