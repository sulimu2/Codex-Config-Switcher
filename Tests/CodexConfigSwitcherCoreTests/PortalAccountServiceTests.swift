import CodexConfigSwitcherCore
import Foundation
import Testing

struct PortalAccountServiceTests {
    @Test
    func portalURLHelperNormalizesPortalAndPresetBaseURL() throws {
        let portalURL = try PortalURLHelper.normalizedPortalURL(
            from: "https://portal.example.com/team-a/api/v1/auth/me"
        )
        let inferredPortalURL = try PortalURLHelper.inferredPortalURL(
            fromAPIBaseURL: "https://gateway.example.com/team-a/v1"
        )
        let inferredPortalURLWithoutAPIHost = try PortalURLHelper.inferredPortalURL(
            fromAPIBaseURL: "https://api.xiaojie6.top/v1"
        )

        #expect(portalURL.absoluteString == "https://portal.example.com/team-a")
        #expect(inferredPortalURL.absoluteString == "https://gateway.example.com/team-a")
        #expect(inferredPortalURLWithoutAPIHost.absoluteString == "https://xiaojie6.top")
    }

    @Test
    func fetchAccountSnapshotLoadsProfileStatsAndUsageModels() async throws {
        let service = PortalAccountService { request in
            let url = try #require(request.url)
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer portal-token")

            let data: Data
            switch url.path {
            case "/api/v1/auth/me":
                data = Data(
                    """
                    {
                      "data": {
                        "id": "user-1",
                        "email": "demo@example.com",
                        "displayName": "Demo User",
                        "role": "admin"
                      }
                    }
                    """.utf8
                )
            case "/api/v1/usage/dashboard/stats":
                data = Data(
                    """
                    {
                      "data": {
                        "requestCount": 12,
                        "inputTokenCount": 100,
                        "outputTokenCount": 25,
                        "totalTokenCount": 125,
                        "quota": 20,
                        "usedQuota": 5
                      }
                    }
                    """.utf8
                )
            case "/api/v1/usage/dashboard/models":
                data = Data(
                    """
                    {
                      "data": [
                        {
                          "model": "gpt-5.4",
                          "requestCount": 10,
                          "totalTokenCount": 100
                        },
                        {
                          "model": "gpt-4.1",
                          "requestCount": 2,
                          "totalTokenCount": 25
                        }
                      ]
                    }
                    """.utf8
                )
            default:
                Issue.record("unexpected URL: \(url.absoluteString)")
                throw CancellationError()
            }

            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )
            return (data, try #require(response))
        }

        let snapshot = try await service.fetchAccountSnapshot(
            portalURL: "https://portal.example.com",
            accessToken: "portal-token"
        )

        #expect(snapshot.profile.name == "Demo User")
        #expect(snapshot.profile.email == "demo@example.com")
        #expect(snapshot.stats.totalTokenCount == 125)
        #expect(snapshot.stats.remainingQuota == 15)
        #expect(snapshot.usageModels.map(\.modelID) == ["gpt-5.4", "gpt-4.1"])
    }

    @Test
    func sessionBackedRequestRefreshesAfterUnauthorizedResponse() async throws {
        let recorder = PortalAccountRequestRecorder()

        let service = PortalAccountService(
            now: {
                Date(timeIntervalSince1970: 1_710_000_000)
            },
            sendRequest: { request in
                let url = try #require(request.url)
                let authorization = request.value(forHTTPHeaderField: "Authorization") ?? ""
                await recorder.record(path: url.path, authorization: authorization)

                let response: HTTPURLResponse
                let data: Data

                if url.path == "/api/v1/auth/me", authorization == "Bearer expired-token" {
                    response = try #require(
                        HTTPURLResponse(
                            url: url,
                            statusCode: 401,
                            httpVersion: nil,
                            headerFields: nil
                        )
                    )
                    data = Data()
                } else if url.path == "/api/v1/auth/refresh" {
                    data = Data(
                        """
                        {
                          "data": {
                            "access_token": "fresh-token",
                            "refresh_token": "fresh-refresh-token",
                            "expires_in": 3600
                          }
                        }
                        """.utf8
                    )
                    response = try #require(
                        HTTPURLResponse(
                            url: url,
                            statusCode: 200,
                            httpVersion: nil,
                            headerFields: nil
                        )
                    )
                } else if url.path == "/api/v1/auth/me", authorization == "Bearer fresh-token" {
                    data = Data(
                        """
                        {
                          "data": {
                            "id": "user-2",
                            "email": "fresh@example.com",
                            "name": "Fresh User"
                          }
                        }
                        """.utf8
                    )
                    response = try #require(
                        HTTPURLResponse(
                            url: url,
                            statusCode: 200,
                            httpVersion: nil,
                            headerFields: nil
                        )
                    )
                } else {
                    Issue.record("unexpected request \(url.path) with \(authorization)")
                    throw CancellationError()
                }

                return (data, response)
            }
        )

        let store = PortalAccountSessionStore(
            session: PortalAccountSession(
                portalURL: try PortalURLHelper.normalizedPortalURL(from: "https://portal.example.com"),
                accessToken: "expired-token",
                refreshToken: "refresh-token",
                expiresAt: Date(timeIntervalSince1970: 1_710_000_000 + 600)
            ),
            now: {
                Date(timeIntervalSince1970: 1_710_000_000)
            }
        )

        let profile = try await service.fetchAccountProfile(using: store)
        let storedSession = try #require(await store.snapshot())
        let requests = await recorder.requests()

        #expect(profile.email == "fresh@example.com")
        #expect(storedSession.accessToken == "fresh-token")
        #expect(storedSession.refreshToken == "fresh-refresh-token")
        #expect(requests.map(\.0) == ["/api/v1/auth/me", "/api/v1/auth/refresh", "/api/v1/auth/me"])
    }

    @Test
    func fetchAvailableModelsUsesPresetAPIKeyAndModelsEndpoint() async throws {
        let service = PortalAccountService { request in
            let url = try #require(request.url)
            #expect(url.absoluteString == "https://api.openai.com/v1/models")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer preset-key")

            let data = Data(
                """
                {
                  "data": [
                    { "id": "gpt-5.4", "owned_by": "openai", "created": 1710000000 },
                    { "id": "gpt-4.1", "owned_by": "openai", "created": 1710001000 }
                  ]
                }
                """.utf8
            )
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )
            return (data, try #require(response))
        }

        let models = try await service.fetchAvailableModels(
            for: CodexPreset(
                name: "官方",
                baseURL: "https://api.openai.com/v1",
                apiKey: "preset-key"
            )
        )

        #expect(models.map(\.id) == ["gpt-5.4", "gpt-4.1"])
        #expect(models[0].ownedBy == "openai")
    }
}

private actor PortalAccountRequestRecorder {
    private var entries: [(String, String)] = []

    func record(path: String, authorization: String) {
        entries.append((path, authorization))
    }

    func requests() -> [(String, String)] {
        entries
    }
}
