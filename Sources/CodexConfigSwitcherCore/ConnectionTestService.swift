import Foundation

public enum ConnectionTestOutcome: Equatable, Sendable {
    case success
    case warning
    case failure
}

public struct ConnectionTestResult: Equatable, Sendable {
    public var outcome: ConnectionTestOutcome
    public var endpoint: String
    public var statusCode: Int?
    public var title: String
    public var message: String

    public init(
        outcome: ConnectionTestOutcome,
        endpoint: String,
        statusCode: Int? = nil,
        title: String,
        message: String
    ) {
        self.outcome = outcome
        self.endpoint = endpoint
        self.statusCode = statusCode
        self.title = title
        self.message = message
    }
}

public struct ConnectionTestService: Sendable {
    public typealias RequestHandler = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)

    private let sendRequest: RequestHandler

    public init() {
        self.sendRequest = Self.defaultRequestHandler
    }

    public init(sendRequest: @escaping RequestHandler) {
        self.sendRequest = sendRequest
    }

    public func testConnection(for preset: CodexPreset) async -> ConnectionTestResult {
        do {
            let endpoint = try modelsEndpoint(from: preset.baseURL)
            let request = try makeRequest(for: preset, endpoint: endpoint)
            let (data, response) = try await sendRequest(request)

            if (200 ... 299).contains(response.statusCode) {
                let modelIDs = extractModelIDs(from: data)
                if modelIDs.isEmpty || modelIDs.contains(preset.model) {
                    return ConnectionTestResult(
                        outcome: .success,
                        endpoint: endpoint.absoluteString,
                        statusCode: response.statusCode,
                        title: "连接成功",
                        message: modelIDs.isEmpty
                            ? "接口连通，鉴权通过，已收到有效响应。"
                            : "接口连通，鉴权通过，且模型列表中包含当前主模型。"
                    )
                }

                return ConnectionTestResult(
                    outcome: .warning,
                    endpoint: endpoint.absoluteString,
                    statusCode: response.statusCode,
                    title: "连接成功，但模型未命中",
                    message: "接口连通且鉴权通过，但返回的模型列表里没有找到当前主模型：\(preset.model)。"
                )
            }

            if response.statusCode == 401 || response.statusCode == 403 {
                return ConnectionTestResult(
                    outcome: .failure,
                    endpoint: endpoint.absoluteString,
                    statusCode: response.statusCode,
                    title: "鉴权失败",
                    message: "接口已响应，但认证未通过，请检查 API Key、auth_mode 或网关鉴权配置。"
                )
            }

            if response.statusCode == 404 || response.statusCode == 405 {
                return ConnectionTestResult(
                    outcome: .failure,
                    endpoint: endpoint.absoluteString,
                    statusCode: response.statusCode,
                    title: "接口响应异常",
                    message: "已连到服务器，但 `\(endpoint.path)` 不可用，请检查 base_url 是否指向兼容 OpenAI 的 `/v1` 根路径。"
                )
            }

            return ConnectionTestResult(
                outcome: .failure,
                endpoint: endpoint.absoluteString,
                statusCode: response.statusCode,
                title: "连接失败",
                message: "接口返回了异常状态码：\(response.statusCode)。"
            )
        } catch {
            return ConnectionTestResult(
                outcome: .failure,
                endpoint: preset.baseURL,
                title: "连接失败",
                message: error.localizedDescription
            )
        }
    }

    private func makeRequest(for preset: CodexPreset, endpoint: URL) throws -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let authMode = preset.authMode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if authMode == "apikey" {
            let apiKey = preset.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !apiKey.isEmpty else {
                throw ConfigSwitchError.invalidFormat("当前认证模式需要 API Key，无法发起连接测试。")
            }
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    private func modelsEndpoint(from baseURL: String) throws -> URL {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let components = URLComponents(string: trimmed),
            let scheme = components.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            components.host?.isEmpty == false
        else {
            throw ConfigSwitchError.invalidFormat("接口地址不是合法的 http 或 https URL。")
        }

        var normalizedPath = components.path
        if normalizedPath.hasSuffix("/models") {
            return try requireURL(from: components)
        }

        if normalizedPath.isEmpty || normalizedPath == "/" {
            normalizedPath = "/models"
        } else if normalizedPath.hasSuffix("/") {
            normalizedPath += "models"
        } else {
            normalizedPath += "/models"
        }

        var updatedComponents = components
        updatedComponents.path = normalizedPath
        return try requireURL(from: updatedComponents)
    }

    private func requireURL(from components: URLComponents) throws -> URL {
        guard let url = components.url else {
            throw ConfigSwitchError.invalidFormat("无法生成测试连接地址，请检查 base_url。")
        }
        return url
    }

    private func extractModelIDs(from data: Data) -> [String] {
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let dictionary = object as? [String: Any],
            let items = dictionary["data"] as? [[String: Any]]
        else {
            return []
        }

        return items.compactMap { $0["id"] as? String }
    }

    private static func defaultRequestHandler(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ConfigSwitchError.invalidFormat("测试连接时没有拿到 HTTP 响应。")
        }
        return (data, httpResponse)
    }
}
