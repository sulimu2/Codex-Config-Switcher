import AppKit
import CodexConfigSwitcherCore
import SwiftUI
import WebKit

struct PortalLoginSheetView: View {
    @Environment(\.colorScheme) private var colorScheme

    private let presetName: String
    private let onComplete: (PortalLoginCapture) -> Void
    private let onCancel: () -> Void

    @StateObject private var model: PortalLoginSheetModel

    init(
        portalURL: String,
        presetName: String,
        onComplete: @escaping (PortalLoginCapture) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.presetName = presetName
        self.onComplete = onComplete
        self.onCancel = onCancel
        _model = StateObject(
            wrappedValue: PortalLoginSheetModel(
                portalURL: portalURL,
                onCapture: onComplete
            )
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            bodyContent
        }
        .frame(minWidth: 920, minHeight: 700)
        .background(AppTheme.financeBackdrop(for: colorScheme))
        .onAppear {
            model.loadLoginPage()
        }
        .onDisappear {
            model.stop()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("登录站点账户")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(headerPrimaryTextColor)
                    Text("当前预设：\(presetName)")
                        .font(.caption)
                        .foregroundStyle(headerSecondaryTextColor)
                }

                Spacer()

                Button("取消") {
                    onCancel()
                }
                .buttonStyle(AppSecondaryButtonStyle())
                .appHoverLift()
            }

            HStack(spacing: 8) {
                PresetStatusBadge(title: model.statusTitle, tint: model.statusTint)
                Text(model.portalHost)
                    .font(.caption)
                    .foregroundStyle(headerSecondaryTextColor)
            }

            Text(model.statusMessage)
                .font(.caption)
                .foregroundStyle(headerSecondaryTextColor)

            HStack(spacing: 8) {
                Button("重新加载") {
                    model.reload()
                }
                .buttonStyle(AppSecondaryButtonStyle())
                .appHoverLift()

                Button("在默认浏览器打开") {
                    model.openInDefaultBrowser()
                }
                .buttonStyle(AppSecondaryButtonStyle())
                .appHoverLift()
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.financePanelFill(for: colorScheme).opacity(0.98))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.financeBorder(for: colorScheme))
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private var bodyContent: some View {
        if let errorMessage = model.errorMessage {
            VStack(alignment: .leading, spacing: 12) {
                Text("无法打开站点登录页")
                    .font(.headline)
                    .foregroundStyle(headerPrimaryTextColor)
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(headerSecondaryTextColor)
                Button("关闭") {
                    onCancel()
                }
                .buttonStyle(AppSecondaryButtonStyle())
                .appHoverLift()
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(AppTheme.financeBackdrop(for: colorScheme))
        } else {
            PortalWebViewContainer(webView: model.webView)
                .overlay(alignment: .bottomLeading) {
                    if let email = model.detectedUser?.email ?? model.detectedUser?.username {
                        Label("已检测到登录态：\(email)", systemImage: "checkmark.shield")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(AppTheme.positiveGreen.opacity(0.14))
                            )
                            .padding(16)
                    }
                }
        }
    }

    private var headerPrimaryTextColor: Color {
        colorScheme == .dark ? .white : Color.black.opacity(0.90)
    }

    private var headerSecondaryTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.76) : Color.black.opacity(0.62)
    }
}

@MainActor
private final class PortalLoginSheetModel: NSObject, ObservableObject, WKNavigationDelegate {
    @Published var statusMessage = "请在内置网页里完成登录、人机验证和跳转。检测到 `auth_token` 后会自动接管。"
    @Published var errorMessage: String?
    @Published var detectedUser: PortalAuthenticatedUser?
    @Published var statusTitle = "等待登录"
    @Published var statusTint: Color = AppTheme.cautionAmber

    let portalURL: String
    let webView: WKWebView

    private let onCapture: (PortalLoginCapture) -> Void
    private var pollingTimer: Timer?
    private var hasCompletedCapture = false

    init(portalURL: String, onCapture: @escaping (PortalLoginCapture) -> Void) {
        self.portalURL = portalURL
        self.onCapture = onCapture

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        self.webView = WKWebView(frame: .zero, configuration: configuration)

        super.init()

        webView.navigationDelegate = self
    }

    var portalHost: String {
        URL(string: portalURL)?.host ?? portalURL
    }

    func loadLoginPage() {
        guard let loginURL = loginURL else {
            errorMessage = "站点门户地址不是合法 URL：\(portalURL)"
            statusTitle = "地址错误"
            statusTint = .red
            return
        }

        errorMessage = nil
        let request = URLRequest(url: loginURL)
        webView.load(request)
        startPollingIfNeeded()
    }

    func reload() {
        errorMessage = nil
        hasCompletedCapture = false
        if webView.url == nil {
            loadLoginPage()
        } else {
            webView.reload()
        }
        probeSession()
    }

    func stop() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    func openInDefaultBrowser() {
        guard let url = loginURL else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        errorMessage = nil
        updateStatus(path: webView.url?.path)
        probeSession()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard shouldPresentWebViewError(error) else {
            return
        }
        errorMessage = error.localizedDescription
        statusTitle = "加载失败"
        statusTint = .red
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard shouldPresentWebViewError(error) else {
            return
        }
        errorMessage = error.localizedDescription
        statusTitle = "加载失败"
        statusTint = .red
    }

    private var loginURL: URL? {
        let trimmedPortalURL = portalURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let baseURL = URL(string: trimmedPortalURL) else {
            return nil
        }

        return baseURL.appendingPathComponent("login")
    }

    private func startPollingIfNeeded() {
        guard pollingTimer == nil else {
            return
        }

        pollingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.probeSession()
            }
        }
    }

    private func updateStatus(path: String?) {
        if hasCompletedCapture {
            statusTitle = "已接管"
            statusTint = AppTheme.positiveGreen
            statusMessage = "检测到有效登录态，正在回写到当前预设。"
            return
        }

        switch path {
        case "/login":
            statusTitle = "等待登录"
            statusTint = AppTheme.cautionAmber
            statusMessage = "请完成邮箱密码登录与 Cloudflare Turnstile 验证。成功后通常会跳到 `/dashboard`。"
        case "/dashboard", "/profile", "/keys", "/usage":
            statusTitle = "检测中"
            statusTint = AppTheme.brandBlue
            statusMessage = "已经进入站点工作区，正在读取本地登录 token。"
        default:
            statusTitle = "处理中"
            statusTint = AppTheme.brandBlueSoft
            statusMessage = "正在监听页面跳转和本地登录态。"
        }
    }

    private func probeSession() {
        guard !hasCompletedCapture else {
            return
        }

        let script =
            """
            JSON.stringify({
              path: window.location.pathname,
              authToken: localStorage.getItem('auth_token'),
              refreshToken: localStorage.getItem('refresh_token'),
              tokenExpiresAt: localStorage.getItem('token_expires_at'),
              authUser: localStorage.getItem('auth_user')
            })
            """

        webView.evaluateJavaScript(script) { [weak self] result, _ in
            guard let self else {
                return
            }

            if let payload = self.decodeProbeResult(result) {
                self.updateStatus(path: payload.path)
                self.detectedUser = payload.user

                guard let authToken = payload.authToken, !authToken.isEmpty else {
                    return
                }

                self.hasCompletedCapture = true
                self.statusTitle = "已接管"
                self.statusTint = AppTheme.positiveGreen
                self.statusMessage = "检测到站点登录态，正在回写并刷新账户概览。"
                self.onCapture(
                    PortalLoginCapture(
                        portalURL: self.portalURL,
                        accessToken: authToken,
                        refreshToken: payload.refreshToken,
                        tokenExpiresAt: payload.tokenExpiresAt,
                        user: payload.user
                    )
                )
            }
        }
    }

    private func shouldPresentWebViewError(_ error: Error) -> Bool {
        let nsError = error as NSError

        if nsError.domain == NSURLErrorDomain,
           nsError.code == NSURLErrorCancelled {
            return false
        }

        if nsError.domain == "WebKitErrorDomain",
           nsError.code == 102 {
            return false
        }

        return true
    }

    private func decodeProbeResult(_ raw: Any?) -> ProbePayload? {
        guard
            let string = raw as? String,
            let data = string.data(using: .utf8),
            let dictionary = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        let path = dictionary["path"] as? String
        let authToken = dictionary["authToken"] as? String
        let refreshToken = dictionary["refreshToken"] as? String
        let tokenExpiresAt: Date?

        if let millisecondsText = dictionary["tokenExpiresAt"] as? String,
           let milliseconds = Double(millisecondsText) {
            tokenExpiresAt = Date(timeIntervalSince1970: milliseconds / 1000)
        } else {
            tokenExpiresAt = nil
        }

        let user: PortalAuthenticatedUser?
        if let authUserText = dictionary["authUser"] as? String,
           let userData = authUserText.data(using: .utf8) {
            user = try? JSONDecoder().decode(PortalAuthenticatedUser.self, from: userData)
        } else {
            user = nil
        }

        return ProbePayload(
            path: path,
            authToken: authToken,
            refreshToken: refreshToken,
            tokenExpiresAt: tokenExpiresAt,
            user: user
        )
    }
}

private struct PortalWebViewContainer: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> WKWebView {
        webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

private struct ProbePayload {
    var path: String?
    var authToken: String?
    var refreshToken: String?
    var tokenExpiresAt: Date?
    var user: PortalAuthenticatedUser?
}
