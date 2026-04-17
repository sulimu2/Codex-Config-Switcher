import AppKit
import CodexConfigSwitcherCore
import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var searchText = ""
    @State private var environmentFilter: PresetEnvironmentTag?
    @State private var sortMode: PresetListSortMode = .recentUsage
    @State private var isShowingTemplateQuickCreate = false
    @State private var isConfirmingLoadLiveIntoDraft = false
    @State private var workspaceMode: DetailWorkspaceMode = .presetEditor

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 240, ideal: 280)
        } detail: {
            detailView
        }
        .alert(
            "操作失败",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.clearError() } }
            )
        ) {
            Button("知道了", role: .cancel) {
                model.clearError()
            }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .confirmationDialog(
            "删除当前预设？",
            isPresented: pendingDeletionBinding,
            titleVisibility: .visible,
            presenting: model.presetPendingDeletion
        ) { preset in
            Button("删除 \(preset.name)", role: .destructive) {
                model.confirmDeleteSelectedPreset()
            }
            Button("取消", role: .cancel) {
                model.cancelDeletePreset()
            }
        } message: { _ in
            Text("删除后不会影响已经写入的配置和备份，但这个预设会从列表中移除。")
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
        .confirmationDialog(
            "切换预设前先处理当前修改？",
            isPresented: pendingPresetSelectionBinding,
            titleVisibility: .visible,
            presenting: model.presetPendingSelection
        ) { preset in
            Button("保存当前修改并切换到 \(preset.name)") {
                model.confirmSaveAndSelectPendingPreset()
            }
            Button("放弃修改并切换到 \(preset.name)", role: .destructive) {
                model.confirmDiscardAndSelectPendingPreset()
            }
            Button("取消", role: .cancel) {
                model.cancelPendingPresetSelection()
            }
        } message: { preset in
            Text("你正在编辑的草稿还没有保存。继续切换到 \(preset.name) 前，可以先覆盖当前预设，或放弃这次修改。")
        }
        .confirmationDialog(
            "用当前 live 覆盖草稿？",
            isPresented: $isConfirmingLoadLiveIntoDraft,
            titleVisibility: .visible
        ) {
            Button("覆盖当前草稿", role: .destructive) {
                model.loadLiveConfigurationIntoDraft()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("这会用当前生效配置覆盖编辑区里的未保存草稿。建议只在确认不再保留当前草稿时使用。")
        }
        .sheet(isPresented: $model.isShowingSettingsSheet) {
            SettingsSheetView()
                .environmentObject(model)
        }
    }

    private var selectedPresetBinding: Binding<UUID?> {
        Binding(
            get: { model.selectedPresetID },
            set: { model.selectPreset(id: $0) }
        )
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            sidebarControls

            Divider()

            sidebarContent

            Divider()

            sidebarActionDock
        }
        .background(AppTheme.panelFill(for: colorScheme))
        .searchable(text: $searchText, prompt: "搜索预设、地址或模型")
    }

    private var sidebarControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("预设库")
                    .font(.title3.weight(.semibold))
                Text("高频切换用侧边栏，低频管理收进菜单。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Menu {
                    Button("全部环境") {
                        environmentFilter = nil
                    }

                    Divider()

                    ForEach(PresetEnvironmentTag.allCases, id: \.self) { tag in
                        Button(tag.title) {
                            environmentFilter = tag
                        }
                    }
                } label: {
                    Label(environmentFilterTitle, systemImage: "line.3.horizontal.decrease.circle")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .menuStyle(.borderlessButton)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.pillRadius)
                        .fill(AppTheme.elevatedPanelFill(for: colorScheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.pillRadius)
                        .stroke(AppTheme.border(for: colorScheme), lineWidth: 1)
                )

                Menu {
                    ForEach(PresetListSortMode.allCases) { mode in
                        Button(mode.title) {
                            sortMode = mode
                        }
                    }
                } label: {
                    Label(sortMode.title, systemImage: "arrow.up.arrow.down.circle")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .menuStyle(.borderlessButton)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.pillRadius)
                        .fill(AppTheme.elevatedPanelFill(for: colorScheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.pillRadius)
                        .stroke(AppTheme.border(for: colorScheme), lineWidth: 1)
                )
            }

            if environmentFilter != nil {
                Button("清除环境筛选") {
                    environmentFilter = nil
                }
                .font(.caption.weight(.medium))
            }
        }
        .padding(16)
    }

    @ViewBuilder
    private var sidebarContent: some View {
        if filteredSections.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("未找到匹配预设")
                    .font(.headline)
                Text(emptyStateDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            presetList
        }
    }

    private var presetList: some View {
        List(selection: selectedPresetBinding) {
            ForEach(filteredSections) { section in
                Section(section.title) {
                    ForEach(section.presets) { preset in
                        presetRow(for: preset)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func presetRow(for preset: CodexPreset) -> some View {
        PresetSidebarRow(
            name: preset.name,
            environmentTag: preset.environmentTag,
            baseURL: preset.baseURL,
            model: preset.model,
            reviewModel: preset.reviewModel,
            isFavorite: model.isFavoritePreset(id: preset.id),
            isLive: model.livePresetID == preset.id,
            hasUnsavedChanges: model.selectedPresetID == preset.id && model.hasUnsavedChanges,
            wasLastApplied: model.lastAppliedPresetID == preset.id
        )
        .tag(preset.id as UUID?)
    }

    private var detailView: some View {
        VStack(alignment: .leading, spacing: 16) {
            heroSection

            workspaceHeader

            Group {
                switch workspaceMode {
                case .presetEditor:
                    PresetEditorView()
                        .environmentObject(model)
                case .templateWorkbench:
                    templateWorkspace
                }
            }
        }
        .padding(20)
    }

    private var pendingDeletionBinding: Binding<Bool> {
        Binding(
            get: { model.presetPendingDeletion != nil },
            set: { if !$0 { model.cancelDeletePreset() } }
        )
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

    private var pendingPresetSelectionBinding: Binding<Bool> {
        Binding(
            get: { model.presetPendingSelection != nil },
            set: { if !$0 { model.cancelPendingPresetSelection() } }
        )
    }

    private var formattedLastApplied: String {
        guard let date = model.lastAppliedDate else {
            return "尚未应用"
        }

        return formatted(date)
    }

    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    private var quickActionPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("快速动作", systemImage: "bolt.fill")
                .font(.headline)

            Text("先处理 live 同步、回滚和收藏，再进入编辑。")
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                quickActionTile(
                    title: "重新读取",
                    subtitle: "同步当前 live 配置",
                    systemImage: "arrow.clockwise.circle"
                ) {
                    model.reloadLiveConfiguration()
                }

                quickActionTile(
                    title: "载入到草稿",
                    subtitle: "把当前 live 配置带回编辑区",
                    systemImage: "square.and.arrow.down.on.square"
                ) {
                    model.loadLiveConfigurationIntoDraft()
                }

                quickActionTile(
                    title: "恢复最近备份",
                    subtitle: model.latestBackup == nil ? "当前还没有可恢复备份" : "先自动备份，再回滚",
                    systemImage: "clock.arrow.circlepath",
                    tint: .orange,
                    isDisabled: model.latestBackup == nil
                ) {
                    model.requestRestoreLatestBackup()
                }

                quickActionTile(
                    title: model.selectedPreset.map { model.isFavoritePreset(id: $0.id) ? "取消收藏" : "收藏当前预设" } ?? "收藏当前预设",
                    subtitle: model.selectedPreset == nil ? "先选择一个预设" : "把常用项固定到前面",
                    systemImage: "star.circle",
                    tint: .yellow,
                    isDisabled: model.selectedPreset == nil
                ) {
                    model.toggleFavoriteSelectedPreset()
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.panelRadius)
                .fill(AppTheme.elevatedPanelFill(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.panelRadius)
                .stroke(AppTheme.border(for: colorScheme), lineWidth: 1)
        )
    }

    private func quickActionTile(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color = .accentColor,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tint)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.tileRadius)
                    .fill(AppTheme.insetFill(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.tileRadius)
                    .stroke(AppTheme.border(for: colorScheme), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.55 : 1)
        .appHoverLift(enabled: !isDisabled)
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 18) {
                CurrentStatusSummaryCard(
                    livePresetName: model.livePresetName,
                    liveEnvironmentTag: model.livePresetEnvironmentTag,
                    selectedPresetName: model.selectedPreset?.name ?? "未选择预设",
                    selectedEnvironmentTag: model.selectedPresetEnvironmentTag,
                    draftStatusText: model.hasUnsavedChanges ? "未保存修改" : "已与所选预设同步",
                    lastAppliedText: formattedLastApplied,
                    targetAppName: model.targetApp.displayName,
                    targetAppStatusText: model.targetAppStatusText,
                    validationText: model.validationSummary
                )
                .frame(maxWidth: .infinity, alignment: .leading)

                quickActionPanel
                    .frame(width: 320)
            }

            if let bannerContext = model.mainWindowContextBannerContext {
                LiveContextBanner(
                    context: bannerContext,
                    onSelectLivePreset: {
                        model.selectPreset(id: bannerContext.livePresetID)
                    },
                    onLoadLiveIntoDraft: {
                        isConfirmingLoadLiveIntoDraft = true
                    }
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.heroRadius)
                .fill(AppTheme.heroFill(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.heroRadius)
                .stroke(AppTheme.border(for: colorScheme, emphasized: true), lineWidth: 1)
        )
        .shadow(color: AppTheme.shadow(for: colorScheme), radius: 24, x: 0, y: 12)
    }

    private var workspaceHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("工作区")
                    .font(.headline)
                Text(workspaceMode.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                model.isShowingSettingsSheet = true
            } label: {
                Label("全局设置", systemImage: "gearshape.2")
            }
            .buttonStyle(AppSecondaryButtonStyle())
            .appHoverLift()

            Picker("工作区", selection: $workspaceMode) {
                ForEach(DetailWorkspaceMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 280)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.panelRadius)
                .fill(AppTheme.panelFill(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.panelRadius)
                .stroke(AppTheme.border(for: colorScheme), lineWidth: 1)
        )
    }

    private var sidebarActionDock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                model.addBlankPreset()
            } label: {
                Label("新建预设", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .appHoverLift()

            HStack(spacing: 8) {
                Button {
                    isShowingTemplateQuickCreate = true
                } label: {
                    Label("从模板新建", systemImage: "square.stack.3d.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AppSecondaryButtonStyle())
                .disabled(!model.canCreatePresetFromTemplate)
                .appHoverLift(enabled: model.canCreatePresetFromTemplate)
                .popover(isPresented: $isShowingTemplateQuickCreate, arrowEdge: .bottom) {
                    TemplateQuickCreatePopover(isPresented: $isShowingTemplateQuickCreate)
                        .environmentObject(model)
                }

                Menu {
                    Section("当前预设") {
                        Button("复制当前预设") {
                            model.duplicateSelectedPreset()
                        }

                        Button("导出当前预设") {
                            model.exportSelectedPreset()
                        }
                        .disabled(!model.canExportSelectedPreset)

                        Button("删除当前预设", role: .destructive) {
                            model.requestDeleteSelectedPreset()
                        }
                    }

                    Section("导入") {
                        Button("追加导入（同名自动重命名）") {
                            model.importPresetsByAppending()
                        }
                        Button("导入并覆盖同名") {
                            model.importPresetsByReplacingSameName()
                        }
                    }

                    Section("批量导出") {
                        Button("导出全部预设") {
                            model.exportAllPresets()
                        }
                        .disabled(!model.canExportAllPresets)

                        Button("导出收藏预设") {
                            model.exportFavoritePresets()
                        }
                        .disabled(!model.canExportFavoritePresets)
                    }
                } label: {
                    Label("更多", systemImage: "ellipsis.circle")
                        .frame(maxWidth: .infinity)
                }
                .menuStyle(.borderlessButton)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.pillRadius)
                        .fill(AppTheme.elevatedPanelFill(for: colorScheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.pillRadius)
                        .stroke(AppTheme.border(for: colorScheme), lineWidth: 1)
                )
                .appHoverLift()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.panelRadius)
                .fill(AppTheme.panelFill(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.panelRadius)
                .stroke(AppTheme.border(for: colorScheme), lineWidth: 1)
        )
        .padding(12)
    }

    private var templateWorkspace: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("模板工作台")
                        .font(.title3.weight(.semibold))
                    Text("模板相关操作已经从默认编辑流中抽离出来，这样高频编辑和低频模板管理不会再挤在同一屏。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                TemplateWorkbenchPanel()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var filteredSections: [SidebarSection] {
        let favorites = model.filteredPresets(
            from: model.favoritePresets,
            query: searchText,
            environmentFilter: environmentFilter,
            sortMode: sortMode
        )
        let nonFavoriteRecent = model.filteredPresets(
            from: model.recentPresets.filter { !model.isFavoritePreset(id: $0.id) },
            query: searchText,
            environmentFilter: environmentFilter,
            sortMode: sortMode
        )

        let hiddenIDs = Set(favorites.map(\.id) + nonFavoriteRecent.map(\.id))
        let remainingPresets = model.filteredPresets(
            from: model.presets.filter { !hiddenIDs.contains($0.id) },
            query: searchText,
            environmentFilter: environmentFilter,
            sortMode: sortMode
        )

        var sections: [SidebarSection] = []
        if !favorites.isEmpty {
            sections.append(SidebarSection(title: "收藏", presets: favorites))
        }
        if !nonFavoriteRecent.isEmpty {
            sections.append(SidebarSection(title: "最近使用", presets: nonFavoriteRecent))
        }
        if !remainingPresets.isEmpty {
            sections.append(SidebarSection(title: "全部预设", presets: remainingPresets))
        }

        return sections
    }

    private var environmentFilterTitle: String {
        environmentFilter?.title ?? "全部环境"
    }

    private var emptyStateDescription: String {
        if environmentFilter != nil {
            return "试试清除环境筛选，或调整搜索关键字。"
        }

        return "试试预设名称、接口地址或模型关键字。"
    }
}

private struct SidebarSection: Identifiable {
    let title: String
    let presets: [CodexPreset]

    var id: String { title }
}

private enum DetailWorkspaceMode: String, CaseIterable, Identifiable {
    case presetEditor
    case templateWorkbench

    var id: String { rawValue }

    var title: String {
        switch self {
        case .presetEditor:
            "预设编辑"
        case .templateWorkbench:
            "模板工作台"
        }
    }

    var description: String {
        switch self {
        case .presetEditor:
            "默认聚焦当前预设和草稿，减少低频模块对主流程的干扰。"
        case .templateWorkbench:
            "集中处理模板的创建、载入、重命名和清理，避免和编辑器抢空间。"
        }
    }
}
