import CodexConfigSwitcherCore
import SwiftUI

struct BackupHistoryRow: View {
    let backup: BackupSnapshotSummary
    let formattedDate: String
    let onRestore: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(formattedDate)
                    .font(.subheadline.weight(.semibold))
                Text(pathSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            Button("恢复这份") {
                onRestore()
            }
            .buttonStyle(.borderless)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.06))
        )
    }

    private var pathSummary: String {
        var parts: [String] = []
        if backup.configBackupPath != nil {
            parts.append("config")
        }
        if backup.authBackupPath != nil {
            parts.append("auth")
        }
        return parts.isEmpty ? "空备份" : "包含：\(parts.joined(separator: " + "))"
    }
}
