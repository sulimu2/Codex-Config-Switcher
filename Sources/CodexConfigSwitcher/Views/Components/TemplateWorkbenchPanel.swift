import CodexConfigSwitcherCore
import SwiftUI

struct TemplateWorkbenchPanel: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.colorScheme) private var colorScheme

    @State private var searchText = ""
    @State private var selectedTemplateID: UUID?
    @State private var renameDraft = ""
    @State private var templatePendingDeletion: CodexTemplate?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            if model.templates.isEmpty {
                emptyState
            } else if filteredTemplates.isEmpty {
                emptySearchState
            } else {
                content
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(panelBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(panelBorder, lineWidth: 1)
        )
        .shadow(color: panelShadow, radius: 20, x: 0, y: 10)
        .onAppear {
            repairSelection()
        }
        .onChange(of: model.templates) { _ in
            repairSelection()
        }
        .onChange(of: searchText) { _ in
            repairSelection()
        }
        .confirmationDialog(
            "删除这个模板？",
            isPresented: pendingDeletionBinding,
            titleVisibility: .visible,
            presenting: templatePendingDeletion
        ) { template in
            Button("删除 \(template.name)", role: .destructive) {
                model.deleteTemplate(id: template.id)
                templatePendingDeletion = nil
            }
            Button("取消", role: .cancel) {
                templatePendingDeletion = nil
            }
        } message: { template in
            Text("模板删除后不会影响已经保存的预设。模板名：\(template.name)。")
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("模板工作台")
                        .font(.title3.weight(.semibold))

                    templateCapsule(text: "\(model.templates.count) 个模板", tint: .blue, fill: blueSurface)
                    templateCapsule(text: "敏感字段已隔离", tint: .secondary, fill: neutralSurface)
                }

                Text("保存个人常用配置骨架，用模板生成新预设，或把模板安全载入到当前草稿。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("搜索模板、地址或模型", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(width: 240)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(searchBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(panelBorder, lineWidth: 1)
            )
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("这里还没有模板")
                .font(.headline)

            Text("把当前草稿保存为第一个模板后，就能在这里管理模板、快速生成新预设，并安全复用非敏感字段。")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("把当前草稿保存为模板") {
                model.saveDraftAsTemplate()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(secondaryPanelBackground)
        )
    }

    private var emptySearchState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("没有找到匹配的模板")
                .font(.headline)

            Text("试试清空搜索，或改用模板名称、接口地址、模型名称来搜索。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(secondaryPanelBackground)
        )
    }

    private var content: some View {
        HStack(alignment: .top, spacing: 18) {
            templateList
                .frame(width: 300)

            if let selectedTemplate {
                templateDetail(for: selectedTemplate)
            }
        }
    }

    private var templateList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(filteredTemplates) { template in
                Button {
                    selectedTemplateID = template.id
                    renameDraft = template.name
                } label: {
                    TemplateWorkbenchRow(
                        template: template,
                        isSelected: template.id == selectedTemplate?.id
                    )
                }
                .buttonStyle(.plain)

                if template.id != filteredTemplates.last?.id {
                    Divider()
                        .padding(.leading, 14)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(secondaryPanelBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(panelBorder, lineWidth: 1)
        )
    }

    private func templateDetail(for template: CodexTemplate) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(template.name)
                            .font(.title3.weight(.semibold))
                            .lineLimit(1)

                        PresetEnvironmentBadge(tag: template.environmentTag)
                    }

                    Text(compactBaseURL(template.baseURL))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        templateCapsule(text: template.model, tint: .blue, fill: blueSurface)
                        templateCapsule(text: template.authMode, tint: .secondary, fill: neutralSurface)
                        if template.requiresOpenAIAuth {
                            templateCapsule(text: "OpenAI Auth", tint: .green, fill: greenSurface)
                        }
                    }
                }

                Spacer()

                Button("从模板创建新预设") {
                    model.createPresetFromTemplate(id: template.id)
                }
                .buttonStyle(.borderedProminent)
            }

            Divider()

            LazyVGrid(columns: detailColumns, alignment: .leading, spacing: 12) {
                templateFact(title: "主模型", value: template.model)
                templateFact(title: "评审模型", value: template.reviewModel)
                templateFact(title: "Provider", value: template.providerName)
                templateFact(title: "Wire API", value: template.wireAPI)
                templateFact(title: "上下文窗口", value: "\(template.modelContextWindow)")
                templateFact(title: "自动压缩限制", value: "\(template.modelAutoCompactTokenLimit)")
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("模板操作")
                    .font(.subheadline.weight(.semibold))

                HStack {
                    Button("载入到当前草稿") {
                        model.loadTemplateIntoDraft(id: template.id)
                    }

                    Button("用当前草稿覆盖模板") {
                        model.overwriteTemplate(id: template.id)
                    }
                }

                HStack(alignment: .center, spacing: 10) {
                    TextField("模板名称", text: $renameDraft)
                        .textFieldStyle(.roundedBorder)

                    Button("重命名") {
                        model.renameTemplate(id: template.id, to: renameDraft)
                    }
                    .disabled(!canRename(template))
                }

                HStack {
                    Button("删除模板", role: .destructive) {
                        templatePendingDeletion = template
                    }

                    Spacer()
                }
            }

            Text("载入模板只会更新当前草稿，不会直接覆盖已选预设；模板始终不会继承或保存 API Key。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(secondaryPanelBackground)
                )
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(secondaryPanelBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(panelBorder, lineWidth: 1)
        )
    }

    private func templateFact(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.body.weight(.medium))
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(detailCellBackground)
        )
    }

    private func templateCapsule(text: String, tint: Color, fill: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(fill)
            )
    }

    private func canRename(_ template: CodexTemplate) -> Bool {
        let trimmed = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != template.name
    }

    private func repairSelection() {
        guard !filteredTemplates.isEmpty else {
            selectedTemplateID = nil
            renameDraft = ""
            return
        }

        if let selectedTemplateID,
           let matched = filteredTemplates.first(where: { $0.id == selectedTemplateID }) {
            renameDraft = matched.name
            return
        }

        selectedTemplateID = filteredTemplates.first?.id
        renameDraft = filteredTemplates.first?.name ?? ""
    }

    private var filteredTemplates: [CodexTemplate] {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return model.templates
        }

        return model.templates.filter { template in
            [
                template.name,
                template.environmentTag.title,
                template.environmentTag.rawValue,
                template.baseURL,
                template.model,
                template.reviewModel,
                template.authMode,
            ].contains { value in
                value.localizedCaseInsensitiveContains(trimmedQuery)
            }
        }
    }

    private var selectedTemplate: CodexTemplate? {
        guard let selectedTemplateID else {
            return filteredTemplates.first
        }

        return filteredTemplates.first(where: { $0.id == selectedTemplateID }) ?? filteredTemplates.first
    }

    private var detailColumns: [GridItem] {
        [
            GridItem(.flexible(minimum: 140)),
            GridItem(.flexible(minimum: 140)),
            GridItem(.flexible(minimum: 140)),
        ]
    }

    private var pendingDeletionBinding: Binding<Bool> {
        Binding(
            get: { templatePendingDeletion != nil },
            set: { if !$0 { templatePendingDeletion = nil } }
        )
    }

    private func compactBaseURL(_ baseURL: String) -> String {
        guard
            let url = URL(string: baseURL),
            let host = url.host
        else {
            return baseURL.isEmpty ? "未配置接口地址" : baseURL
        }

        return url.path.isEmpty || url.path == "/" ? host : "\(host)\(url.path)"
    }

    private var panelBackground: Color {
        colorScheme == .dark
            ? Color(nsColor: .controlBackgroundColor)
            : Color(red: 0.974, green: 0.966, blue: 0.954)
    }

    private var secondaryPanelBackground: Color {
        colorScheme == .dark
            ? Color(nsColor: .windowBackgroundColor)
            : .white
    }

    private var detailCellBackground: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.04)
            : Color.black.opacity(0.018)
    }

    private var searchBackground: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.04)
            : Color.white.opacity(0.82)
    }

    private var panelBorder: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.08)
    }

    private var panelShadow: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.18)
            : Color.black.opacity(0.06)
    }

    private var blueSurface: Color {
        Color.blue.opacity(colorScheme == .dark ? 0.18 : 0.10)
    }

    private var neutralSurface: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.05)
    }

    private var greenSurface: Color {
        Color.green.opacity(colorScheme == .dark ? 0.18 : 0.10)
    }
}

private struct TemplateWorkbenchRow: View {
    let template: CodexTemplate
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(template.name)
                        .font(.body.weight(.medium))
                        .lineLimit(1)

                    PresetEnvironmentBadge(tag: template.environmentTag)
                }

                Spacer()

                Image(systemName: isSelected ? "chevron.right.circle.fill" : "chevron.right.circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.55))
            }

            Text(compactBaseURL(template.baseURL))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text("\(template.model) / \(template.reviewModel)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isSelected ? Color.accentColor.opacity(0.10) : .clear)
        )
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private func compactBaseURL(_ baseURL: String) -> String {
        guard
            let url = URL(string: baseURL),
            let host = url.host
        else {
            return baseURL.isEmpty ? "未配置接口地址" : baseURL
        }

        return url.path.isEmpty || url.path == "/" ? host : "\(host)\(url.path)"
    }
}
