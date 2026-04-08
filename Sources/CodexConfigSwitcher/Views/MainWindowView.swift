import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                List(selection: selectedPresetBinding) {
                    ForEach(model.presets) { preset in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(preset.name)
                                .font(.headline)
                            Text(preset.baseURL)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(preset.model) / \(preset.reviewModel)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                        .tag(preset.id)
                    }
                }

                Divider()

                HStack {
                    Button {
                        model.addBlankPreset()
                    } label: {
                        Label("新建", systemImage: "plus")
                    }

                    Button {
                        model.saveDraftAsNewPreset()
                    } label: {
                        Label("另存", systemImage: "square.on.square")
                    }

                    Button(role: .destructive) {
                        model.deleteSelectedPreset()
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
                .padding()
            }
            .navigationSplitViewColumnWidth(min: 240, ideal: 280)
        } detail: {
            PresetEditorView()
                .environmentObject(model)
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
    }

    private var selectedPresetBinding: Binding<UUID?> {
        Binding(
            get: { model.selectedPresetID },
            set: { model.selectPreset(id: $0) }
        )
    }
}
