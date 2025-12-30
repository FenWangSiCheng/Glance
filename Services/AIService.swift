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

    func generateTodoList(from issues: [BacklogIssue], calendarEvents: [CalendarEvent] = []) async throws -> [TodoItem] {
        guard !apiKey.isEmpty else {
            throw AIError.invalidConfiguration
        }

        let prompt = buildPrompt(from: issues, calendarEvents: calendarEvents)
        let response = try await sendRequest(prompt: prompt)
        let todoItems = try parseTodoItems(from: response, issues: issues)

        return todoItems
    }

    private func buildPrompt(from issues: [BacklogIssue], calendarEvents: [CalendarEvent] = []) -> String {
        var issueDescriptions = ""
        for issue in issues {
            issueDescriptions += """

            ---
            票据编号: \(issue.issueKey)
            标题: \(issue.summary)
            描述: \(issue.description ?? "无描述")
            优先级: \(issue.priorityDisplayName)
            开始日期: \(issue.startDate ?? "无开始日期")
            截止日期: \(issue.dueDate ?? "无截止日期")
            """
        }
        
        var calendarInfo = ""
        if !calendarEvents.isEmpty {
            calendarInfo = """
            
            
            以下是今天的日历事件（仅供参考，帮助你更好地安排今天的 Backlog 任务优先级）:
            """
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            
            for event in calendarEvents {
                let startTime = dateFormatter.string(from: event.startDate)
                let endTime = dateFormatter.string(from: event.endDate)
                calendarInfo += """
                
                
                ---
                日历事件: \(event.title)
                时间: \(startTime) - \(endTime)
                \(event.location != nil ? "地点: \(event.location!)" : "")
                """
            }
            
            calendarInfo += """
            
            
            注意：日历事件会自动显示在待办列表中，你只需要排序 Backlog 票据即可。
            在排序时，请考虑今天的会议时间安排，优先处理会议前后有空档的紧急任务。
            """
        }

        return """
        你是一个专业的任务排序助手。请根据以下 Backlog 票据生成今天的待办清单。

        要求:
        1. 每个票据就是一个待办项，不需要拆解
        2. 这是**今天的待办清单**，请根据优先级、截止日期、今天的日历安排综合考虑
        3. 排序规则（按重要性递减）：
           - 今天截止或即将截止的任务优先
           - 优先级高的任务优先
           - 考虑今天的会议时间，合理安排任务顺序
           - 将简单快速的任务安排在会议间隙

        请以 JSON 格式返回，格式如下:
        {
            "tasks": [
                {
                    "issueKey": "票据编号",
                    "title": "票据标题"
                }
            ]
        }

        以下是需要排序的票据:
        \(issueDescriptions)
        \(calendarInfo)

        请直接返回 JSON，不要包含其他文字说明。按照建议的执行顺序排列任务。
        """
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

    private func parseTodoItems(from response: String, issues: [BacklogIssue]) throws -> [TodoItem] {
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
            throw AIError.decodingError(NSError(domain: "AIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法解析响应数据"]))
        }

        let issueMap = Dictionary(uniqueKeysWithValues: issues.map { ($0.issueKey, $0) })

        do {
            let parsed = try JSONDecoder().decode(AITaskResponse.self, from: data)

            return parsed.tasks.compactMap { task -> TodoItem? in
                guard let issue = issueMap[task.issueKey] else { return nil }
                let issueURL = "\(backlogURL)/view/\(task.issueKey)"
                return .backlog(
                    title: task.title,
                    issueKey: task.issueKey,
                    issueURL: issueURL,
                    priority: issue.priority?.name,
                    startDate: issue.startDate,
                    dueDate: issue.dueDate
                )
            }
        } catch {
            throw AIError.decodingError(error)
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

private struct AITaskResponse: Codable {
    let tasks: [AITask]

    struct AITask: Codable {
        let issueKey: String
        let title: String
    }
}
