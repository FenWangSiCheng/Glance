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
                return "DeepSeek 配置无效，请检查 API Key"
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

    init(apiKey: String, baseURL: String = "https://api.deepseek.com", model: String = "deepseek-chat", backlogURL: String = "") {
        self.apiKey = apiKey
        self.baseURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.model = model
        self.backlogURL = backlogURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func sendRequest(prompt: String) async throws -> String {
        let urlString = "\(baseURL)/chat/completions"

        guard let url = URL(string: urlString) else {
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
            "temperature": 0.7
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

        let urlString = "\(baseURL)/models"

        guard let url = URL(string: urlString) else {
            throw AIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIError.invalidResponse
            }

            if httpResponse.statusCode == 200 {
                return true
            } else {
                throw AIError.apiError("HTTP \(httpResponse.statusCode)")
            }
        } catch let error as AIError {
            throw error
        } catch {
            throw AIError.networkError(error)
        }
    }

    // MARK: - Redmine Matching Methods

    /// Match todos to Redmine projects, trackers, and infer activity type, hours, comments
    func matchProjectsTrackersAndActivities(
        todos: [TodoItem],
        projects: [RedmineProject],
        trackers: [RedmineTracker],
        activities: [RedmineActivity]
    ) async throws -> [ProjectMatchResult] {
        guard !apiKey.isEmpty else {
            throw AIError.invalidConfiguration
        }

        let prompt = buildProjectMatchPrompt(todos: todos, projects: projects, trackers: trackers, activities: activities)
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

        let prompt = buildIssueMatchPrompt(todoTitle: todoTitle, description: description, issues: issues)
        let response = try await sendRequest(prompt: prompt)
        return try parseIssueMatchResponse(from: response)
    }

    // MARK: - Prompt Builders

    private func buildProjectMatchPrompt(
        todos: [TodoItem],
        projects: [RedmineProject],
        trackers: [RedmineTracker],
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
        let trackerList = trackers.map { "ID:\($0.id) 名称:\($0.name)" }.joined(separator: "\n")
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
        print("   Trackers (\(trackers.count)):")
        for tracker in trackers {
            print("     - ID:\(tracker.id) \(tracker.name)")
        }
        print("   Activities (\(activities.count)):")
        for activity in activities {
            print("     - ID:\(activity.id) \(activity.name)")
        }

        return """
        你是工时记录助手。分析已完成的任务，匹配 Redmine 项目、跟踪器并生成工时记录。

        ## 已完成的任务
        \(todoList)

        ## 可用的 Redmine 项目
        \(projectList)

        ## 可用的跟踪器类型
        \(trackerList)

        ## 可用的活动类型
        \(activityList)

        ## 要求
        1. 根据任务信息匹配最相关的项目，按以下优先级匹配：
           a) 首先提取「票据Key」的前缀（如 VISSEL-776 → VISSEL）
           b) 找到项目名称包含该前缀的候选项目
           c) 如果有多个候选，根据「里程碑」名称中的关键词进一步筛选：
              - 里程碑包含「保守」→ 优先选择项目名称包含「保守」的项目
              - 里程碑包含「開幕」「新規」→ 优先选择项目名称包含「開幕」「案件」的项目
              - 里程碑包含年份如「26年」只是时间标记，不作为主要匹配依据
           d) 示例：票据Key=VISSEL-776, 里程碑=26年1月保守 → 应匹配「楽天 VisselKobe 保守」而非「26年開幕案件」
        2. 根据任务标题和描述匹配跟踪器类型（综合分析标题和描述内容）：
           - 标题或描述包含「バグ」「bug」「修正」「修复」「エラー」「不具合」等关键词 → 选择 Bug 相关的跟踪器
           - 标题或描述包含「開発」「开发」「実装」「实现」「新機能」「新功能」「追加」等关键词 → 选择 功能/Feature/開発 相关的跟踪器
           - 标题或描述包含「タスク」「任务」「作業」「対応」「調査」「確認」等关键词 → 选择 任务/Task 相关的跟踪器
           - 标题或描述包含「サポート」「支持」「問い合わせ」「咨询」「質問」等关键词 → 选择 支持/Support 相关的跟踪器
           - 如果标题和描述关键词不明确，默认选择「開発」或「タスク」类跟踪器
        3. 根据任务标题和描述推断活动类型（开发/设计/测试/会议等），从可用的活动类型中选择
        4. 生成简洁的工作描述（20字以内，例如："完成登录功能开发"），可参考任务描述中的关键信息

        ## 返回 JSON 格式（只返回 JSON，不要其他文字）
        {
          "entries": [
            {
              "todoTitle": "任务标题",
              "projectId": 123,
              "projectName": "项目名称",
              "trackerId": 1,
              "trackerName": "開発",
              "activityId": 8,
              "activityName": "活动名称",
              "comments": "完成了XX功能"
            }
          ]
        }

        注意：
        - projectId 和 projectName 必须从上面的项目列表中选择，不能为 null
        - trackerId 和 trackerName 必须从上面的跟踪器列表中选择，不能为 null
        - activityId 和 activityName 必须从上面的活动类型列表中选择
        - 不需要返回 hours 字段，实际工时由用户在完成任务时输入
        """
    }

    private func buildIssueMatchPrompt(
        todoTitle: String,
        description: String?,
        issues: [RedmineIssue]
    ) -> String {
        let issueList = issues.map { "ID:\($0.id) 标题:\($0.subject)" }.joined(separator: "\n")

        var taskInfo = "任务标题: \(todoTitle)"
        if let desc = description, !desc.isEmpty {
            taskInfo += "\n任务描述: \(desc)"
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

        var jsonString = response.trimmingCharacters(in: .whitespacesAndNewlines)

        if jsonString.hasPrefix("```json") {
            jsonString = String(jsonString.dropFirst(7))
        } else if jsonString.hasPrefix("```") {
            jsonString = String(jsonString.dropFirst(3))
        }
        if jsonString.hasSuffix("```") {
            jsonString = String(jsonString.dropLast(3))
        }
        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)

        print("🔍 [AIService] Cleaned JSON string:")
        print(jsonString)
        print("--- End of cleaned JSON ---")

        guard let data = jsonString.data(using: .utf8) else {
            print("❌ [AIService] Failed to convert string to data")
            throw AIError.decodingError(NSError(domain: "AIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response data"]))
        }

        do {
            let parsed = try JSONDecoder().decode(ProjectMatchResponse.self, from: data)
            print("✅ [AIService] Parsed \(parsed.entries.count) project match entries:")
            for entry in parsed.entries {
                print("   - Todo: \(entry.todoTitle)")
                print("     ProjectId: \(entry.projectId), ProjectName: \(entry.projectName)")
                print("     TrackerId: \(entry.trackerId), TrackerName: \(entry.trackerName)")
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
        var jsonString = response.trimmingCharacters(in: .whitespacesAndNewlines)

        if jsonString.hasPrefix("```json") {
            jsonString = String(jsonString.dropFirst(7))
        } else if jsonString.hasPrefix("```") {
            jsonString = String(jsonString.dropFirst(3))
        }
        if jsonString.hasSuffix("```") {
            jsonString = String(jsonString.dropLast(3))
        }
        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = jsonString.data(using: .utf8) else {
            throw AIError.decodingError(NSError(domain: "AIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response data"]))
        }

        do {
            return try JSONDecoder().decode(IssueMatchResult.self, from: data)
        } catch {
            throw AIError.decodingError(error)
        }
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

struct ProjectMatchResult: Codable {
    let todoTitle: String
    let projectId: Int
    let projectName: String
    let trackerId: Int
    let trackerName: String
    let activityId: Int
    let activityName: String
    let comments: String
}

struct ProjectMatchResponse: Codable {
    let entries: [ProjectMatchResult]
}

struct IssueMatchResult: Codable {
    let issueId: Int
    let issueSubject: String
}
