import CodexConfigSwitcherCore
import SwiftUI

struct LiveContextBanner: View {
    @Environment(\.colorScheme) private var colorScheme

    let context: MainWindowContextBannerContext
    let onSelectLivePreset: () -> Void
    let onLoadLiveIntoDraft: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Label(context.title, systemImage: "arrow.triangle.branch")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)

                Text(context.message)
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                HStack {
                    Button("切到当前生效预设") {
                        onSelectLivePreset()
                    }

                    Button("用当前 live 覆盖草稿") {
                        onLoadLiveIntoDraft()
                    }

                    Spacer()
                }
            }

            HStack(alignment: .center, spacing: 10) {
                contextPill(
                    title: "当前生效",
                    name: context.livePresetName,
                    tag: context.liveEnvironmentTag
                )

                contextPill(
                    title: "当前编辑",
                    name: context.selectedPresetName,
                    tag: context.selectedEnvironmentTag
                )
            }
            .frame(maxWidth: 360)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.tileRadius)
                .fill(AppTheme.warningFill(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.tileRadius)
                .stroke(Color.orange.opacity(colorScheme == .dark ? 0.30 : 0.18), lineWidth: 1)
        )
    }

    private func contextPill(
        title: String,
        name: String,
        tag: PresetEnvironmentTag?
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            if let tag {
                PresetEnvironmentBadge(tag: tag)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppTheme.elevatedPanelFill(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppTheme.border(for: colorScheme), lineWidth: 1)
        )
    }
}
