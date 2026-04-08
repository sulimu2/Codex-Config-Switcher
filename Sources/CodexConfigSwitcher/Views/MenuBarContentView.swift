import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Codex Config Switcher")
                        .font(.headline)
                    Text("一键切换 Codex 本地配置")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let lastLoaded = model.lastLoaded {
                    infoRow("当前 Base URL", value: lastLoaded.preset.baseURL.isEmpty ? "未读取到" : lastLoaded.preset.baseURL)
                    infoRow("当前 Model", value: lastLoaded.preset.model)
                }

                Text("快速应用")
                    .font(.subheadline.weight(.semibold))

                ForEach(model.presets) { preset in
                    Button {
                        model.applyPresetFromMenu(id: preset.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(preset.name)
                                .font(.body.weight(.medium))
                            Text(preset.baseURL)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(preset.model) / \(preset.reviewModel)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(model.selectedPresetID == preset.id ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08))
                        )
                    }
                    .buttonStyle(.plain)
                }

                Divider()

                HStack {
                    Button("打开主窗口") {
                        openWindow(id: "main")
                    }
                    Button("重新读取") {
                        model.reloadLiveConfiguration()
                    }
                }

                Button("立即重启 \(model.targetApp.displayName)") {
                    model.restartTargetAppNow()
                }

                Button("打开备份目录") {
                    model.revealBackupFolder()
                }

                if let status = model.compactStatusLine {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage = model.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Divider()

                Button("退出") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(16)
            .frame(width: 340, alignment: .leading)
        }
    }

    private func infoRow(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout)
        }
    }
}
