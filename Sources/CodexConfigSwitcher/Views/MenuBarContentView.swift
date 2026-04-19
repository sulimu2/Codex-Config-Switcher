import AppKit
import CodexConfigSwitcherCore
import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.colorScheme) private var colorScheme
    @State private var searchText = ""

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

                currentLiveSummary

                searchField

                if filteredPresetSections.isEmpty {
                    Text("没有找到匹配的预设")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                } else {
                    ForEach(filteredPresetSections) { section in
                        Text(section.title)
                            .font(.subheadline.weight(.semibold))

                        ForEach(section.presets) { preset in
                            presetButton(for: preset)
                        }
                    }
                }

                Divider()

                HStack {
                    Button("打开工作台") {
                        openWindow(id: "main")
                    }
                    .buttonStyle(AppSecondaryButtonStyle())
                    Button("重新读取") {
                        model.reloadLiveConfiguration()
                    }
                    .buttonStyle(AppSecondaryButtonStyle())
                }

                if let status = model.compactStatusLine {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(AppTheme.insetFill(for: colorScheme))
                        )
                }

                if let errorMessage = model.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(AppTheme.warningFill(for: colorScheme))
                        )
                }

                Menu {
                    Button("打开全局设置") {
                        model.isShowingSettingsSheet = true
                        openWindow(id: "main")
                    }

                    Button("立即重启 \(model.targetApp.displayName)") {
                        model.restartTargetAppNow()
                    }

                    Divider()

                    Button("打开备份目录") {
                        model.revealBackupFolder()
                    }

                    Button("恢复最近备份") {
                        model.requestRestoreLatestBackup()
                    }
                    .disabled(model.latestBackup == nil)

                    Divider()

                    Button("退出") {
                        NSApplication.shared.terminate(nil)
                    }
                } label: {
                    Label("更多操作", systemImage: "ellipsis.circle")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .menuStyle(.borderlessButton)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppTheme.panelFill(for: colorScheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppTheme.border(for: colorScheme), lineWidth: 1)
                )
                .appHoverLift()
            }
            .padding(16)
            .frame(width: 336, alignment: .leading)
        }
        .confirmationDialog(
            "恢复最近备份？",
            isPresented: pendingRestoreBinding,
            titleVisibility: .visible,
            presenting: model.backupPendingRestore
        ) { backup in
            Button("恢复 \(formatted(backup.createdAt)) 的备份", role: .destructive) {
                model.confirmRestoreLatestBackup()
            }
            Button("取消", role: .cancel) {
                model.cancelRestoreLatestBackup()
            }
        } message: { backup in
            Text("恢复前会先自动备份当前配置。备份时间：\(formatted(backup.createdAt))。")
        }
        .confirmationDialog(
            "切换到高风险环境？",
            isPresented: pendingApplyBinding,
            titleVisibility: .visible,
            presenting: model.presetPendingApplyConfirmation
        ) { preset in
            Button("继续切换到 \(preset.name)", role: .destructive) {
                model.confirmPendingPresetApply()
            }
            Button("取消", role: .cancel) {
                model.cancelPendingPresetApply()
            }
        } message: { preset in
            Text("当前环境标签：\(preset.environmentTag.title)。这类环境可能指向代理或非默认服务，请确认接口地址和认证信息无误。")
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("搜索预设、地址或模型", text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.panelFill(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.border(for: colorScheme), lineWidth: 1)
        )
    }

    private var currentLiveSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("当前生效环境")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                PresetStatusBadge(title: model.targetAppStatusText, tint: targetAppTint)
            }

            HStack(spacing: 8) {
                Text(model.livePresetName)
                    .font(.body.weight(.medium))
                PresetEnvironmentBadge(tag: model.livePresetEnvironmentTag)
            }

            if let lastLoaded = model.lastLoaded {
                Text(lastLoaded.preset.baseURL.isEmpty ? "未读取到接口地址" : compactBaseURL(for: lastLoaded.preset.baseURL))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(lastLoaded.preset.model)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.panelRadius)
                .fill(AppTheme.heroFill(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.panelRadius)
                .stroke(AppTheme.border(for: colorScheme, emphasized: true), lineWidth: 1)
        )
    }

    private var filteredPresetSections: [MenuPresetSection] {
        let favorites = filterPresets(model.favoritePresets)
        let nonFavoriteRecentPresets = filterPresets(
            model.recentPresets.filter { !model.isFavoritePreset(id: $0.id) }
        )
        let hiddenIDs = Set(favorites.map(\.id) + nonFavoriteRecentPresets.map(\.id))
        let remainingPresets = filterPresets(
            model.presets.filter { !hiddenIDs.contains($0.id) }
        )

        var sections: [MenuPresetSection] = []
        if !favorites.isEmpty {
            sections.append(MenuPresetSection(title: "收藏", presets: favorites))
        }
        if !nonFavoriteRecentPresets.isEmpty {
            sections.append(MenuPresetSection(title: "最近使用", presets: nonFavoriteRecentPresets))
        }
        if !remainingPresets.isEmpty {
            sections.append(MenuPresetSection(title: searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "全部预设" : "搜索结果", presets: remainingPresets))
        }

        return sections
    }

    private func filterPresets(_ presets: [CodexPreset]) -> [CodexPreset] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return presets
        }

        return presets.filter { preset in
            [
                preset.name,
                preset.baseURL,
                preset.model,
                preset.reviewModel,
                preset.environmentTag.title,
            ].contains { value in
                value.localizedCaseInsensitiveContains(query)
            }
        }
    }

    private func compactBaseURL(for baseURL: String) -> String {
        guard
            let url = URL(string: baseURL),
            let host = url.host
        else {
            return baseURL
        }

        return url.path.isEmpty || url.path == "/" ? host : "\(host)\(url.path)"
    }

    private func backgroundColor(for preset: CodexPreset) -> Color {
        AppTheme.menuPresetFill(
            for: colorScheme,
            isLive: model.livePresetID == preset.id,
            isSelected: model.selectedPresetID == preset.id
        )
    }

    private var targetAppTint: Color {
        switch model.targetAppStatusText {
        case "运行中":
            .green
        case "已安装，未运行":
            .blue
        default:
            .orange
        }
    }

    private func presetButton(for preset: CodexPreset) -> some View {
        Button {
            model.applyPresetFromMenu(id: preset.id)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(preset.name)
                                .font(.body.weight(.medium))
                            if model.isFavoritePreset(id: preset.id) {
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundStyle(.yellow)
                            }
                        }
                        PresetEnvironmentBadge(tag: preset.environmentTag)
                    }
                    Spacer(minLength: 8)
                    if model.livePresetID == preset.id {
                        PresetStatusBadge(title: "当前生效", tint: .green)
                    } else if model.lastAppliedPresetID == preset.id {
                        PresetStatusBadge(title: "最近应用", tint: .accentColor)
                    }
                }

                Text(compactBaseURL(for: preset.baseURL))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(preset.model) / \(preset.reviewModel)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.tileRadius)
                    .fill(backgroundColor(for: preset))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.tileRadius)
                    .stroke(AppTheme.border(for: colorScheme), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .appHoverLift()
    }

    private var pendingRestoreBinding: Binding<Bool> {
        Binding(
            get: { model.backupPendingRestore != nil },
            set: { if !$0 { model.cancelRestoreLatestBackup() } }
        )
    }

    private var pendingApplyBinding: Binding<Bool> {
        Binding(
            get: { model.presetPendingApplyConfirmation != nil },
            set: { if !$0 { model.cancelPendingPresetApply() } }
        )
    }

    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}

struct OnboardingMenuBarContentView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.colorScheme) private var colorScheme
    @State private var isShowingInstallHelp = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("欢迎使用")
                        .font(.headline)
                    Text("先完成首次设置，再进入完整工作台。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("当前步骤")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("\(model.onboardingStep.title) · \(model.onboardingProgressText)")
                        .font(.body.weight(.medium))
                    Text(model.onboardingStep.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.panelRadius)
                        .fill(AppTheme.heroFill(for: colorScheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.panelRadius)
                        .stroke(AppTheme.border(for: colorScheme, emphasized: true), lineWidth: 1)
                )

                Button("打开首次设置") {
                    model.reopenOnboarding(startingAt: model.onboardingStep)
                    openWindow(id: "main")
                }
                .buttonStyle(.borderedProminent)
                .appHoverLift()

                Button("查看安装受阻说明") {
                    isShowingInstallHelp = true
                }
                .buttonStyle(AppSecondaryButtonStyle())
                .appHoverLift()

                Divider()

                Text("在首次设置完成前，菜单栏只保留最小入口，避免你误操作 live 配置。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(width: 336, alignment: .leading)
        }
        .sheet(isPresented: $isShowingInstallHelp) {
            InstallationHelpSheet()
        }
    }
}

private struct MenuPresetSection: Identifiable {
    let title: String
    let presets: [CodexPreset]

    var id: String { title }
}
