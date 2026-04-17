import CodexConfigSwitcherCore
import SwiftUI

struct PresetOperationHistoryRow: View {
    let entry: PresetOperationHistoryEntry
    let formattedDate: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(entry.presetName)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)

                        if let environmentTag = entry.environmentTag {
                            PresetEnvironmentBadge(tag: environmentTag)
                        }
                    }

                    Text(entry.kind.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                PresetStatusBadge(title: entry.outcome.title, tint: outcomeTint)
            }

            Text(entry.detail)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(formattedDate)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var outcomeTint: Color {
        switch entry.outcome {
        case .success:
            .green
        case .failure:
            .red
        }
    }
}
