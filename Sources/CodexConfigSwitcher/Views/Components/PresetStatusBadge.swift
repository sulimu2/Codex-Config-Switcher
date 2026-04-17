import SwiftUI

struct PresetStatusBadge: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let tint: Color

    var body: some View {
        Text(title)
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
}
