import SwiftUI

struct PresetEditorView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showPlaintextKey = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                fileSection
                presetSection
                restartSection
                providerSection
                runtimeSection
                apiKeySection
                statusSection
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Codex Config Switcher")
                .font(.largeTitle.bold())
            Text("菜单栏负责快切，主窗口负责完整编辑和保存预设。")
                .foregroundStyle(.secondary)
        }
    }

    private var fileSection: some View {
        GroupBox("目标文件") {
            VStack(alignment: .leading, spacing: 12) {
                TextField("config.toml 路径", text: $model.paths.configPath)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        model.persistSettings()
                    }

                TextField("auth.json 路径", text: $model.paths.authPath)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        model.persistSettings()
                    }

                HStack {
                    Button("保存路径") {
                        model.persistSettings()
                    }
                    Button("重新读取当前配置") {
                        model.reloadLiveConfiguration()
                    }
                    Button("把当前配置载入编辑区") {
                        model.loadLiveConfigurationIntoDraft()
                    }
                    Button("定位 config.toml") {
                        model.revealFile(at: model.paths.configPath)
                    }
                    Button("定位 auth.json") {
                        model.revealFile(at: model.paths.authPath)
                    }
                }
            }
            .padding(.top, 6)
        }
    }

    private var presetSection: some View {
        GroupBox("预设信息") {
            VStack(alignment: .leading, spacing: 12) {
                TextField("预设名称", text: $model.draft.name)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("覆盖当前预设") {
                        model.saveDraftToSelectedPreset()
                    }
                    Button("另存为新预设") {
                        model.saveDraftAsNewPreset()
                    }
                    Button("立即应用到 Codex") {
                        model.applyDraft()
                    }
                }
            }
            .padding(.top, 6)
        }
    }

    private var providerSection: some View {
        GroupBox("模型与 Provider") {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                GridRow {
                    Text("model_provider")
                    TextField("OpenAI", text: $model.draft.modelProvider)
                        .textFieldStyle(.roundedBorder)
                    Text("provider.name")
                    TextField("OpenAI", text: $model.draft.providerName)
                        .textFieldStyle(.roundedBorder)
                }

                GridRow {
                    Text("model")
                    TextField("gpt-5.4", text: $model.draft.model)
                        .textFieldStyle(.roundedBorder)
                    Text("review_model")
                    TextField("gpt-5.4", text: $model.draft.reviewModel)
                        .textFieldStyle(.roundedBorder)
                }

                GridRow {
                    Text("reasoning_effort")
                    TextField("xhigh", text: $model.draft.modelReasoningEffort)
                        .textFieldStyle(.roundedBorder)
                    Text("network_access")
                    TextField("enabled", text: $model.draft.networkAccess)
                        .textFieldStyle(.roundedBorder)
                }

                GridRow {
                    Text("base_url")
                    TextField("https://xiaojie6.top", text: $model.draft.baseURL)
                        .textFieldStyle(.roundedBorder)
                    Text("wire_api")
                    TextField("responses", text: $model.draft.wireAPI)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding(.top, 6)
        }
    }

    private var restartSection: some View {
        GroupBox("应用后联动") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("切换配置后提示是否自动重启目标软件", isOn: $model.restartPromptEnabled)

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                    GridRow {
                        Text("软件名称")
                        TextField("Codex", text: $model.targetApp.displayName)
                            .textFieldStyle(.roundedBorder)
                        Text("Bundle ID")
                        TextField("com.openai.codex", text: $model.targetApp.bundleIdentifier)
                            .textFieldStyle(.roundedBorder)
                    }

                    GridRow {
                        Text("App 路径")
                        TextField("/Applications/Codex.app", text: $model.targetApp.appPath)
                            .textFieldStyle(.roundedBorder)
                        Text("")
                        Text("")
                    }
                }

                HStack {
                    Button("保存重启设置") {
                        model.persistSettings()
                    }
                    Button("立即重启目标软件") {
                        model.restartTargetAppNow()
                    }
                }

                Text("默认目标软件已预设为本机 Codex，可按需改成别的 App。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 6)
        }
    }

    private var runtimeSection: some View {
        GroupBox("运行参数") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("disable_response_storage", isOn: $model.draft.disableResponseStorage)
                Toggle("windows_wsl_setup_acknowledged", isOn: $model.draft.windowsWSLSetupAcknowledged)
                Toggle("requires_openai_auth", isOn: $model.draft.requiresOpenAIAuth)

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                    GridRow {
                        Text("model_context_window")
                        TextField("1000000", value: $model.draft.modelContextWindow, format: .number)
                            .textFieldStyle(.roundedBorder)
                        Text("model_auto_compact_token_limit")
                        TextField("900000", value: $model.draft.modelAutoCompactTokenLimit, format: .number)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                if let requestMaxRetries = model.draft.requestMaxRetries
                    ?? model.lastLoaded?.preset.requestMaxRetries {
                    Text("保留 request_max_retries = \(requestMaxRetries)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let streamMaxRetries = model.draft.streamMaxRetries
                    ?? model.lastLoaded?.preset.streamMaxRetries {
                    Text("保留 stream_max_retries = \(streamMaxRetries)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let streamIdleTimeoutMs = model.draft.streamIdleTimeoutMs
                    ?? model.lastLoaded?.preset.streamIdleTimeoutMs {
                    Text("保留 stream_idle_timeout_ms = \(streamIdleTimeoutMs)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 6)
        }
    }

    private var apiKeySection: some View {
        GroupBox("认证") {
            VStack(alignment: .leading, spacing: 12) {
                TextField("auth_mode", text: $model.draft.authMode)
                    .textFieldStyle(.roundedBorder)

                Toggle("显示 API Key 明文", isOn: $showPlaintextKey)

                if showPlaintextKey {
                    TextField("OPENAI_API_KEY", text: $model.draft.apiKey)
                        .textFieldStyle(.roundedBorder)
                } else {
                    SecureField("OPENAI_API_KEY", text: $model.draft.apiKey)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding(.top, 6)
        }
    }

    private var statusSection: some View {
        GroupBox("状态") {
            VStack(alignment: .leading, spacing: 10) {
                Text(model.statusMessage)
                    .font(.body)

                if let lastLoaded = model.lastLoaded {
                    Text("最近读取：\(formatted(lastLoaded.loadedAt))")
                        .foregroundStyle(.secondary)
                }

                if let lastApplied = model.lastApplied {
                    Text("最近写入：\(formatted(lastApplied.appliedAt))")
                        .foregroundStyle(.secondary)
                    if let configBackupPath = lastApplied.configBackupPath {
                        Text("config 备份：\(configBackupPath)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let authBackupPath = lastApplied.authBackupPath {
                        Text("auth 备份：\(authBackupPath)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Button("打开备份目录") {
                    model.revealBackupFolder()
                }
            }
            .padding(.top, 6)
        }
    }

    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}
