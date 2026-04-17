import AppKit
import CodexConfigSwitcherCore
import SwiftUI

struct CurrentStatusSummaryCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let livePresetName: String
    let liveEnvironmentTag: PresetEnvironmentTag
    let selectedPresetName: String
    let selectedEnvironmentTag: PresetEnvironmentTag?
    let draftStatusText: String
    let lastAppliedText: String
    let targetAppName: String
    let targetAppStatusText: String
    let validationText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("工作区总览", systemImage: "sparkles.rectangle.stack")
                        .font(.title3.weight(.semibold))
                    Text("先确认当前生效配置，再决定是继续编辑、切换还是回滚。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    PresetStatusBadge(title: targetAppStatusText, tint: targetAppTint)
                    Text(targetAppName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .top, spacing: 12) {
                spotlightBlock(
                    "当前生效",
                    value: livePresetName,
                    environmentTag: liveEnvironmentTag,
                    accent: .mint
                )

                spotlightBlock(
                    "当前编辑",
                    value: selectedPresetName,
                    environmentTag: selectedEnvironmentTag,
                    accent: .accentColor
                )
            }

            HStack(alignment: .top, spacing: 12) {
                compactFact(
                    title: "草稿状态",
                    value: draftStatusText,
                    detail: draftStatusText == "未保存修改" ? "建议先保存再应用" : "可以直接继续处理",
                    accent: draftTint
                )

                compactFact(
                    title: "最近应用",
                    value: lastAppliedText,
                    detail: "用于快速确认本轮操作是否落地"
                )

                compactFact(
                    title: "目标应用",
                    value: targetAppStatusText,
                    detail: targetAppName,
                    accent: targetAppTint
                )
            }

            if let validationText, !validationText.isEmpty {
                Label(validationText, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(AppTheme.warningFill(for: colorScheme))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.orange.opacity(colorScheme == .dark ? 0.30 : 0.18), lineWidth: 1)
                    )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.panelRadius)
                .fill(AppTheme.elevatedPanelFill(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.panelRadius)
                .stroke(AppTheme.border(for: colorScheme), lineWidth: 1)
        )
        .shadow(color: AppTheme.shadow(for: colorScheme), radius: 18, x: 0, y: 8)
    }

    private var targetAppTint: Color {
        switch targetAppStatusText {
        case "运行中":
            .green
        case "已安装，未运行":
            .blue
        default:
            .orange
        }
    }

    private var draftTint: Color {
        draftStatusText == "未保存修改" ? .orange : .green
    }

    private func spotlightBlock(
        _ title: String,
        value: String,
        environmentTag: PresetEnvironmentTag? = nil,
        accent: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(accent)
                    .frame(width: 8, height: 8)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            if let environmentTag {
                PresetEnvironmentBadge(tag: environmentTag)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.tileRadius)
                .fill(AppTheme.insetFill(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.tileRadius)
                .stroke(AppTheme.border(for: colorScheme), lineWidth: 1)
        )
    }

    private func compactFact(
        title: String,
        value: String,
        detail: String,
        accent: Color? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(accent ?? .primary)

            Text(detail)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.tileRadius)
                .fill(AppTheme.insetFill(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.tileRadius)
                .stroke(AppTheme.border(for: colorScheme), lineWidth: 1)
        )
    }
}
