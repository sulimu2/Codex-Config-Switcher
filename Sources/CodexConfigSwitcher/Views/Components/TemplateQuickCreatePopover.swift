import CodexConfigSwitcherCore
import SwiftUI

struct TemplateQuickCreatePopover: View {
    @Binding var isPresented: Bool
    @EnvironmentObject private var model: AppModel
    @Environment(\.colorScheme) private var colorScheme

    @State private var searchText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("从模板快速新建")
                    .font(.headline)
                Text("挑一个模板生成新预设，认证信息会留空，稍后再补。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("搜索模板", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(searchBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 1)
            )

            if filteredTemplates.isEmpty {
                Text(model.templates.isEmpty ? "还没有模板，先在右侧把草稿保存为模板。" : "没有找到匹配的模板。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 16)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(filteredTemplates) { template in
                            Button {
                                model.createPresetFromTemplate(id: template.id)
                                isPresented = false
                            } label: {
                                quickCreateRow(template)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: 280)
            }
        }
        .padding(16)
        .frame(width: 340)
    }

    private func quickCreateRow(_ template: CodexTemplate) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(template.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                PresetEnvironmentBadge(tag: template.environmentTag)

                Spacer()
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
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(rowBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(borderColor, lineWidth: 1)
        )
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
            ].contains { value in
                value.localizedCaseInsensitiveContains(trimmedQuery)
            }
        }
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

    private var rowBackground: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.04)
            : Color.black.opacity(0.018)
    }

    private var searchBackground: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.04)
            : Color.black.opacity(0.018)
    }

    private var borderColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.08)
    }
}
