import Foundation

actor RedmineService {
    enum RedmineError: LocalizedError {
        case invalidConfiguration
        case invalidURL
        case networkError(Error)
        case invalidResponse
        case apiError(String)
        case decodingError(Error)

        var errorDescription: String? {
            switch self {
            case .invalidConfiguration:
                return "Redmine 配置无效，请检查 URL 和 API Key"
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

    private let baseURL: String
    private let apiKey: String

    init(baseURL: String, apiKey: String) {
        var url = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if url.hasSuffix("/") {
            url = String(url.dropLast())
        }
        self.baseURL = url
        self.apiKey = apiKey
    }

    // MARK: - Common Request Method

    private func performRequest<T: Decodable>(
        path: String,
        method: String = "GET",
        body: Data? = nil,
        expectedStatusCode: Int = 200
    ) async throws -> T {
        guard !baseURL.isEmpty, !apiKey.isEmpty else {
            throw RedmineError.invalidConfiguration
        }

        let urlString = "\(baseURL)\(path)"
        guard let url = URL(string: urlString) else {
            throw RedmineError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(apiKey, forHTTPHeaderField: "X-Redmine-API-Key")
        
        if let body = body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw RedmineError.invalidResponse
            }

            if httpResponse.statusCode != expectedStatusCode {
                if let responseString = String(data: data, encoding: .utf8) {
                    throw RedmineError.apiError("HTTP \(httpResponse.statusCode): \(responseString)")
                }
                throw RedmineError.apiError("HTTP \(httpResponse.statusCode)")
            }

            let decoded = try JSONDecoder().decode(T.self, from: data)
            return decoded
        } catch let error as RedmineError {
            throw error
        } catch let error as DecodingError {
            throw RedmineError.decodingError(error)
        } catch {
            throw RedmineError.networkError(error)
        }
    }

    // MARK: - Connection Test

    func testConnection() async throws -> RedmineUser {
        let response: RedmineUserResponse = try await performRequest(path: "/users/current.json")
        return response.user
    }

    // MARK: - Fetch Projects (with pagination)

    func fetchProjects() async throws -> [RedmineProject] {
        var allProjects: [RedmineProject] = []
        var offset = 0
        let limit = 100

        while true {
            let response: RedmineProjectsResponse = try await performRequest(
                path: "/projects.json?limit=\(limit)&offset=\(offset)"
            )
            
            let activeProjects = response.projects.filter { !$0.isArchived }
            allProjects.append(contentsOf: activeProjects)

            if offset + limit >= response.totalCount {
                break
            }
            offset += limit
        }

        return allProjects.sorted { $0.name < $1.name }
    }

    // MARK: - Fetch Trackers

    func fetchTrackers() async throws -> [RedmineTracker] {
        let response: RedmineTrackersResponse = try await performRequest(path: "/trackers.json")
        return response.trackers
    }

    // MARK: - Fetch Issues

    func fetchIssues(projectId: Int, trackerId: Int?) async throws -> [RedmineIssue] {
        let path: String
        if let trackerId = trackerId {
            path = "/issues.json?project_id=\(projectId)&tracker_id=\(trackerId)"
        } else {
            path = "/issues.json?project_id=\(projectId)"
        }
        let response: RedmineIssuesResponse = try await performRequest(path: path)
        return response.issues
    }

    // MARK: - Fetch Activities

    func fetchActivities() async throws -> [RedmineActivity] {
        let response: RedmineActivitiesResponse = try await performRequest(
            path: "/enumerations/time_entry_activities.json"
        )
        return response.timeEntryActivities
    }

    // MARK: - Submit Time Entry

    func submitTimeEntry(_ entry: RedmineTimeEntry) async throws {
        let requestBody = RedmineTimeEntryRequest(timeEntry: entry)
        let encoder = JSONEncoder()
        let body = try encoder.encode(requestBody)
        
        // Use a dummy response type since we don't need the response body
        struct EmptyResponse: Codable {}
        let _: EmptyResponse = try await performRequest(
            path: "/time_entries.json",
            method: "POST",
            body: body,
            expectedStatusCode: 201
        )
    }
}
