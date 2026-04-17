import CodexConfigSwitcherCore
import SwiftUI

struct PresetDiffRow: View {
    let diff: PresetFieldDiff

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(diff.title)
                        .font(.subheadline.weight(.semibold))
                    Text(diff.key)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                PresetStatusBadge(title: badgeTitle, tint: badgeTint)
            }

            HStack(alignment: .top, spacing: 12) {
                valueColumn("当前", value: diff.oldValue)
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 18)
                valueColumn("应用后", value: diff.newValue)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.06))
        )
    }

    private var badgeTitle: String {
        switch diff.kind {
        case .added:
            "新增"
        case .modified:
            "修改"
        case .unchanged:
            "保持不变"
        }
    }

    private var badgeTint: Color {
        switch diff.kind {
        case .added:
            .blue
        case .modified:
            .orange
        case .unchanged:
            .secondary
        }
    }

    private func valueColumn(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
