import CodexConfigSwitcherCore
import SwiftUI

struct PresetEnvironmentBadge: View {
    @Environment(\.colorScheme) private var colorScheme

    let tag: PresetEnvironmentTag

    var body: some View {
        Text(tag.title)
            .font(.caption2.weight(.bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(AppTheme.badgeFill(tint, colorScheme: colorScheme))
            )
            .overlay(
                Capsule()
                    .stroke(AppTheme.badgeBorder(tint, colorScheme: colorScheme), lineWidth: 1)
            )
    }

    private var tint: Color {
        switch tag {
        case .official:
            .blue
        case .proxy:
            .orange
        case .test:
            .mint
        case .backup:
            .gray
        }
    }
}
