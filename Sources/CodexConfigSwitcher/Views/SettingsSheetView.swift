import CodexConfigSwitcherCore
import SwiftUI

struct SettingsSheetView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("全局设置")
                        .font(.title2.bold())
                    Text("这里放低频设置，避免干扰预设编辑。")
                        .foregroundStyle(.secondary)
                }

                GroupBox("目标文件") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("当前平台的默认路径已经预置好；如果你临时改过路径，可以一键恢复。")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField("config.toml 路径", text: $model.paths.configPath)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                model.persistSettings()
                            }

                        HStack {
                            Button("选择 config.toml") {
                                model.chooseConfigFile()
                            }
                            .buttonStyle(AppSecondaryButtonStyle())
                            .appHoverLift()
                            Button("定位 config.toml") {
                                model.revealFile(at: model.paths.configPath)
                            }
                            .buttonStyle(AppSecondaryButtonStyle())
                            .appHoverLift()
                            Button("恢复默认路径") {
                                model.resetPathsToDefault()
                            }
                            .buttonStyle(AppSecondaryButtonStyle())
                            .appHoverLift()
                        }

                        TextField("auth.json 路径", text: $model.paths.authPath)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                model.persistSettings()
                            }

                        HStack {
                            Button("选择 auth.json") {
                                model.chooseAuthFile()
                            }
                            .buttonStyle(AppSecondaryButtonStyle())
                            .appHoverLift()
                            Button("定位 auth.json") {
                                model.revealFile(at: model.paths.authPath)
                            }
                            .buttonStyle(AppSecondaryButtonStyle())
                            .appHoverLift()
                        }
                    }
                    .padding(.top, 6)
                }

                GroupBox("应用联动") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("切换配置后提示是否自动重启目标软件", isOn: $model.restartPromptEnabled)

                        TextField("软件名称", text: $model.targetApp.displayName)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                model.persistSettings()
                            }

                        TextField("Bundle ID（macOS）", text: $model.targetApp.bundleIdentifier)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                model.persistSettings()
                            }

                        TextField("App 路径", text: $model.targetApp.appPath)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                model.persistSettings()
                            }

                        HStack {
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
                            Button("立即重启 \(model.targetApp.displayName)") {
                                model.restartTargetAppNow()
                            }
                            .buttonStyle(AppSecondaryButtonStyle())
                            .appHoverLift()
                        }

                        Text("当前状态：\(model.targetAppStatusText)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("默认目标会随平台变化；macOS 当前默认值为 \(ManagedAppTarget.codex.appPath)。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 6)
                }

                HStack {
                    Button("保存设置") {
                        model.persistSettings()
                    }
                    .buttonStyle(AppSecondaryButtonStyle())
                    .appHoverLift()

                    Spacer()

                    Button("完成") {
                        model.persistSettings()
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .appHoverLift()
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
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .groupBoxStyle(AppPanelGroupBoxStyle())
        }
        .frame(minWidth: 620, minHeight: 460)
        .onDisappear {
            model.persistSettings()
        }
    }
}
