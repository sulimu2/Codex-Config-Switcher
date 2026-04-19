import CodexConfigSwitcherCore
import SwiftUI

struct OnboardingRootView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var isShowingInstallHelp = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                stepNavigator
                currentStepCard
                footerActions
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AppTheme.financeBackdrop(for: colorScheme))
        .sheet(item: $model.portalLoginContext) { context in
            PortalLoginSheetView(
                portalURL: context.portalURL,
                presetName: context.presetName,
                onComplete: { capture in
                    model.handlePortalLoginCapture(capture)
                },
                onCancel: {
                    model.cancelPortalLogin()
                }
            )
        }
        .sheet(isPresented: $isShowingInstallHelp) {
            InstallationHelpSheet()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("首次设置")
                        .font(.system(size: 34, weight: .bold))
                    Text("先把本机路径、当前 live 配置和目标应用确认清楚，再进入完整工作台。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text("步骤")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(model.onboardingProgressText)
                        .font(.headline.weight(.semibold))
                }
            }

            HStack(spacing: 10) {
                PresetStatusBadge(title: "首次打开引导", tint: AppTheme.brandBlue)
                Button("安装受阻说明") {
                    isShowingInstallHelp = true
                }
                .buttonStyle(AppSecondaryButtonStyle())
                .appHoverLift()
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.heroRadius)
                .fill(AppTheme.heroFill(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.heroRadius)
                .stroke(AppTheme.border(for: colorScheme, emphasized: true), lineWidth: 1)
        )
    }

    private var stepNavigator: some View {
        HStack(spacing: 10) {
            ForEach(OnboardingStep.allCases) { step in
                VStack(alignment: .leading, spacing: 4) {
                    Text(step.title)
                        .font(.caption.weight(.semibold))
                    Text(step.subtitle)
                        .font(.caption2)
                        .lineLimit(2)
                        .foregroundStyle(step == model.onboardingStep ? .secondary : .tertiary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.tileRadius)
                        .fill(step == model.onboardingStep ? AppTheme.financeInsetFill(for: colorScheme, emphasized: true) : AppTheme.financePanelFill(for: colorScheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.tileRadius)
                        .stroke(step == model.onboardingStep ? AppTheme.financeBorder(for: colorScheme, emphasized: true) : AppTheme.border(for: colorScheme), lineWidth: 1)
                )
            }
        }
    }

    @ViewBuilder
    private var currentStepCard: some View {
        switch model.onboardingStep {
        case .welcome:
            welcomeStep
        case .files:
            filesStep
        case .importLive:
            importLiveStep
        case .targetApp:
            targetAppStep
        case .portalAccount:
            portalAccountStep
        case .finish:
            finishStep
        }
    }

    private var welcomeStep: some View {
        onboardingCard(
            title: "先说明白这个工具会碰什么",
            summary: "它只管理你本机的 Codex 配置文件，不会因为进入向导就自动覆盖任何 live 配置。",
            body: [
                "这一步会做什么：检查你本机的 `config.toml`、`auth.json`、当前 live 配置和目标应用默认路径。",
                "这一步不会做什么：不会立刻改写配置，不会自动重启 Codex，不会上传你的 API Key 到远端。",
                "你可以稍后再做什么：站点账户登录、模板整理和高级参数都可以进入工作台后再处理。",
            ]
        )
    }

    private var filesStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            onboardingCard(
                title: "确认目标文件路径",
                summary: "先确保我们读的是你真正想管理的那一份 `config.toml` / `auth.json`。",
                body: [
                    "这一步会做什么：只读取路径并检查文件是否存在。",
                    "这一步不会做什么：不会覆盖这两个文件。",
                    "如果你不确定：先用默认路径，后面在设置里也能重改。",
                ]
            )

            GroupBox("当前路径") {
                VStack(alignment: .leading, spacing: 12) {
                    fileStatusRow(title: "config.toml", path: model.paths.configPath, exists: model.hasReadableConfigFile)
                    fileStatusRow(title: "auth.json", path: model.paths.authPath, exists: model.hasReadableAuthFile)

                    HStack(spacing: 10) {
                        Button("选择 config.toml") {
                            model.chooseConfigFile()
                        }
                        .buttonStyle(AppSecondaryButtonStyle())
                        .appHoverLift()

                        Button("选择 auth.json") {
                            model.chooseAuthFile()
                        }
                        .buttonStyle(AppSecondaryButtonStyle())
                        .appHoverLift()

                        Button("恢复默认路径") {
                            model.resetPathsToDefault()
                        }
                        .buttonStyle(AppSecondaryButtonStyle())
                        .appHoverLift()

                        Button("重新读取当前配置") {
                            model.refreshLiveConfigurationForOnboarding()
                        }
                        .buttonStyle(AppSecondaryButtonStyle())
                        .appHoverLift()
                    }
                }
                .padding(.top, 6)
            }
        }
    }

    private var importLiveStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            onboardingCard(
                title: "确认你的第一个预设",
                summary: "如果已经读到了当前 live 配置，应用会把它当作起点；如果没读到，也可以先建空白预设。",
                body: [
                    "这一步会做什么：把当前 live 配置整理成可编辑预设。",
                    "这一步不会做什么：不会立即写回 live 配置。",
                    "你可以稍后再做什么：改名、复制、导出和模板化都可以后续处理。",
                ]
            )

            GroupBox("当前检测结果") {
                VStack(alignment: .leading, spacing: 12) {
                    if let snapshot = model.lastLoaded {
                        Text("已读取到当前 live 配置")
                            .font(.subheadline.weight(.semibold))
                        Text("接口地址：\(snapshot.preset.baseURL.isEmpty ? "未读取到" : snapshot.preset.baseURL)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("模型：\(snapshot.preset.model) / \(snapshot.preset.reviewModel)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("当前已准备的预设：\(model.selectedPreset?.name ?? snapshot.preset.name)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button("额外创建一个空白预设") {
                            model.createBlankPresetForOnboarding()
                        }
                        .buttonStyle(AppSecondaryButtonStyle())
                        .appHoverLift()
                    } else {
                        Text("还没有成功读到 live 配置。")
                            .font(.subheadline.weight(.semibold))
                        Text("你可以返回上一步继续检查文件路径，或者先创建一个空白预设。")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button("创建空白预设") {
                            model.createBlankPresetForOnboarding()
                        }
                        .buttonStyle(AppSecondaryButtonStyle())
                        .appHoverLift()
                    }
                }
                .padding(.top, 6)
            }
        }
    }

    private var targetAppStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            onboardingCard(
                title: "设置切换后的应用联动",
                summary: "告诉应用：配置写入后，你通常希望联动哪个 App，以及是否提示重启。",
                body: [
                    "这一步会做什么：确认默认目标应用和切换后是否提示重启。",
                    "这一步不会做什么：不会在这里立刻重启目标应用。",
                    "你可以稍后再做什么：目标 App 路径和重启策略随时都能在全局设置里调整。",
                ]
            )

            GroupBox("应用联动") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("切换配置后提示是否自动重启目标软件", isOn: $model.restartPromptEnabled)

                    TextField("软件名称", text: $model.targetApp.displayName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            model.persistSettings()
                        }

                    TextField("App 路径", text: $model.targetApp.appPath)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            model.persistSettings()
                        }

                    HStack(spacing: 10) {
                        Button("选择目标 App") {
                            model.chooseTargetApplication()
                        }
                        .buttonStyle(AppSecondaryButtonStyle())
                        .appHoverLift()

                        Button("恢复默认目标 App") {
                            model.resetTargetApplicationToDefault()
                        }
                        .buttonStyle(AppSecondaryButtonStyle())
                        .appHoverLift()
                    }

                    Text("当前状态：\(model.targetAppStatusText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 6)
            }
        }
    }

    private var portalAccountStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            onboardingCard(
                title: "可选：绑定站点账户",
                summary: "如果你的预设走的是代理/网关站点，这一步可以顺手接管站点登录态，后面就能在应用里看余额、模型和 token 使用。",
                body: [
                    "这一步会做什么：打开站点登录页，并在成功登录后读取本地登录态。",
                    "这一步不会做什么：不会改写本地 Codex 配置，也不会强制你现在就登录。",
                    "你可以稍后再做什么：直接跳过，后面在预设编辑器里随时补登录。",
                ]
            )

            GroupBox("站点登录") {
                VStack(alignment: .leading, spacing: 12) {
                    if model.shouldSuggestPortalAccountOnboarding {
                        Text("当前可推导门户：\(model.selectedPresetAccountPortalURL)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("当前预设还没有可推导的站点门户，后面你也可以在预设里手动填写。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let overview = model.selectedPresetAccountOverview {
                        Text("已同步站点账户：\(overview.user.email ?? overview.user.username ?? "已登录")")
                            .font(.subheadline.weight(.semibold))
                        Text("余额：\(String(format: "$%.2f", overview.user.balance ?? 0))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if let session = model.selectedPresetAccountSession {
                        Text("已保存登录态：\(session.portalURL)")
                            .font(.subheadline.weight(.semibold))
                        Text("你可以现在刷新账户概览，也可以稍后在编辑器里处理。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 10) {
                        Button("登录站点账户") {
                            model.requestPortalLoginForDraft()
                        }
                        .disabled(model.shouldSuggestPortalAccountOnboarding == false)
                        .buttonStyle(AppSecondaryButtonStyle())
                        .appHoverLift(enabled: model.shouldSuggestPortalAccountOnboarding)

                        Button("刷新概览") {
                            model.refreshSelectedPresetAccountOverview()
                        }
                        .disabled(model.selectedPresetAccountSession == nil)
                        .buttonStyle(AppSecondaryButtonStyle())
                        .appHoverLift(enabled: model.selectedPresetAccountSession != nil)

                        if model.selectedPresetAccountSession != nil {
                            Button("清除登录态") {
                                model.clearSelectedPresetAccountSession()
                            }
                            .buttonStyle(AppSecondaryButtonStyle())
                            .appHoverLift()
                        }
                    }
                }
                .padding(.top, 6)
            }
        }
    }

    private var finishStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            onboardingCard(
                title: "可以进入工作台了",
                summary: "你已经完成了首轮必要配置，后面可以继续在工作台里细调预设、模板和账户面板。",
                body: [
                    "已确认的内容：目标文件路径、初始预设、目标应用联动。",
                    "还没做也没关系：站点账户登录、模板整理、高级配置都可以后续再补。",
                    "下一步建议：进入工作台后先跑一次连接测试，再决定是否立即应用。",
                ]
            )

            GroupBox("当前摘要") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("config.toml：\(model.paths.configPath)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("auth.json：\(model.paths.authPath)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("当前预设：\(model.selectedPreset?.name ?? "未创建")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("目标应用：\(model.targetApp.displayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 6)
            }
        }
    }

    private var footerActions: some View {
        HStack(spacing: 12) {
            Button("上一步") {
                model.goToPreviousOnboardingStep()
            }
            .disabled(model.onboardingStep == .welcome)
            .buttonStyle(AppSecondaryButtonStyle())
            .appHoverLift(enabled: model.onboardingStep != .welcome)

            if model.onboardingStep == .portalAccount {
                Button("跳过这一步") {
                    model.goToNextOnboardingStep()
                }
                .buttonStyle(AppSecondaryButtonStyle())
                .appHoverLift()
            }

            Spacer()

            if model.onboardingStep == .finish {
                Button("进入工作台") {
                    model.completeOnboarding()
                }
                .buttonStyle(.borderedProminent)
                .appHoverLift()
            } else {
                Button("继续") {
                    model.goToNextOnboardingStep()
                }
                .disabled(model.onboardingCanMoveForwardFromCurrentStep == false)
                .buttonStyle(.borderedProminent)
                .appHoverLift(enabled: model.onboardingCanMoveForwardFromCurrentStep)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.panelRadius)
                .fill(AppTheme.financePanelFill(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.panelRadius)
                .stroke(AppTheme.financeBorder(for: colorScheme), lineWidth: 1)
        )
    }

    private func onboardingCard(title: String, summary: String, body: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2.weight(.bold))

            Text(summary)
                .font(.body)
                .foregroundStyle(.secondary)

            ForEach(body, id: \.self) { line in
                Text(line)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.panelRadius)
                .fill(AppTheme.financePanelFill(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.panelRadius)
                .stroke(AppTheme.financeBorder(for: colorScheme), lineWidth: 1)
        )
    }

    private func fileStatusRow(title: String, path: String, exists: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                PresetStatusBadge(
                    title: exists ? "已找到" : "未找到",
                    tint: exists ? AppTheme.financePositive(for: colorScheme) : AppTheme.financeWarning(for: colorScheme)
                )
            }

            Text(path)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }
}

struct InstallationHelpSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("安装受阻说明")
                        .font(.title2.bold())
                    Text("如果应用还没成功打开，这一页的内容也建议同步写进 Release 页面和 README。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                helpCard(
                    title: "情况一：Apple 无法检查是否含恶意软件 / unknown developer",
                    body: [
                        "这通常是未 notarize 安装包的常见提示。",
                        "正确路径是：先尝试打开一次，再到“系统设置 > 隐私与安全性”，点击“仍要打开 / Open Anyway”。",
                        "这个按钮通常只会在最近一次被阻止后的约 1 小时内出现。",
                    ]
                )

                helpCard(
                    title: "情况二：应用已损坏 / modified or damaged",
                    body: [
                        "不要默认把它当成普通“未知开发者”提示来处理。",
                        "先重新下载并确认来源可信，再核对发布页提供的校验值。",
                        "只有在你明确知道这是可信内部构建时，才继续按系统安全设置放行。",
                    ]
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text("官方说明")
                        .font(.headline)

                    Link("Safely open apps on your Mac", destination: URL(string: "https://support.apple.com/en-tj/102445")!)
                    Link("Open a Mac app from an unknown developer", destination: URL(string: "https://support.apple.com/en-lamr/guide/mac-help/mh40616/26/mac/26")!)
                    Link("Apple can’t check app for malicious software", destination: URL(string: "https://support.apple.com/en-sg/guide/mac-help/mchleab3a043/mac")!)
                    Link("The app has been modified or damaged", destination: URL(string: "https://support.apple.com/en-sg/guide/mac-help/mh40619/mac")!)
                }

                HStack {
                    Spacer()
                    Button("关闭") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .appHoverLift()
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 680, minHeight: 560)
        .background(AppTheme.financeBackdrop(for: colorScheme))
    }

    private func helpCard(title: String, body: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            ForEach(body, id: \.self) { line in
                Text(line)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.panelRadius)
                .fill(AppTheme.financePanelFill(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.panelRadius)
                .stroke(AppTheme.financeBorder(for: colorScheme), lineWidth: 1)
        )
    }
}
