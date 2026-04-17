import CodexConfigSwitcherCore
import SwiftUI

struct PresetSidebarRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let name: String
    let environmentTag: PresetEnvironmentTag
    let baseURL: String
    let model: String
    let reviewModel: String
    let isFavorite: Bool
    let isLive: Bool
    let hasUnsavedChanges: Bool
    let wasLastApplied: Bool

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: AppTheme.tileRadius)
                .fill(rowFill)

            RoundedRectangle(cornerRadius: 3)
                .fill(statusTint.opacity(hasPrimaryStatus ? 0.85 : 0))
                .frame(width: 4)
                .padding(.vertical, 12)
                .padding(.leading, 8)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(name)
                                .font(.headline.weight(.semibold))
                                .lineLimit(1)

                            if isFavorite {
                                Image(systemName: "star.fill")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.yellow)
                            }
                        }

                        PresetEnvironmentBadge(tag: environmentTag)
                    }

                    Spacer(minLength: 0)

                    if let statusTitle {
                        PresetStatusBadge(title: statusTitle, tint: statusTint)
                    }
                }

                Text(condensedBaseURL)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text("\(model) / \(reviewModel)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.tileRadius)
                .stroke(rowBorder, lineWidth: 1)
        )
        .appHoverLift()
        .padding(.vertical, 4)
    }

    private var condensedBaseURL: String {
        guard
            let url = URL(string: baseURL),
            let host = url.host
        else {
            return baseURL.isEmpty ? "未配置接口地址" : baseURL
        }

        return url.path.isEmpty || url.path == "/" ? host : "\(host)\(url.path)"
    }

    private var statusTitle: String? {
        if isLive {
            return "当前生效"
        }
        if hasUnsavedChanges {
            return "未保存"
        }
        if wasLastApplied {
            return "最近应用"
        }
        return nil
    }

    private var statusTint: Color {
        if isLive {
            return .green
        }
        if hasUnsavedChanges {
            return .orange
        }
        if wasLastApplied {
            return .accentColor
        }
        return .secondary
    }

    private var hasPrimaryStatus: Bool {
        statusTitle != nil
    }

    private var rowFill: Color {
        if isLive {
            return Color.green.opacity(colorScheme == .dark ? 0.16 : 0.08)
        }
        if hasUnsavedChanges {
            return AppTheme.warningFill(for: colorScheme)
        }
        if wasLastApplied {
            return Color.accentColor.opacity(colorScheme == .dark ? 0.14 : 0.08)
        }
        return AppTheme.insetFill(for: colorScheme)
    }

    private var rowBorder: Color {
        if hasPrimaryStatus {
            return statusTint.opacity(colorScheme == .dark ? 0.24 : 0.18)
        }
        return AppTheme.border(for: colorScheme)
    }
}
