import Foundation

actor AIService {
    enum AIError: LocalizedError {
        case invalidConfiguration
        case invalidURL
        case networkError(Error)
        case invalidResponse
        case apiError(String)
        case decodingError(Error)
        case emptyResponse

        var errorDescription: String? {
            switch self {
            case .invalidConfiguration:
                return "AI 配置无效，请检查 API Key 和 Base URL"
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
            case .emptyResponse:
                return "AI 返回了空响应"
            }
        }
    }

    private let apiKey: String
    private let baseURL: String
    private let model: String
    private let backlogURL: String

    init(
        apiKey: String, baseURL: String = "https://api.deepseek.com", model: String = "deepseek-chat",
        backlogURL: String = ""
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.model = model
        self.backlogURL = backlogURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func sendRequest(prompt: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw AIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7,
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIError.invalidResponse
            }

            if httpResponse.statusCode != 200 {
                if let errorResponse = try? JSONDecoder().decode(DeepSeekErrorResponse.self, from: data) {
                    throw AIError.apiError(errorResponse.error.message)
                }
                throw AIError.apiError("HTTP \(httpResponse.statusCode)")
            }

            let chatResponse = try JSONDecoder().decode(DeepSeekChatResponse.self, from: data)

            guard let content = chatResponse.choices.first?.message.content else {
                throw AIError.emptyResponse
            }

            return content
        } catch let error as AIError {
            throw error
        } catch let error as DecodingError {
            throw AIError.decodingError(error)
        } catch {
            throw AIError.networkError(error)
        }
    }

    func testConnection() async throws -> Bool {
        guard !apiKey.isEmpty else {
            throw AIError.invalidConfiguration
        }

        guard let url = URL(string: "\(baseURL)/models") else {
            throw AIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIError.invalidResponse
            }

            if httpResponse.statusCode == 404 {
                print("⚠️ [AIService] /models endpoint not found, trying chat endpoint")
                return try await testWithChatEndpoint()
            }

            guard httpResponse.statusCode == 200 else {
                logErrorResponse(data, context: "Test connection")
                throw AIError.apiError("HTTP \(httpResponse.statusCode)")
            }
            return true
        } catch let error as AIError {
            throw error
        } catch {
            throw AIError.networkError(error)
        }
    }

    private func testWithChatEndpoint() async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw AIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": "Hi"]
            ],
            "max_tokens": 10,
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                logErrorResponse(data, context: "Chat test")
                throw AIError.apiError("HTTP \(httpResponse.statusCode)")
            }
            return true
        } catch let error as AIError {
            throw error
        } catch {
            throw AIError.networkError(error)
        }
    }

    private func logErrorResponse(_ data: Data, context: String) {
        guard let response = String(data: data, encoding: .utf8) else { return }
        print("❌ [AIService] \(context) error response: \(response)")
    }

    // MARK: - Redmine Matching Methods

    /// Match todos to Redmine projects and infer activity type, comments
    func matchProjectsAndActivities(
        todos: [TodoItem],
        projects: [RedmineProject],
        activities: [RedmineActivity]
    ) async throws -> [ProjectMatchResult] {
        guard !apiKey.isEmpty else {
            throw AIError.invalidConfiguration
        }

        let prompt = buildProjectMatchPrompt(todos: todos, projects: projects, activities: activities)
        let response = try await sendRequest(prompt: prompt)
        return try parseProjectMatchResponse(from: response)
    }

    /// Match todo title to Redmine issue
    func matchIssue(
        todoTitle: String,
        description: String?,
        issues: [RedmineIssue]
    ) async throws -> IssueMatchResult {
        guard !apiKey.isEmpty else {
            throw AIError.invalidConfiguration
        }

        let prompt = buildIssueMatchPrompt(
            todoTitle: todoTitle, description: description, issues: issues)
        let response = try await sendRequest(prompt: prompt)
        return try parseIssueMatchResponse(from: response)
    }

    // MARK: - Prompt Builders

    private func buildProjectMatchPrompt(
        todos: [TodoItem],
        projects: [RedmineProject],
        activities: [RedmineActivity]
    ) -> String {
        let todoList = todos.map { todo -> String in
            var info = "- 标题: \(todo.title)"
            if let issueKey = todo.issueKey {
                info += "\n  票据Key: \(issueKey)"
            }
            if let milestones = todo.milestoneNames, !milestones.isEmpty {
                info += "\n  里程碑: \(milestones.joined(separator: ", "))"
            }
            if let description = todo.description, !description.isEmpty {
                info += "\n  描述: \(description)"
            }
            return info
        }.joined(separator: "\n\n")

        let projectList = projects.map { "ID:\($0.id) 名称:\($0.name)" }.joined(separator: "\n")
        let activityList = activities.map { "ID:\($0.id) 名称:\($0.name)" }.joined(separator: "\n")

        print("📝 [AIService] Building project match prompt:")
        print("   Todos (\(todos.count)):")
        for todo in todos {
            let milestones = todo.milestoneNames?.joined(separator: ", ") ?? "nil"
            print("     - \(todo.title) [key=\(todo.issueKey ?? "nil"), milestones=\(milestones)]")
        }
        print("   Projects (\(projects.count)):")
        for project in projects {
            print("     - ID:\(project.id) \(project.name)")
        }
        print("   Activities (\(activities.count)):")
        for activity in activities {
            print("     - ID:\(activity.id) \(activity.name)")
        }

        return """
            你是工时记录助手。分析已完成的任务，匹配 Redmine 项目并生成工时记录。

            ## 已完成的任务
            \(todoList)

            ## 可用的 Redmine 项目（必须从这些项目中选择）
            \(projectList)

            ## 可用的活动类型（必须从这些活动中选择）
            \(activityList)

            ## 匹配规则
            1. **项目匹配优先级**（按以下顺序匹配）：
               a) 如果任务有「票据Key」（如 VISSEL-776），提取前缀（VISSEL）
               b) 在**上面的项目列表**中查找名称包含该前缀的项目
               c) 如果有多个候选，根据「里程碑」关键词筛选：
                  - 里程碑包含「保守」→ 优先选择项目名称包含「保守」的项目
                  - 里程碑包含「開幕」「新規」→ 优先选择项目名称包含「開幕」「案件」的项目
                  - 里程碑包含年份（如「26年」）仅作时间标记，不作为主要匹配依据
               d) 示例：票据Key=VISSEL-776, 里程碑=26年1月保守 → 匹配「楽天 VisselKobe 保守」

            2. **如果没有找到合适的项目匹配**：
               - 任务是学习、培训、非工作相关 → 使用项目ID:75「非生産」
               - 任务无明确项目信息或无法匹配 → 使用项目ID:75「非生産」

            3. **活动类型匹配**：
               - 根据任务标题和描述推断活动类型（开发/设计/测试/会议/学习等）
               - 学习相关任务 → 使用活动ID:50「内部-学习」
               - 必须从**上面的活动类型列表**中选择有效的ID

            4. **生成工作描述**：
               - 简洁描述（50字以内，例如："完成登录功能开发"）
               - 可参考任务描述中的关键信息

            ## 返回 JSON 格式（只返回 JSON，不要其他文字）
            {
              "entries": [
                {
                  "todoTitle": "任务标题",
                  "projectId": 123,
                  "projectName": "项目名称",
                  "activityId": 8,
                  "activityName": "活动名称",
                  "comments": "完成了XX功能"
                }
              ]
            }

            ## ⚠️ 严格要求
            - **projectId 必须是上面项目列表中的有效ID**，不能使用活动ID，不能编造ID
            - **activityId 必须是上面活动类型列表中的有效ID**，不能使用项目ID，不能编造ID
            - 项目ID和活动ID是两个不同的列表，不要混淆
            - 如果无法找到合适的项目匹配，默认使用项目ID:75「非生産」+ 活动ID:50「内部-学习」
            """
    }

    private func buildIssueMatchPrompt(
        todoTitle: String,
        description: String?,
        issues: [RedmineIssue]
    ) -> String {
        let issueList = issues.map { "ID:\($0.id) 标题:\($0.subject)" }.joined(separator: "\n")

        var taskInfo = "任务标题: \(todoTitle)"
        if let description, !description.isEmpty {
            taskInfo += "\n任务描述: \(description)"
        }

        return """
            将任务匹配到最相关的 Redmine Issue。

            \(taskInfo)

            可用的 Issues:
            \(issueList)

            返回 JSON（只返回 JSON，不要其他文字）:
            { "issueId": 12345, "issueSubject": "开发" }

            注意：
            - 根据标题和描述的相似度匹配
            - 综合分析标题和描述内容，找到最相关的 Issue
            - 必须从上面的 Issues 列表中选择一个有效的 ID 和标题，不能为空
            """
    }

    // MARK: - Response Parsers

    private func parseProjectMatchResponse(from response: String) throws -> [ProjectMatchResult] {
        print("🔍 [AIService] Raw AI response for project match:")
        print(response)
        print("--- End of raw response ---")

        let jsonString = cleanedJSON(from: response)

        print("🔍 [AIService] Cleaned JSON string:")
        print(jsonString)
        print("--- End of cleaned JSON ---")

        guard let data = jsonString.data(using: .utf8) else {
            print("❌ [AIService] Failed to convert string to data")
            throw AIError.decodingError(
                NSError(
                    domain: "AIService", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to parse response data"]))
        }

        do {
            let parsed = try JSONDecoder().decode(ProjectMatchResponse.self, from: data)
            print("✅ [AIService] Parsed \(parsed.entries.count) project match entries:")
            for entry in parsed.entries {
                print("   - Todo: \(entry.todoTitle)")
                print("     ProjectId: \(entry.projectId), ProjectName: \(entry.projectName)")
                print("     ActivityId: \(entry.activityId), ActivityName: \(entry.activityName)")
                print("     Comments: \(entry.comments)")
            }
            return parsed.entries
        } catch {
            print("❌ [AIService] JSON decode error: \(error)")
            throw AIError.decodingError(error)
        }
    }

    private func parseIssueMatchResponse(from response: String) throws -> IssueMatchResult {
        let jsonString = cleanedJSON(from: response)

        guard let data = jsonString.data(using: .utf8) else {
            throw AIError.decodingError(
                NSError(
                    domain: "AIService", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to parse response data"]))
        }

        do {
            return try JSONDecoder().decode(IssueMatchResult.self, from: data)
        } catch {
            throw AIError.decodingError(error)
        }
    }

    private func cleanedJSON(from response: String) -> String {
        var json = response.trimmingCharacters(in: .whitespacesAndNewlines)

        if json.hasPrefix("```json") {
            json.removeFirst(7)
        } else if json.hasPrefix("```") {
            json.removeFirst(3)
        }
        if json.hasSuffix("```") {
            json.removeLast(3)
        }

        return json.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct DeepSeekChatResponse: Codable {
    let choices: [Choice]

    struct Choice: Codable {
        let message: Message
    }

    struct Message: Codable {
        let content: String
    }
}

private struct DeepSeekErrorResponse: Codable {
    let error: DeepSeekError

    struct DeepSeekError: Codable {
        let message: String
    }
}

// MARK: - Redmine Matching Response Models

struct ProjectMatchResult: Codable, Sendable {
    let todoTitle: String
    let projectId: Int
    let projectName: String
    let activityId: Int
    let activityName: String
    let comments: String
}

struct ProjectMatchResponse: Codable, Sendable {
    let entries: [ProjectMatchResult]
}

struct IssueMatchResult: Codable, Sendable {
    let issueId: Int
    let issueSubject: String
}
