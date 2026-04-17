import CodexConfigSwitcherCore
import Foundation
import Testing

struct ConnectionTestServiceTests {
    @Test
    func connectionTestSucceedsWhenModelExists() async {
        let service = ConnectionTestService { request in
            #expect(request.url?.absoluteString == "https://api.openai.com/v1/models")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-key")

            let data = Data(
                """
                {
                  "data": [
                    { "id": "gpt-5.4" },
                    { "id": "gpt-5.5" }
                  ]
                }
                """.utf8
            )
            let response = HTTPURLResponse(
                url: try #require(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )
            return (data, try #require(response))
        }

        let result = await service.testConnection(
            for: CodexPreset(
                name: "官方",
                model: "gpt-5.4",
                reviewModel: "gpt-5.4",
                baseURL: "https://api.openai.com/v1",
                authMode: "apikey",
                apiKey: "test-key"
            )
        )

        #expect(result.outcome == .success)
        #expect(result.statusCode == 200)
    }

    @Test
    func connectionTestWarnsWhenModelMissing() async {
        let service = ConnectionTestService { request in
            let data = Data(
                """
                { "data": [ { "id": "gpt-4.1" } ] }
                """.utf8
            )
            let response = HTTPURLResponse(
                url: try #require(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )
            return (data, try #require(response))
        }

        let result = await service.testConnection(
            for: CodexPreset(
                name: "代理",
                model: "gpt-5.4",
                reviewModel: "gpt-5.4",
                baseURL: "https://proxy.example.com/v1",
                authMode: "apikey",
                apiKey: "proxy-key"
            )
        )

        #expect(result.outcome == .warning)
    }

    @Test
    func connectionTestFailsOnUnauthorizedResponse() async {
        let service = ConnectionTestService { request in
            let response = HTTPURLResponse(
                url: try #require(request.url),
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )
            return (Data(), try #require(response))
        }

        let result = await service.testConnection(
            for: CodexPreset(
                name: "鉴权失败",
                model: "gpt-5.4",
                reviewModel: "gpt-5.4",
                baseURL: "https://proxy.example.com/v1",
                authMode: "apikey",
                apiKey: "bad-key"
            )
        )

        #expect(result.outcome == .failure)
        #expect(result.title == "鉴权失败")
    }

    @Test
    func connectionTestFailsOnInvalidBaseURL() async {
        let service = ConnectionTestService { _ in
            Issue.record("invalid URL should fail before sending request")
            throw CancellationError()
        }

        let result = await service.testConnection(
            for: CodexPreset(
                name: "坏地址",
                model: "gpt-5.4",
                reviewModel: "gpt-5.4",
                baseURL: "not-a-url",
                authMode: "apikey",
                apiKey: "key"
            )
        )

        #expect(result.outcome == .failure)
    }
}
