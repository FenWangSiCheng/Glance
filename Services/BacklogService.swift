import Foundation

actor BacklogService {
    enum BacklogError: LocalizedError {
        case invalidConfiguration
        case invalidURL
        case networkError(Error)
        case invalidResponse
        case apiError(String)
        case decodingError(Error)

        var errorDescription: String? {
            switch self {
            case .invalidConfiguration:
                return "Backlog 配置无效，请检查 URL 和 API Key"
            case .invalidURL:
                return "无效的 URL"
            case .networkError(let error):
                return "网络错误: \(error.localizedDescription)"
            case .invalidResponse:
                return "服务器响应无效"
            case .apiError(let message):
                return "API 错误: \(message)"
            case .decodingError(let error):
                return "数据解析错误: \(error.localizedDescription)"
            }
        }
    }

    private let host: String
    private let apiKey: String

    private var baseURL: String {
        "https://\(host)/api/v2"
    }

    private static func extractHost(from urlString: String) -> String {
        var cleaned = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.hasPrefix("https://") {
            cleaned = String(cleaned.dropFirst(8))
        } else if cleaned.hasPrefix("http://") {
            cleaned = String(cleaned.dropFirst(7))
        }

        if let slashIndex = cleaned.firstIndex(of: "/") {
            cleaned = String(cleaned[..<slashIndex])
        }

        return cleaned
    }

    init(backlogURL: String, apiKey: String) {
        self.host = Self.extractHost(from: backlogURL)
        self.apiKey = apiKey
    }

    func fetchMyIssues() async throws -> [BacklogIssue] {
        guard !host.isEmpty, !apiKey.isEmpty else {
            print(
                "❌ [BacklogService] Invalid configuration: host=\(host.isEmpty ? "empty" : "set"), apiKey=\(apiKey.isEmpty ? "empty" : "set")"
            )
            throw BacklogError.invalidConfiguration
        }

        print("🔄 [BacklogService] Fetching user info...")
        let myself = try await fetchMyself()
        print("✅ [BacklogService] Got user: id=\(myself.id), name=\(myself.name)")

        var components = URLComponents(string: "\(baseURL)/issues")!
        components.queryItems = [
            URLQueryItem(name: "apiKey", value: apiKey),
            URLQueryItem(name: "assigneeId[]", value: String(myself.id)),
            URLQueryItem(name: "count", value: "100"),
        ]

        guard let url = components.url else {
            print("❌ [BacklogService] URL construction failed")
            throw BacklogError.invalidURL
        }

        print("🌐 [BacklogService] Request URL: \(url.absoluteString.replacingOccurrences(of: apiKey, with: "***"))")

        let allIssues: [BacklogIssue] = try await fetch(url, operation: "Fetch issues")
        let openIssues = allIssues.filter { $0.status?.id != 4 }

        print(
            "✅ [BacklogService] Successfully fetched \(allIssues.count) issues, \(openIssues.count) open issues (filtered out \(allIssues.count - openIssues.count) closed)"
        )
        return openIssues
    }

    private func fetchMyself() async throws -> BacklogUser {
        let urlString = "\(baseURL)/users/myself?apiKey=\(apiKey)"
        print("🔍 [BacklogService] fetchMyself URL: \(baseURL)/users/myself?apiKey=***")

        guard let url = URL(string: urlString) else {
            print("❌ [BacklogService] fetchMyself URL invalid")
            throw BacklogError.invalidURL
        }

        return try await fetch(url, operation: "Fetch current user")
    }

    private func fetch<Response: Decodable>(_ url: URL, operation: String) async throws -> Response {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [BacklogService] \(operation): invalid response")
                throw BacklogError.invalidResponse
            }

            print("📡 [BacklogService] \(operation) HTTP status code: \(httpResponse.statusCode)")

            guard httpResponse.statusCode == 200 else {
                let responseString = String(data: data, encoding: .utf8) ?? "Unable to parse"
                print("❌ [BacklogService] \(operation) error response: \(responseString)")

                if let errorResponse = try? JSONDecoder().decode(BacklogAPIError.self, from: data) {
                    throw BacklogError.apiError(errorResponse.errors.first?.message ?? "未知错误")
                }
                throw BacklogError.apiError("HTTP \(httpResponse.statusCode)")
            }

            return try JSONDecoder().decode(Response.self, from: data)
        } catch let error as BacklogError {
            throw error
        } catch let error as DecodingError {
            throw BacklogError.decodingError(error)
        } catch {
            throw BacklogError.networkError(error)
        }
    }

    func testConnection() async throws -> Bool {
        _ = try await fetchMyself()
        return true
    }
}

private struct BacklogUser: Codable {
    let id: Int
    let userId: String?
    let name: String
}

private struct BacklogAPIError: Codable {
    let errors: [BacklogErrorDetail]
}

private struct BacklogErrorDetail: Codable {
    let message: String
    let code: Int
}
