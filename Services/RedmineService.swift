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

    // MARK: - Connection Test

    func testConnection() async throws -> RedmineUser {
        guard !baseURL.isEmpty, !apiKey.isEmpty else {
            throw RedmineError.invalidConfiguration
        }

        let urlString = "\(baseURL)/users/current.json"
        guard let url = URL(string: urlString) else {
            throw RedmineError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-Redmine-API-Key")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw RedmineError.invalidResponse
            }

            if httpResponse.statusCode != 200 {
                throw RedmineError.apiError("HTTP \(httpResponse.statusCode)")
            }

            let decoded = try JSONDecoder().decode(RedmineUserResponse.self, from: data)
            return decoded.user
        } catch let error as RedmineError {
            throw error
        } catch let error as DecodingError {
            throw RedmineError.decodingError(error)
        } catch {
            throw RedmineError.networkError(error)
        }
    }

    // MARK: - Fetch Projects (with pagination)

    func fetchProjects() async throws -> [RedmineProject] {
        guard !baseURL.isEmpty, !apiKey.isEmpty else {
            throw RedmineError.invalidConfiguration
        }

        var allProjects: [RedmineProject] = []
        var offset = 0
        let limit = 100

        while true {
            let urlString = "\(baseURL)/projects.json?limit=\(limit)&offset=\(offset)"
            guard let url = URL(string: urlString) else {
                throw RedmineError.invalidURL
            }

            var request = URLRequest(url: url)
            request.setValue(apiKey, forHTTPHeaderField: "X-Redmine-API-Key")

            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw RedmineError.invalidResponse
                }

                if httpResponse.statusCode != 200 {
                    throw RedmineError.apiError("HTTP \(httpResponse.statusCode)")
                }

                let decoded = try JSONDecoder().decode(RedmineProjectsResponse.self, from: data)
                let activeProjects = decoded.projects.filter { !$0.isArchived }
                allProjects.append(contentsOf: activeProjects)

                if offset + limit >= decoded.totalCount {
                    break
                }
                offset += limit
            } catch let error as RedmineError {
                throw error
            } catch let error as DecodingError {
                throw RedmineError.decodingError(error)
            } catch {
                throw RedmineError.networkError(error)
            }
        }

        return allProjects.sorted { $0.name < $1.name }
    }

    // MARK: - Fetch Trackers

    func fetchTrackers(projectId: Int) async throws -> [RedmineTracker] {
        guard !baseURL.isEmpty, !apiKey.isEmpty else {
            throw RedmineError.invalidConfiguration
        }

        let urlString = "\(baseURL)/trackers.json?project_id=\(projectId)"
        guard let url = URL(string: urlString) else {
            throw RedmineError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-Redmine-API-Key")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw RedmineError.invalidResponse
            }

            if httpResponse.statusCode != 200 {
                throw RedmineError.apiError("HTTP \(httpResponse.statusCode)")
            }

            let decoded = try JSONDecoder().decode(RedmineTrackersResponse.self, from: data)
            return decoded.trackers
        } catch let error as RedmineError {
            throw error
        } catch let error as DecodingError {
            throw RedmineError.decodingError(error)
        } catch {
            throw RedmineError.networkError(error)
        }
    }

    // MARK: - Fetch Issues

    func fetchIssues(projectId: Int, trackerId: Int) async throws -> [RedmineIssue] {
        guard !baseURL.isEmpty, !apiKey.isEmpty else {
            throw RedmineError.invalidConfiguration
        }

        let urlString = "\(baseURL)/issues.json?project_id=\(projectId)&tracker_id=\(trackerId)"
        guard let url = URL(string: urlString) else {
            throw RedmineError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-Redmine-API-Key")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw RedmineError.invalidResponse
            }

            if httpResponse.statusCode != 200 {
                throw RedmineError.apiError("HTTP \(httpResponse.statusCode)")
            }

            let decoded = try JSONDecoder().decode(RedmineIssuesResponse.self, from: data)
            return decoded.issues
        } catch let error as RedmineError {
            throw error
        } catch let error as DecodingError {
            throw RedmineError.decodingError(error)
        } catch {
            throw RedmineError.networkError(error)
        }
    }

    // MARK: - Fetch Activities

    func fetchActivities() async throws -> [RedmineActivity] {
        guard !baseURL.isEmpty, !apiKey.isEmpty else {
            throw RedmineError.invalidConfiguration
        }

        let urlString = "\(baseURL)/enumerations/time_entry_activities.json"
        guard let url = URL(string: urlString) else {
            throw RedmineError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-Redmine-API-Key")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw RedmineError.invalidResponse
            }

            if httpResponse.statusCode != 200 {
                throw RedmineError.apiError("HTTP \(httpResponse.statusCode)")
            }

            let decoded = try JSONDecoder().decode(RedmineActivitiesResponse.self, from: data)
            return decoded.timeEntryActivities
        } catch let error as RedmineError {
            throw error
        } catch let error as DecodingError {
            throw RedmineError.decodingError(error)
        } catch {
            throw RedmineError.networkError(error)
        }
    }

    // MARK: - Submit Time Entry

    func submitTimeEntry(_ entry: RedmineTimeEntry) async throws {
        guard !baseURL.isEmpty, !apiKey.isEmpty else {
            throw RedmineError.invalidConfiguration
        }

        let urlString = "\(baseURL)/time_entries.json"
        guard let url = URL(string: urlString) else {
            throw RedmineError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "X-Redmine-API-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody = RedmineTimeEntryRequest(timeEntry: entry)
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw RedmineError.invalidResponse
            }

            if httpResponse.statusCode != 201 {
                if let responseString = String(data: data, encoding: .utf8) {
                    throw RedmineError.apiError("HTTP \(httpResponse.statusCode): \(responseString)")
                }
                throw RedmineError.apiError("HTTP \(httpResponse.statusCode)")
            }
        } catch let error as RedmineError {
            throw error
        } catch let error as EncodingError {
            throw RedmineError.decodingError(error)
        } catch {
            throw RedmineError.networkError(error)
        }
    }
}
