import Foundation
import SwiftUI
import AppKit

// MARK: - Navigation State

enum NavigationDestination: Hashable {
    case todos
    case timeEntry
}

@MainActor
class AppViewModel: ObservableObject {
    // Shared instance for Settings scene
    static let shared = AppViewModel()

    // Navigation
    @Published var selectedDestination: NavigationDestination = .todos
    @Published var backlogURL: String {
        didSet { UserDefaults.standard.set(backlogURL, forKey: "backlogURL") }
    }
    @Published var backlogAPIKey: String {
        didSet { KeychainHelper.backlogAPIKey = backlogAPIKey }
    }
    @Published var openAIAPIKey: String {
        didSet { KeychainHelper.openAIAPIKey = openAIAPIKey }
    }
    @Published var openAIBaseURL: String {
        didSet { UserDefaults.standard.set(openAIBaseURL, forKey: "openAIBaseURL") }
    }
    @Published var selectedModel: String {
        didSet { UserDefaults.standard.set(selectedModel, forKey: "selectedModel") }
    }
    
    // Calendar settings
    @Published var calendarEnabled: Bool {
        didSet { UserDefaults.standard.set(calendarEnabled, forKey: "calendarEnabled") }
    }
    @Published var selectedCalendarIds: [String] {
        didSet {
            UserDefaults.standard.set(selectedCalendarIds, forKey: "selectedCalendarIds")
        }
    }
    @Published var calendarDaysAhead: Int {
        didSet { UserDefaults.standard.set(calendarDaysAhead, forKey: "calendarDaysAhead") }
    }
    @Published var calendarAccessGranted: Bool = false

    // Redmine settings
    @Published var redmineURL: String {
        didSet { UserDefaults.standard.set(redmineURL, forKey: "redmineURL") }
    }
    @Published var redmineAPIKey: String {
        didSet { KeychainHelper.redmineAPIKey = redmineAPIKey }
    }

    // Email settings
    @Published var emailEnabled: Bool {
        didSet { UserDefaults.standard.set(emailEnabled, forKey: "emailEnabled") }
    }
    @Published var emailUserName: String {
        didSet { UserDefaults.standard.set(emailUserName, forKey: "emailUserName") }
    }
    @Published var senderEmail: String {
        didSet { UserDefaults.standard.set(senderEmail, forKey: "senderEmail") }
    }
    @Published var emailPassword: String {
        didSet { KeychainHelper.emailPassword = emailPassword }
    }
    @Published var recipientEmails: String {
        didSet { UserDefaults.standard.set(recipientEmails, forKey: "recipientEmails") }
    }
    @Published var smtpHost: String {
        didSet { UserDefaults.standard.set(smtpHost, forKey: "smtpHost") }
    }
    @Published var smtpPort: String {
        didSet { UserDefaults.standard.set(smtpPort, forKey: "smtpPort") }
    }
    @Published var emailUseSSL: Bool {
        didSet { UserDefaults.standard.set(emailUseSSL, forKey: "emailUseSSL") }
    }

    // Email state
    @Published var isSendingEmail = false
    @Published var lastEmailResult: EmailSendResult?

    // Redmine state
    @Published var pendingTimeEntries: [PendingTimeEntry] = []
    @Published var redmineUser: RedmineUser?

    // Time entry generation state
    @Published var isGeneratingTimeEntries = false
    @Published var generationProgress: String = ""

    @Published var todoItems: [TodoItem] = [] {
        didSet { saveTodoItems() }
    }

    @Published var isGeneratingTodos = false
    @Published var errorMessage: String?
    @Published var showingSettings = false
    @Published var showingError = false

    static let availableModels = [
        "deepseek-chat",
        "deepseek-reasoner"
    ]

    var isConfigured: Bool {
        !backlogURL.isEmpty && !backlogAPIKey.isEmpty && !openAIAPIKey.isEmpty
    }

    var isRedmineConfigured: Bool {
        !redmineURL.isEmpty && !redmineAPIKey.isEmpty
    }

    var isEmailConfigured: Bool {
        emailEnabled &&
        !emailUserName.isEmpty &&
        !senderEmail.isEmpty &&
        !emailPassword.isEmpty &&
        !recipientEmails.isEmpty
    }

    init() {
        self.backlogURL = UserDefaults.standard.string(forKey: "backlogURL") ?? ""
        self.backlogAPIKey = KeychainHelper.backlogAPIKey ?? ""
        self.openAIAPIKey = KeychainHelper.openAIAPIKey ?? ""
        self.openAIBaseURL = UserDefaults.standard.string(forKey: "openAIBaseURL") ?? "https://api.deepseek.com"
        self.selectedModel = UserDefaults.standard.string(forKey: "selectedModel") ?? "deepseek-chat"
        self.calendarEnabled = UserDefaults.standard.bool(forKey: "calendarEnabled")
        self.selectedCalendarIds = UserDefaults.standard.stringArray(forKey: "selectedCalendarIds") ?? []
        self.calendarDaysAhead = UserDefaults.standard.integer(forKey: "calendarDaysAhead") != 0 ? UserDefaults.standard.integer(forKey: "calendarDaysAhead") : 1
        self.redmineURL = UserDefaults.standard.string(forKey: "redmineURL") ?? "https://fenrir-inc.cn/redmine"
        self.redmineAPIKey = KeychainHelper.redmineAPIKey ?? ""

        // Email settings
        self.emailEnabled = UserDefaults.standard.bool(forKey: "emailEnabled")
        self.emailUserName = UserDefaults.standard.string(forKey: "emailUserName") ?? ""
        self.senderEmail = UserDefaults.standard.string(forKey: "senderEmail") ?? ""
        self.emailPassword = KeychainHelper.emailPassword ?? ""
        self.recipientEmails = UserDefaults.standard.string(forKey: "recipientEmails") ?? ""
        self.smtpHost = UserDefaults.standard.string(forKey: "smtpHost") ?? "smtp.exmail.qq.com"
        self.smtpPort = UserDefaults.standard.string(forKey: "smtpPort") ?? "465"
        self.emailUseSSL = UserDefaults.standard.object(forKey: "emailUseSSL") as? Bool ?? true

        self.todoItems = Self.loadTodoItems()

        // Check calendar access status
        Task {
            await checkCalendarAccessStatus()
        }
    }

    // MARK: - Todo Persistence

    private static let todoItemsKey = "todoItems"

    private static func loadTodoItems() -> [TodoItem] {
        guard let data = UserDefaults.standard.data(forKey: todoItemsKey) else {
            return []
        }
        do {
            return try JSONDecoder().decode([TodoItem].self, from: data)
        } catch {
            print("❌ [AppViewModel] Failed to load todo items: \(error)")
            return []
        }
    }

    private func saveTodoItems() {
        do {
            let data = try JSONEncoder().encode(todoItems)
            UserDefaults.standard.set(data, forKey: Self.todoItemsKey)
        } catch {
            print("❌ [AppViewModel] Failed to save todo items: \(error)")
        }
    }

    private func mergeTodoItems(
        existing: [TodoItem],
        newBacklogItems: [TodoItem],
        newCalendarItems: [TodoItem]
    ) -> [TodoItem] {
        var result = existing.filter { $0.source == .custom }

        var existingBacklogMap: [String: TodoItem] = [:]
        for item in existing where item.source == .backlog {
            if let key = item.issueKey {
                existingBacklogMap[key] = item
            }
        }

        for newItem in newBacklogItems {
            guard let issueKey = newItem.issueKey else { continue }

            if let existingItem = existingBacklogMap[issueKey] {
                var updatedItem = newItem
                updatedItem.isCompleted = existingItem.isCompleted
                result.append(updatedItem)
                existingBacklogMap.removeValue(forKey: issueKey)
            } else {
                result.append(newItem)
            }
        }

        for (_, item) in existingBacklogMap where item.isCompleted {
            result.append(item)
        }

        var existingCalendarMap: [String: TodoItem] = [:]
        for item in existing where item.source == .calendar {
            if let eventId = item.eventId {
                existingCalendarMap[eventId] = item
            }
        }

        for newItem in newCalendarItems {
            guard let eventId = newItem.eventId else { continue }

            if let existingItem = existingCalendarMap[eventId] {
                var updatedItem = newItem
                updatedItem.isCompleted = existingItem.isCompleted
                result.append(updatedItem)
                existingCalendarMap.removeValue(forKey: eventId)
            } else {
                result.append(newItem)
            }
        }

        for (_, item) in existingCalendarMap where item.isCompleted {
            result.append(item)
        }

        return result
    }

    func fetchAndGenerateTodos() async {
        print("🚀 [AppViewModel] fetchAndGenerateTodos started")

        guard isConfigured else {
            print("❌ [AppViewModel] Configuration incomplete, aborting")
            showError("请先配置 API 信息")
            return
        }

        isGeneratingTodos = true
        errorMessage = nil

        do {
            var backlogTodos: [TodoItem] = []
            var calendarTodos: [TodoItem] = []

            print("📋 [AppViewModel] Fetching Backlog issues...")
            let backlogService = BacklogService(backlogURL: backlogURL, apiKey: backlogAPIKey)
            let issues = try await backlogService.fetchMyIssues()
            print("✅ [AppViewModel] Fetched \(issues.count) issues")

            var calendarEvents: [CalendarEvent] = []
            if calendarEnabled && calendarAccessGranted {
                print("📅 [AppViewModel] Fetching calendar events...")
                let calendarService = CalendarService()
                do {
                    calendarEvents = try await calendarService.fetchEvents(
                        calendarIds: selectedCalendarIds.isEmpty ? nil : selectedCalendarIds,
                        daysAhead: calendarDaysAhead
                    )
                    print("✅ [AppViewModel] Fetched \(calendarEvents.count) calendar events")

                    calendarTodos = calendarEvents.map { event in
                        TodoItem.calendar(
                            title: event.title,
                            eventId: event.id,
                            startTime: event.startDate,
                            endTime: event.endDate,
                            location: event.location
                        )
                    }
                } catch {
                    print("⚠️ [AppViewModel] Failed to fetch calendar events: \(error.localizedDescription)")
                }
            }

            if issues.isEmpty && calendarEvents.isEmpty {
                showError("暂无分配给您的票据或日历事件")
                isGeneratingTodos = false
                return
            }

            if !issues.isEmpty {
                print("🤖 [AppViewModel] Generating todo list...")
                let aiService = AIService(
                    apiKey: openAIAPIKey,
                    baseURL: openAIBaseURL,
                    model: selectedModel,
                    backlogURL: backlogURL
                )
                backlogTodos = try await aiService.generateTodoList(from: issues, calendarEvents: calendarEvents)
            }

            todoItems = mergeTodoItems(
                existing: todoItems,
                newBacklogItems: backlogTodos,
                newCalendarItems: calendarTodos
            )
            print("✅ [AppViewModel] Merged total \(todoItems.count) todo items")

        } catch {
            print("❌ [AppViewModel] Error: \(error.localizedDescription)")
            showError(error.localizedDescription)
        }

        isGeneratingTodos = false
        print("🏁 [AppViewModel] fetchAndGenerateTodos finished")
    }

    func toggleTodoCompletion(_ todo: TodoItem) {
        if let index = todoItems.firstIndex(where: { $0.id == todo.id }) {
            todoItems[index].isCompleted.toggle()
        }
    }

    func deleteTodo(_ todo: TodoItem) {
        todoItems.removeAll { $0.id == todo.id }
    }

    func clearAllTodos() {
        todoItems.removeAll()
    }

    func updateTodoTitle(_ todo: TodoItem, newTitle: String) {
        if let index = todoItems.firstIndex(where: { $0.id == todo.id }) {
            todoItems[index].title = newTitle
        }
    }

    func addTodo(title: String) {
        let newTodo = TodoItem.custom(title: title)
        todoItems.insert(newTodo, at: 0)
    }

    func testBacklogConnection() async -> Bool {
        guard !backlogURL.isEmpty, !backlogAPIKey.isEmpty else {
            return false
        }

        do {
            let service = BacklogService(backlogURL: backlogURL, apiKey: backlogAPIKey)
            return try await service.testConnection()
        } catch {
            return false
        }
    }

    func testOpenAIConnection() async -> Bool {
        guard !openAIAPIKey.isEmpty else {
            return false
        }

        do {
            let service = AIService(apiKey: openAIAPIKey, baseURL: openAIBaseURL, model: selectedModel)
            return try await service.testConnection()
        } catch {
            return false
        }
    }
    
    // MARK: - Calendar Methods

    func requestCalendarAccess() async {
        print("📅 [AppViewModel] Requesting calendar access...")
        let service = CalendarService()
        do {
            let granted = try await service.requestAccess()
            print("📅 [AppViewModel] Calendar access request result: \(granted)")

            await checkCalendarAccessStatus()

            if !calendarAccessGranted {
                print("❌ [AppViewModel] Calendar access not granted")
                showError("日历访问被拒绝。\n\n如果没有看到权限弹窗，请前往：\n系统设置 > 隐私与安全性 > 日历\n手动添加 Glance 的访问权限")
            } else {
                print("✅ [AppViewModel] Calendar access granted")
            }
        } catch let error as CalendarService.CalendarError {
            print("❌ [AppViewModel] Calendar access error: \(error)")
            calendarAccessGranted = false

            if case .accessDenied = error {
                showError("日历访问权限已被拒绝。\n\n请按以下步骤操作：\n1. 点击下方按钮打开系统设置\n2. 前往 隐私与安全性 > 日历\n3. 点击 🔒 解锁并添加 Glance")
            } else {
                showError(error.localizedDescription)
            }
        } catch {
            print("❌ [AppViewModel] Failed to request calendar access: \(error)")
            calendarAccessGranted = false
            showError("请求日历权限失败: \(error.localizedDescription)\n\n请前往系统设置手动授予权限")
        }
    }

    func openSystemPrivacySettings() {
        print("🔧 [AppViewModel] Attempting to open system privacy settings...")

        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
            print("✅ [AppViewModel] Opened system settings")
            return
        }

        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
            NSWorkspace.shared.open(url)
            print("✅ [AppViewModel] Opened system settings (general)")
            return
        }

        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
        print("✅ [AppViewModel] Opened system settings main page")
    }

    func checkCalendarAccessStatus() async {
        let service = CalendarService()
        let status = await service.checkAuthorizationStatus()

        print("📅 [AppViewModel] Checking calendar status: \(status.rawValue)")

        if #available(macOS 14.0, *) {
            calendarAccessGranted = (status == .fullAccess || status == .authorized)
        } else {
            calendarAccessGranted = (status == .authorized)
        }

        print("📅 [AppViewModel] calendarAccessGranted = \(calendarAccessGranted)")
    }

    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }

    func clearError() {
        errorMessage = nil
        showingError = false
    }

    // MARK: - Redmine Methods

    func testRedmineConnection() async -> Bool {
        guard isRedmineConfigured else {
            return false
        }

        do {
            let service = RedmineService(baseURL: redmineURL, apiKey: redmineAPIKey)
            let user = try await service.testConnection()
            
            // Save user info
            await MainActor.run {
                redmineUser = user
                
                // Auto-fill email username if empty
                if emailUserName.isEmpty {
                    emailUserName = user.fullName
                }
            }
            
            return true
        } catch {
            print("❌ [AppViewModel] Redmine connection test failed: \(error)")
            return false
        }
    }

    func fetchRedmineProjects() async throws -> [RedmineProject] {
        guard isRedmineConfigured else {
            throw RedmineService.RedmineError.invalidConfiguration
        }

        let service = RedmineService(baseURL: redmineURL, apiKey: redmineAPIKey)
        return try await service.fetchProjects()
    }

    func fetchRedmineTrackers() async throws -> [RedmineTracker] {
        guard isRedmineConfigured else {
            throw RedmineService.RedmineError.invalidConfiguration
        }

        let service = RedmineService(baseURL: redmineURL, apiKey: redmineAPIKey)
        return try await service.fetchTrackers()
    }

    func fetchRedmineIssues(projectId: Int, trackerId: Int) async throws -> [RedmineIssue] {
        guard isRedmineConfigured else {
            throw RedmineService.RedmineError.invalidConfiguration
        }

        let service = RedmineService(baseURL: redmineURL, apiKey: redmineAPIKey)
        return try await service.fetchIssues(projectId: projectId, trackerId: trackerId)
    }

    func fetchRedmineActivities() async throws -> [RedmineActivity] {
        guard isRedmineConfigured else {
            throw RedmineService.RedmineError.invalidConfiguration
        }

        let service = RedmineService(baseURL: redmineURL, apiKey: redmineAPIKey)
        return try await service.fetchActivities()
    }

    func addPendingTimeEntry(_ entry: PendingTimeEntry) {
        pendingTimeEntries.append(entry)
    }

    func removePendingTimeEntry(id: UUID) {
        pendingTimeEntries.removeAll { $0.id == id }
    }

    func clearPendingTimeEntries() {
        pendingTimeEntries.removeAll()
    }

    func submitAllPendingTimeEntries() async -> (success: Int, failed: Int) {
        guard isRedmineConfigured else {
            return (0, pendingTimeEntries.count)
        }

        let service = RedmineService(baseURL: redmineURL, apiKey: redmineAPIKey)
        var successCount = 0
        var failedEntries: [PendingTimeEntry] = []

        for entry in pendingTimeEntries {
            do {
                try await service.submitTimeEntry(entry.timeEntry)
                successCount += 1
            } catch {
                print("❌ [AppViewModel] Failed to submit time entry: \(error)")
                failedEntries.append(entry)
            }
        }

        pendingTimeEntries = failedEntries
        return (successCount, failedEntries.count)
    }

    // MARK: - AI Time Entry Generation

    func generateTimeEntriesForCompletedTodos() async {
        print("🚀 [AppViewModel] generateTimeEntriesForCompletedTodos started")

        // 1. Get completed todos
        let completedTodos = todoItems.filter { $0.isCompleted }
        guard !completedTodos.isEmpty else {
            showError("没有已完成的待办事项")
            return
        }

        guard isRedmineConfigured else {
            showError("请先配置 Redmine API")
            return
        }

        guard !openAIAPIKey.isEmpty else {
            showError("请先配置 AI API Key")
            return
        }

        isGeneratingTimeEntries = true
        generationProgress = "正在获取项目列表..."

        do {
            let redmineService = RedmineService(baseURL: redmineURL, apiKey: redmineAPIKey)
            let aiService = AIService(apiKey: openAIAPIKey, baseURL: openAIBaseURL, model: selectedModel)

            // 2. Fetch projects, trackers, and activities in parallel
            generationProgress = "正在获取项目、跟踪器和活动类型..."
            async let projectsResult = redmineService.fetchProjects()
            async let trackersResult = redmineService.fetchTrackers()
            async let activitiesResult = redmineService.fetchActivities()
            
            let (projects, trackers, activities) = try await (projectsResult, trackersResult, activitiesResult)
            
            guard !projects.isEmpty else {
                showError("未找到可用的 Redmine 项目，请检查账号权限")
                isGeneratingTimeEntries = false
                return
            }

            guard !trackers.isEmpty else {
                showError("未找到可用的跟踪器，请检查 Redmine 配置")
                isGeneratingTimeEntries = false
                return
            }

            guard !activities.isEmpty else {
                showError("未找到可用的活动类型，请检查 Redmine 配置")
                isGeneratingTimeEntries = false
                return
            }
            print("✅ [AppViewModel] Fetched \(projects.count) projects, \(trackers.count) trackers, \(activities.count) activities")

            // 3. AI matches projects + trackers + activities + hours in one call
            generationProgress = "AI 正在分析任务..."
            let projectMatches = try await aiService.matchProjectsTrackersAndActivities(
                todos: completedTodos,
                projects: projects,
                trackers: trackers,
                activities: activities
            )
            print("✅ [AppViewModel] AI returned \(projectMatches.count) matches (project + tracker + activity)")

            // 4. Group by project for batch processing
            let groupedByProject = Dictionary(grouping: projectMatches) { $0.projectId }
            var generatedCount = 0

            // Get today's date string
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let todayString = dateFormatter.string(from: Date())

            print("🔍 [AppViewModel] Grouped by project: \(groupedByProject.count) groups")
            for (projectId, matches) in groupedByProject {
                print("🔍 [AppViewModel] Processing projectId: \(projectId) with \(matches.count) matches")

                // Cache for issues by trackerId to avoid duplicate API calls
                var issuesByTracker: [Int: [RedmineIssue]] = [:]

                for match in matches {
                    // Tracker is already matched by AI in step 3
                    let trackerId = match.trackerId
                    print("🔍 [AppViewModel] Processing todo: \(match.todoTitle) with trackerId=\(trackerId), trackerName=\(match.trackerName)")

                    // 5. Fetch issues for this project + tracker (use cache if available)
                    let issues: [RedmineIssue]
                    if let cachedIssues = issuesByTracker[trackerId] {
                        issues = cachedIssues
                        print("✅ [AppViewModel] Using cached \(issues.count) issues for tracker \(trackerId)")
                    } else {
                        generationProgress = "正在获取任务列表..."
                        issues = try await redmineService.fetchIssues(projectId: projectId, trackerId: trackerId)
                        issuesByTracker[trackerId] = issues
                        print("✅ [AppViewModel] Fetched \(issues.count) issues for project \(projectId), tracker \(trackerId)")
                    }

                    guard !issues.isEmpty else {
                        print("⚠️ [AppViewModel] No issues found for tracker \(trackerId), skipping: \(match.todoTitle)")
                        continue
                    }

                    // 6. AI matches issue
                    print("🔍 [AppViewModel] Matching issue for todo: \(match.todoTitle)")
                    let issueMatch = try await aiService.matchIssue(
                        todoTitle: match.todoTitle,
                        issues: issues
                    )
                    let issueId = issueMatch.issueId
                    print("🔍 [AppViewModel] Issue match result: issueId=\(issueId), issueSubject=\(issueMatch.issueSubject)")

                    // 7. Create PendingTimeEntry and add to list
                    let matchedIssue = issues.first(where: { $0.id == issueId })
                    let project = projects.first(where: { $0.id == projectId })
                    let activity = activities.first(where: { $0.id == match.activityId })

                    print("🔍 [AppViewModel] Condition check:")
                    print("   - matchedIssue: \(matchedIssue != nil ? "found (\(matchedIssue!.subject))" : "nil (issueId=\(issueId))")")
                    print("   - project: \(project != nil ? "found (\(project!.name))" : "nil")")
                    print("   - activity: \(activity != nil ? "found (\(activity!.name))" : "nil (activityId=\(match.activityId))")")

                    if let matchedIssue = matchedIssue,
                       let project = project,
                       let activity = activity {

                        // Find the original todo to get issueKey
                        let originalTodo = completedTodos.first { $0.title == match.todoTitle }

                        // Build comments: include issueKey if from Backlog
                        var finalComments = String(match.comments.prefix(20))
                        if let issueKey = originalTodo?.issueKey {
                            finalComments = "[\(issueKey)] \(finalComments)"
                        }

                        let timeEntry = RedmineTimeEntry(
                            projectId: projectId,
                            issueId: matchedIssue.id,
                            activityId: activity.id,
                            spentOn: todayString,
                            hours: String(match.hours),
                            comments: finalComments
                        )

                        let pendingEntry = PendingTimeEntry(
                            timeEntry: timeEntry,
                            projectName: project.name,
                            issueSubject: matchedIssue.subject,
                            issueId: matchedIssue.id,
                            activityName: activity.name
                        )

                        pendingTimeEntries.append(pendingEntry)
                        generatedCount += 1
                        print("✅ [AppViewModel] Added pending entry for: \(match.todoTitle)")
                    } else {
                        print("⚠️ [AppViewModel] Could not create entry for: \(match.todoTitle) - missing required data")
                    }
                }
            }

            // 8. Navigate to time entry view
            if generatedCount > 0 {
                selectedDestination = .timeEntry
                print("✅ [AppViewModel] Generated \(generatedCount) time entries")
            } else {
                showError("未能生成任何工时记录，请检查 AI 匹配结果")
            }

        } catch {
            print("❌ [AppViewModel] Error: \(error.localizedDescription)")
            showError(error.localizedDescription)
        }

        isGeneratingTimeEntries = false
        generationProgress = ""
        print("🏁 [AppViewModel] generateTimeEntriesForCompletedTodos finished")
    }

    // MARK: - Email Methods

    func testEmailConnection() async -> Bool {
        guard !senderEmail.isEmpty, !emailPassword.isEmpty else {
            return false
        }

        do {
            let service = EmailService(
                smtpHost: smtpHost,
                smtpPort: Int(smtpPort) ?? 465,
                username: senderEmail,
                password: emailPassword,
                useSSL: emailUseSSL
            )
            return try await service.testConnection()
        } catch {
            print("❌ [AppViewModel] Email connection test failed: \(error)")
            return false
        }
    }

    func sendDailyReport(for entries: [PendingTimeEntry]) async -> EmailSendResult {
        guard isEmailConfigured else {
            return .failed(message: "邮件未配置")
        }

        isSendingEmail = true
        defer { isSendingEmail = false }

        // Build report data
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayString = dateFormatter.string(from: Date())

        let reportEntries = entries.map { entry in
            DailyReportData.ReportEntry(
                projectName: entry.projectName,
                issueId: entry.issueId,
                issueSubject: entry.issueSubject,
                hours: Double(entry.timeEntry.hours) ?? 0,
                comments: entry.timeEntry.comments,
                activityName: entry.activityName
            )
        }

        let reportData = DailyReportData(date: todayString, entries: reportEntries, userName: emailUserName)
        let subject = reportData.generateSubject()
        let body = reportData.generateHTMLReport()

        // Parse recipients
        let recipients = recipientEmails
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !recipients.isEmpty else {
            let result = EmailSendResult.failed(message: "收件人列表为空")
            lastEmailResult = result
            return result
        }

        do {
            let service = EmailService(
                smtpHost: smtpHost,
                smtpPort: Int(smtpPort) ?? 465,
                username: senderEmail,
                password: emailPassword,
                useSSL: emailUseSSL
            )

            try await service.sendEmail(
                to: recipients,
                subject: subject,
                body: body,
                isHTML: true
            )

            print("✅ [AppViewModel] Daily report email sent successfully")
            let result = EmailSendResult.succeeded()
            lastEmailResult = result
            return result

        } catch {
            print("❌ [AppViewModel] Failed to send daily report: \(error)")
            let result = EmailSendResult.failed(message: error.localizedDescription, error: error)
            lastEmailResult = result
            return result
        }
    }
}
