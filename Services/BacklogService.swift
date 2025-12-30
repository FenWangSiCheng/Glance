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

    /// 从完整 URL 中提取 host
    /// 例如: "https://fcn-dev.backlog.jp/" -> "fcn-dev.backlog.jp"
    private static func extractHost(from urlString: String) -> String {
        var cleaned = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        // 移除协议前缀
        if cleaned.hasPrefix("https://") {
            cleaned = String(cleaned.dropFirst(8))
        } else if cleaned.hasPrefix("http://") {
            cleaned = String(cleaned.dropFirst(7))
        }

        // 移除路径和尾部斜杠
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
            print("❌ [BacklogService] 配置无效: host=\(host.isEmpty ? "空" : "有值"), apiKey=\(apiKey.isEmpty ? "空" : "有值")")
            throw BacklogError.invalidConfiguration
        }

        print("🔄 [BacklogService] 开始获取用户信息...")
        let myself = try await fetchMyself()
        print("✅ [BacklogService] 获取到用户: id=\(myself.id), name=\(myself.name)")

        // 使用 URLComponents 正确编码 URL
        var components = URLComponents(string: "\(baseURL)/issues")!
        components.queryItems = [
            URLQueryItem(name: "apiKey", value: apiKey),
            URLQueryItem(name: "assigneeId[]", value: String(myself.id)),
            URLQueryItem(name: "statusId[]", value: "1"),
            URLQueryItem(name: "statusId[]", value: "2"),
            URLQueryItem(name: "statusId[]", value: "3"),
            URLQueryItem(name: "count", value: "100")
        ]

        guard let url = components.url else {
            print("❌ [BacklogService] URL 构建失败")
            throw BacklogError.invalidURL
        }

        print("🌐 [BacklogService] 请求 URL: \(url.absoluteString.replacingOccurrences(of: apiKey, with: "***"))")

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [BacklogService] 响应无效")
                throw BacklogError.invalidResponse
            }

            print("📡 [BacklogService] HTTP 状态码: \(httpResponse.statusCode)")

            if httpResponse.statusCode != 200 {
                let responseString = String(data: data, encoding: .utf8) ?? "无法解析"
                print("❌ [BacklogService] 错误响应: \(responseString)")
                if let errorResponse = try? JSONDecoder().decode(BacklogAPIError.self, from: data) {
                    throw BacklogError.apiError(errorResponse.errors.first?.message ?? "未知错误")
                }
                throw BacklogError.apiError("HTTP \(httpResponse.statusCode)")
            }

            let decoder = JSONDecoder()
            let issues = try decoder.decode([BacklogIssue].self, from: data)
            print("✅ [BacklogService] 成功获取 \(issues.count) 个票据")
            return issues
        } catch let error as BacklogError {
            throw error
        } catch let error as DecodingError {
            throw BacklogError.decodingError(error)
        } catch {
            throw BacklogError.networkError(error)
        }
    }

    private func fetchMyself() async throws -> BacklogUser {
        let urlString = "\(baseURL)/users/myself?apiKey=\(apiKey)"
        print("🔍 [BacklogService] fetchMyself URL: \(baseURL)/users/myself?apiKey=***")

        guard let url = URL(string: urlString) else {
            print("❌ [BacklogService] fetchMyself URL 无效")
            throw BacklogError.invalidURL
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [BacklogService] fetchMyself 响应无效")
                throw BacklogError.invalidResponse
            }

            print("📡 [BacklogService] fetchMyself HTTP 状态码: \(httpResponse.statusCode)")

            if httpResponse.statusCode != 200 {
                let responseString = String(data: data, encoding: .utf8) ?? "无法解析"
                print("❌ [BacklogService] fetchMyself 错误响应: \(responseString)")
                if let errorResponse = try? JSONDecoder().decode(BacklogAPIError.self, from: data) {
                    throw BacklogError.apiError(errorResponse.errors.first?.message ?? "未知错误")
                }
                throw BacklogError.apiError("HTTP \(httpResponse.statusCode)")
            }

            let decoder = JSONDecoder()
            let user = try decoder.decode(BacklogUser.self, from: data)
            return user
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
