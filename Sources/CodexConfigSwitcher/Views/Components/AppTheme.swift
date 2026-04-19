import SwiftUI

enum AppTheme {
    static let heroRadius: CGFloat = 24
    static let panelRadius: CGFloat = 20
    static let tileRadius: CGFloat = 16
    static let pillRadius: CGFloat = 12
    static let brandBlue = Color(red: 0.0, green: 0.32, blue: 1.0)
    static let brandBlueSoft = Color(red: 0.34, green: 0.55, blue: 0.98)
    static let positiveGreen = Color(red: 0.09, green: 0.66, blue: 0.43)
    static let cautionAmber = Color(red: 0.89, green: 0.56, blue: 0.07)

    static func heroFill(for colorScheme: ColorScheme) -> LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.09, blue: 0.14),
                    Color(red: 0.07, green: 0.12, blue: 0.19),
                    Color(red: 0.05, green: 0.17, blue: 0.30),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [
                Color(red: 0.96, green: 0.98, blue: 1.00),
                Color(red: 0.93, green: 0.96, blue: 1.00),
                Color(red: 0.97, green: 0.98, blue: 1.00),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func panelFill(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.08, green: 0.10, blue: 0.14)
            : Color(red: 0.956, green: 0.969, blue: 0.989)
    }

    static func elevatedPanelFill(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.11, green: 0.13, blue: 0.17)
            : Color.white
    }

    static func insetFill(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.05)
            : brandBlue.opacity(0.05)
    }

    static func warningFill(for colorScheme: ColorScheme) -> Color {
        Color.orange.opacity(colorScheme == .dark ? 0.17 : 0.10)
    }

    static func border(for colorScheme: ColorScheme, emphasized: Bool = false) -> Color {
        if colorScheme == .dark {
            return Color.white.opacity(emphasized ? 0.15 : 0.09)
        }

        return brandBlue.opacity(emphasized ? 0.18 : 0.10)
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

    static func financeBackdrop(for colorScheme: ColorScheme) -> LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.10, blue: 0.15),
                    Color(red: 0.08, green: 0.13, blue: 0.20),
                    Color(red: 0.10, green: 0.15, blue: 0.24),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [
                Color(red: 0.978, green: 0.989, blue: 1.000),
                Color(red: 0.949, green: 0.972, blue: 0.996),
                Color(red: 0.930, green: 0.958, blue: 0.992),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func financePanelFill(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.09, green: 0.12, blue: 0.17)
            : Color(red: 0.986, green: 0.992, blue: 1.000)
    }

    static func financeElevatedFill(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.11, green: 0.15, blue: 0.21)
            : Color.white
    }

    static func financeInsetFill(for colorScheme: ColorScheme, emphasized: Bool = false) -> Color {
        if colorScheme == .dark {
            return emphasized
                ? Color(red: 0.13, green: 0.20, blue: 0.30)
                : Color(red: 0.10, green: 0.16, blue: 0.24)
        }

        return emphasized
            ? Color(red: 0.922, green: 0.962, blue: 1.000)
            : Color(red: 0.952, green: 0.976, blue: 1.000)
    }

    static func financeAccent(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.48, green: 0.73, blue: 1.00)
            : Color(red: 0.16, green: 0.43, blue: 0.86)
    }

    static func financeAccentMuted(for colorScheme: ColorScheme) -> Color {
        financeAccent(for: colorScheme).opacity(colorScheme == .dark ? 0.22 : 0.12)
    }

    static func financeBorder(for colorScheme: ColorScheme, emphasized: Bool = false) -> Color {
        if colorScheme == .dark {
            return financeAccent(for: colorScheme).opacity(emphasized ? 0.42 : 0.24)
        }

        return Color(red: 0.74, green: 0.84, blue: 0.95).opacity(emphasized ? 0.95 : 0.70)
    }

    static func financePositive(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.40, green: 0.84, blue: 0.71)
            : Color(red: 0.10, green: 0.58, blue: 0.42)
    }

    static func financeWarning(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 1.00, green: 0.78, blue: 0.42)
            : Color(red: 0.81, green: 0.49, blue: 0.05)
    }

    static func financeDanger(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 1.00, green: 0.54, blue: 0.54)
            : Color(red: 0.77, green: 0.23, blue: 0.22)
    }

    static func financeShadow(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.black.opacity(0.30)
            : Color(red: 0.11, green: 0.24, blue: 0.42).opacity(0.12)
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
