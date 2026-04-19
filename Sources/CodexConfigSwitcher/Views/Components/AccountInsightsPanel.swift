import CodexConfigSwitcherCore
import SwiftUI

struct AccountInsightsPanel: View {
    @Environment(\.colorScheme) private var colorScheme

    let portalURL: String
    let session: PresetAccountSessionRecord?
    let overview: PortalAccountOverview?
    let isLoading: Bool
    let errorMessage: String?
    let onLogin: () -> Void
    let onRefresh: () -> Void
    let onClearSession: () -> Void

    var body: some View {
        GroupBox("站点账号概览") {
            VStack(alignment: .leading, spacing: 16) {
                header

                if isLoading {
                    loadingState
                } else if let overview {
                    overviewContent(overview)
                } else if let errorMessage, !errorMessage.isEmpty {
                    errorState(errorMessage)
                } else {
                    emptyState
                }
            }
            .padding(.top, 6)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(portalHost)
                    .font(.headline.weight(.semibold))
                Text(headerSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                statusBadge

                Button(session == nil ? "登录站点账户" : "重新登录") {
                    onLogin()
                }
                .buttonStyle(AppSecondaryButtonStyle())
                .appHoverLift()

                Button("刷新概览") {
                    onRefresh()
                }
                .disabled(session == nil || isLoading)
                .buttonStyle(AppSecondaryButtonStyle())
                .appHoverLift(enabled: session != nil && !isLoading)

                if session != nil {
                    Button("清除登录态") {
                        onClearSession()
                    }
                    .buttonStyle(AppSecondaryButtonStyle())
                    .appHoverLift()
                }
            }
        }
    }

    private var statusBadge: some View {
        PresetStatusBadge(title: statusBadgeTitle, tint: statusBadgeTint)
    }

    private var loadingState: some View {
        HStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)

            VStack(alignment: .leading, spacing: 4) {
                Text("正在同步账户数据")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.brandBlue)
                Text("会依次读取站点登录态、余额、token 用量与模型信息。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.panelRadius)
                .fill(AppTheme.brandBlue.opacity(colorScheme == .dark ? 0.18 : 0.10))
        )
    }

    private func overviewContent(_ overview: PortalAccountOverview) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            metricsGrid(overview)

            HStack(alignment: .top, spacing: 14) {
                usageModelsBlock(overview)
                availableModelsBlock(overview)
            }

            Text("最近同步：\(formatted(overview.refreshedAt))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func metricsGrid(_ overview: PortalAccountOverview) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
            metricTile(
                title: "余额",
                value: currency(overview.user.balance),
                detail: overview.user.email ?? overview.user.username ?? "站点账户",
                tint: AppTheme.positiveGreen
            )
            metricTile(
                title: "累计 Tokens",
                value: compactNumber(overview.usageStats.totalTokenCount),
                detail: "模型统计总量",
                tint: AppTheme.brandBlue
            )
            metricTile(
                title: "输入 Tokens",
                value: compactNumber(overview.usageStats.inputTokenCount),
                detail: "Prompt / Input",
                tint: .indigo
            )
            metricTile(
                title: "输出 Tokens",
                value: compactNumber(overview.usageStats.outputTokenCount),
                detail: "Completion / Output",
                tint: .teal
            )
            metricTile(
                title: "请求数",
                value: compactNumber(overview.usageStats.requestCount),
                detail: "近一段时间使用量",
                tint: .orange
            )
            metricTile(
                title: "可用模型",
                value: "\(overview.availableModels.count)",
                detail: "基于当前 API Key 探测",
                tint: .purple
            )
            metricTile(
                title: "剩余额度",
                value: currency(overview.usageStats.remainingQuota),
                detail: quotaDetail(for: overview.usageStats),
                tint: AppTheme.brandBlueSoft
            )
        }
    }

    private func metricTile(title: String, value: String, detail: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.tileRadius)
                .fill(AppTheme.insetFill(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.tileRadius)
                .stroke(tint.opacity(colorScheme == .dark ? 0.28 : 0.14), lineWidth: 1)
        )
    }

    private func usageModelsBlock(_ overview: PortalAccountOverview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("近期用量模型")
                .font(.subheadline.weight(.semibold))

            if overview.modelUsage.isEmpty {
                Text("这段时间还没有记录到模型使用分布。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                let maxTokens = max(overview.modelUsage.map { $0.totalTokenCount ?? 0 }.max() ?? 1, 1)
                ForEach(Array(overview.modelUsage.prefix(5))) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(item.modelID)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            Text(compactNumber(item.totalTokenCount))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(AppTheme.brandBlue.opacity(colorScheme == .dark ? 0.14 : 0.08))
                                Capsule()
                                    .fill(AppTheme.brandBlue)
                                    .frame(width: max(proxy.size.width * CGFloat(item.totalTokenCount ?? 0) / CGFloat(maxTokens), 10))
                            }
                        }
                        .frame(height: 8)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.panelRadius)
                .fill(AppTheme.elevatedPanelFill(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.panelRadius)
                .stroke(AppTheme.border(for: colorScheme), lineWidth: 1)
        )
    }

    private func availableModelsBlock(_ overview: PortalAccountOverview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("当前可用模型")
                .font(.subheadline.weight(.semibold))

            if overview.availableModels.isEmpty {
                Text("没有从当前 API Key 探测到模型列表，可以先做一次连接测试或检查 Key。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(Array(overview.availableModels.prefix(14)), id: \.self) { model in
                        Text(model)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(AppTheme.brandBlue.opacity(colorScheme == .dark ? 0.16 : 0.08))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(AppTheme.brandBlue.opacity(colorScheme == .dark ? 0.26 : 0.14), lineWidth: 1)
                            )
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.panelRadius)
                .fill(AppTheme.elevatedPanelFill(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.panelRadius)
                .stroke(AppTheme.border(for: colorScheme), lineWidth: 1)
        )
    }

    private func errorState(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("账户数据同步失败")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.red)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.panelRadius)
                .fill(Color.red.opacity(colorScheme == .dark ? 0.16 : 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.panelRadius)
                .stroke(Color.red.opacity(colorScheme == .dark ? 0.28 : 0.16), lineWidth: 1)
        )
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("还没有绑定站点登录态")
                .font(.subheadline.weight(.semibold))
            Text("点击“登录站点账户”后，会在内置网页里完成登录和人机验证，成功后这里会展示余额、token 用量和模型概览。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.panelRadius)
                .fill(AppTheme.insetFill(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.panelRadius)
                .stroke(AppTheme.border(for: colorScheme), lineWidth: 1)
        )
    }

    private var portalHost: String {
        if let host = URL(string: portalURL)?.host, !host.isEmpty {
            return host
        }
        return portalURL.isEmpty ? "未配置门户地址" : portalURL
    }

    private var headerSubtitle: String {
        if let overview {
            return overview.user.email ?? overview.user.username ?? "站点账户"
        }
        if let session {
            return session.cachedUser?.email ?? "登录态已保存，可以手动刷新概览"
        }
        return "登录后可查看余额、模型与 token 使用情况"
    }

    private func currency(_ value: Double?) -> String {
        guard let value else {
            return "--"
        }
        return "$" + String(format: "%.2f", value)
    }

    private func compactNumber(_ value: Int?) -> String {
        guard let value else {
            return "--"
        }
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }
        return String(value)
    }

    private func quotaDetail(for stats: PortalAccountUsageStats) -> String {
        let quotaText = currency(stats.quota)
        let usedText = currency(stats.usedQuota)
        if quotaText == "--", usedText == "--" {
            return "站点未返回额度字段"
        }
        return "总额度 \(quotaText) / 已用 \(usedText)"
    }

    private var statusBadgeTitle: String {
        if isLoading {
            return "刷新中"
        }
        if overview != nil {
            return "已连接"
        }
        if errorMessage != nil {
            return "异常"
        }
        if session != nil {
            return "已登录"
        }
        return "未登录"
    }

    private var statusBadgeTint: Color {
        switch statusBadgeTitle {
        case "刷新中", "已登录":
            AppTheme.brandBlue
        case "已连接":
            AppTheme.positiveGreen
        case "异常":
            .red
        default:
            AppTheme.cautionAmber
        }
    }

    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat

    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? 320
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }

            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
        }

        return CGSize(width: maxWidth, height: currentY + rowHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var origin = CGPoint(x: bounds.minX, y: bounds.minY)
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if origin.x + size.width > bounds.maxX, origin.x > bounds.minX {
                origin.x = bounds.minX
                origin.y += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(
                at: origin,
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )

            origin.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
