import CodexConfigSwitcherCore
import SwiftUI

struct PresetEditorView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var showPlaintextKey = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if model.hasUnsavedChanges {
                    infoBanner(
                        title: "未保存修改",
                        message: "当前草稿和所选预设不同，可以覆盖保存，也可以另存为新预设。",
                        tint: .orange
                    )
                }
                if let validationSummary = model.validationSummary {
                    infoBanner(
                        title: "应用前请先修正这些问题",
                        message: validationSummary,
                        tint: .orange
                    )
                }
                basicSection
                authSection
                connectionTestSection
                diffSection
                advancedSection
                statusSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .groupBoxStyle(AppPanelGroupBoxStyle())
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("编辑预设")
                        .font(.title2.bold())
                    Text(modeDescription)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Picker("编辑模式", selection: editorModeBinding) {
                    Text("基础模式").tag(PresetEditorMode.basic)
                    Text("高级模式").tag(PresetEditorMode.advanced)
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Button(primarySaveButtonTitle) {
                        performPrimarySave()
                    }
                    .buttonStyle(AppSecondaryButtonStyle())
                    .appHoverLift()

                    Button(model.isTestingConnection ? "测试中..." : "测试连接") {
                        model.testDraftConnection()
                    }
                    .disabled(model.isTestingConnection || !model.validationResult.isValid)
                    .buttonStyle(AppSecondaryButtonStyle())
                    .appHoverLift(enabled: !model.isTestingConnection && model.validationResult.isValid)

                    Menu {
                        Button("另存为新预设") {
                            model.saveDraftAsNewPreset()
                        }

                        Button("保存为模板") {
                            model.saveDraftAsTemplate()
                        }
                    } label: {
                        Label("更多", systemImage: "ellipsis.circle")
                    }

                    Spacer()

                    Button("立即应用到 Codex") {
                        model.applyDraft()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.validationResult.isValid)
                    .appHoverLift(enabled: model.validationResult.isValid)
                }

                connectionFeedbackBanner

                Text("模板只会保存非敏感字段，API Key 不会写入模板文件。基础模式默认隐藏底层配置键，切换到高级模式后可查看全部字段名。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.panelRadius)
                    .fill(AppTheme.panelFill(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.panelRadius)
                    .stroke(AppTheme.border(for: colorScheme), lineWidth: 1)
            )
        }
    }

    private var editorModeBinding: Binding<PresetEditorMode> {
        Binding(
            get: { model.presetEditorMode },
            set: { model.setPresetEditorMode($0) }
        )
    }

    private var modeDescription: String {
        if model.isAdvancedEditorMode {
            return "高级模式会展示完整字段，适合需要精细控制的场景。"
        }

        return "基础模式只保留高频字段，切换模式不会丢失当前草稿。"
    }

    @ViewBuilder
    private var connectionFeedbackBanner: some View {
        if model.isTestingConnection {
            HStack(alignment: .center, spacing: 12) {
                ProgressView()
                    .controlSize(.small)

                VStack(alignment: .leading, spacing: 4) {
                    Text("正在测试连接")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.blue)
                    Text("正在检查接口地址、认证信息和主模型可用性，结果会显示在这里。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.blue.opacity(colorScheme == .dark ? 0.16 : 0.10))
            )
        } else if let result = model.lastConnectionTestResult {
            infoBanner(
                title: result.title,
                message: connectionFeedbackMessage(for: result),
                tint: outcomeColor(for: result.outcome)
            )
        }
    }

    private var connectionTestSection: some View {
        infoBanner(
            title: "连接检查说明",
            message: "点击上方“测试连接”后，会访问当前接口的 `/models` 端点，并检查主模型是否出现在返回列表中。结果会固定显示在头部操作区，避免你在多个模块间来回切换。",
            tint: .blue
        )
    }

    private var basicSection: some View {
        GroupBox("基础配置") {
            VStack(alignment: .leading, spacing: 16) {
                LabeledFieldHelp(title: "预设名称", key: "name", showsKey: model.isAdvancedEditorMode) {
                    TextField("例如：官方接口 / 本地代理", text: $model.draft.name)
                        .textFieldStyle(.roundedBorder)
                }

                LabeledFieldHelp(title: "环境标签", key: "environment_tag", showsKey: model.isAdvancedEditorMode) {
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("环境标签", selection: $model.draft.environmentTag) {
                            ForEach(PresetEnvironmentTag.allCases, id: \.self) { tag in
                                Text(tag.title).tag(tag)
                            }
                        }
                        .pickerStyle(.segmented)

                        if model.draft.environmentTag.isHighRisk {
                            Text("当前标签会在应用前触发二次确认，适合代理或非默认服务环境。")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }

                LabeledFieldHelp(title: "接口地址", key: "base_url", showsKey: model.isAdvancedEditorMode) {
                    TextField("https://api.openai.com/v1", text: $model.draft.baseURL)
                        .textFieldStyle(.roundedBorder)
                }

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                    GridRow {
                        LabeledFieldHelp(title: "主模型", key: "model", showsKey: model.isAdvancedEditorMode) {
                            TextField("gpt-5.4", text: $model.draft.model)
                                .textFieldStyle(.roundedBorder)
                        }

                        LabeledFieldHelp(title: "评审模型", key: "review_model", showsKey: model.isAdvancedEditorMode) {
                            TextField("gpt-5.4", text: $model.draft.reviewModel)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }
            }
            .padding(.top, 6)
        }
    }

    private var authSection: some View {
        GroupBox("认证") {
            VStack(alignment: .leading, spacing: 16) {
                LabeledFieldHelp(title: "认证模式", key: "auth_mode", showsKey: model.isAdvancedEditorMode) {
                    TextField("apikey", text: $model.draft.authMode)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("API Key")
                            .font(.subheadline.weight(.semibold))
                        Spacer(minLength: 12)
                        if model.isAdvancedEditorMode {
                            Text("OPENAI_API_KEY")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("只保存在本机，不会进模板")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Toggle("显示 API Key 明文", isOn: $showPlaintextKey)

                    if showPlaintextKey {
                        TextField("sk-...", text: $model.draft.apiKey)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("sk-...", text: $model.draft.apiKey)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }
            .padding(.top, 6)
        }
    }

    private var advancedSection: some View {
        Group {
            if model.isAdvancedEditorMode {
                GroupBox("高级配置") {
                    VStack(alignment: .leading, spacing: 18) {
                        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                            GridRow {
                                LabeledFieldHelp(title: "模型 Provider", key: "model_provider") {
                                    TextField("OpenAI", text: $model.draft.modelProvider)
                                        .textFieldStyle(.roundedBorder)
                                }

                                LabeledFieldHelp(title: "Provider 名称", key: "provider.name") {
                                    TextField("OpenAI", text: $model.draft.providerName)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }

                            GridRow {
                                LabeledFieldHelp(title: "推理强度", key: "model_reasoning_effort") {
                                    TextField("xhigh", text: $model.draft.modelReasoningEffort)
                                        .textFieldStyle(.roundedBorder)
                                }

                                LabeledFieldHelp(title: "网络访问", key: "network_access") {
                                    TextField("enabled", text: $model.draft.networkAccess)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }

                            GridRow {
                                LabeledFieldHelp(title: "Wire API", key: "wire_api") {
                                    TextField("responses", text: $model.draft.wireAPI)
                                        .textFieldStyle(.roundedBorder)
                                }

                                LabeledFieldHelp(title: "是否要求 OpenAI 认证", key: "requires_openai_auth") {
                                    Toggle("启用", isOn: $model.draft.requiresOpenAIAuth)
                                }
                            }

                            GridRow {
                                LabeledFieldHelp(title: "上下文窗口", key: "model_context_window") {
                                    TextField("1000000", value: $model.draft.modelContextWindow, format: .number)
                                        .textFieldStyle(.roundedBorder)
                                }

                                LabeledFieldHelp(title: "自动压缩限制", key: "model_auto_compact_token_limit") {
                                    TextField("900000", value: $model.draft.modelAutoCompactTokenLimit, format: .number)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Toggle("关闭响应存储", isOn: $model.draft.disableResponseStorage)
                            Toggle("确认过 Windows WSL 设置", isOn: $model.draft.windowsWSLSetupAcknowledged)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            if let requestMaxRetries = model.draft.requestMaxRetries ?? model.lastLoaded?.preset.requestMaxRetries {
                                Text("保留 request_max_retries = \(requestMaxRetries)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if let streamMaxRetries = model.draft.streamMaxRetries ?? model.lastLoaded?.preset.streamMaxRetries {
                                Text("保留 stream_max_retries = \(streamMaxRetries)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if let streamIdleTimeoutMs = model.draft.streamIdleTimeoutMs ?? model.lastLoaded?.preset.streamIdleTimeoutMs {
                                Text("保留 stream_idle_timeout_ms = \(streamIdleTimeoutMs)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.top, 6)
                }
            } else {
                infoBanner(
                    title: "当前是基础模式",
                    message: "常用配置已经完整展示。切换到高级模式后，可以继续编辑 Provider、推理强度、上下文窗口等低频字段。",
                    tint: .blue
                )
            }
        }
    }

    private var diffSection: some View {
        GroupBox("应用前差异预览") {
            VStack(alignment: .leading, spacing: 12) {
                if model.lastLoaded == nil {
                    Text("重新读取当前配置后，这里会展示本次应用将变更的字段。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if model.changedDiffPreview.isEmpty {
                    infoBanner(
                        title: "当前草稿与 live 配置一致",
                        message: "现在点击应用不会产生字段变化。",
                        tint: .green
                    )
                } else {
                    Text("以下字段会在应用后发生变化。")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(model.changedDiffPreview) { diff in
                        PresetDiffRow(diff: diff)
                    }
                }
            }
            .padding(.top, 6)
        }
    }

    private var statusSection: some View {
        GroupBox("运行记录与备份") {
            VStack(alignment: .leading, spacing: 10) {
                Text(model.statusMessage)
                    .font(.body)

                if let lastLoaded = model.lastLoaded {
                    Text("最近读取：\(formatted(lastLoaded.loadedAt))")
                        .foregroundStyle(.secondary)
                }

                if let lastAppliedDate = model.lastAppliedDate {
                    Text("最近应用：\(formatted(lastAppliedDate))")
                        .foregroundStyle(.secondary)
                }

                Text("最近备份：\(model.latestBackupDisplayText)")
                    .foregroundStyle(.secondary)

                if let configBackupPath = model.lastApplied?.configBackupPath {
                    Text("config 备份：\(configBackupPath)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let authBackupPath = model.lastApplied?.authBackupPath {
                    Text("auth 备份：\(authBackupPath)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button("打开备份目录") {
                        model.revealBackupFolder()
                    }
                    .buttonStyle(AppSecondaryButtonStyle())
                    .appHoverLift()

                    Button("恢复最近备份") {
                        model.requestRestoreLatestBackup()
                    }
                    .disabled(model.latestBackup == nil)
                    .buttonStyle(AppSecondaryButtonStyle())
                    .appHoverLift(enabled: model.latestBackup != nil)
                }

                if !model.recentBackups.isEmpty {
                    Divider()

                    Text("最近备份历史")
                        .font(.subheadline.weight(.semibold))

                    ForEach(model.recentBackups, id: \.directoryPath) { backup in
                        BackupHistoryRow(
                            backup: backup,
                            formattedDate: formatted(backup.createdAt)
                        ) {
                            model.requestRestoreBackup(backup)
                        }
                    }
                }

                Divider()

                Text("最近操作历史")
                    .font(.subheadline.weight(.semibold))

                if model.recentOperationHistory.isEmpty {
                    Text("这里会记录最近的预设应用和备份恢复结果，便于追溯当前配置是怎么切过来的。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.recentOperationHistory) { entry in
                        PresetOperationHistoryRow(
                            entry: entry,
                            formattedDate: formatted(entry.operatedAt)
                        )
                    }
                }
            }
            .padding(.top, 6)
        }
    }

    private func infoBanner(title: String, message: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(tint.opacity(colorScheme == .dark ? 0.16 : 0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(tint.opacity(colorScheme == .dark ? 0.28 : 0.16), lineWidth: 1)
        )
    }

    private func outcomeColor(for outcome: ConnectionTestOutcome) -> Color {
        switch outcome {
        case .success:
            .green
        case .warning:
            .orange
        case .failure:
            .red
        }
    }

    private func statusCodeText(for result: ConnectionTestResult) -> String {
        guard let statusCode = result.statusCode else {
            return ""
        }
        return "\n状态码：\(statusCode)"
    }

    private func connectionFeedbackMessage(for result: ConnectionTestResult) -> String {
        "\(result.message)\n测试地址：\(result.endpoint)\(statusCodeText(for: result))"
    }

    private var primarySaveButtonTitle: String {
        model.selectedPreset == nil ? "保存为新预设" : "保存当前预设"
    }

    private func performPrimarySave() {
        if model.selectedPreset == nil {
            model.saveDraftAsNewPreset()
        } else {
            model.saveDraftToSelectedPreset()
        }
    }

    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}
