import Foundation
import SwiftUI
import AppKit

@MainActor
class AppViewModel: ObservableObject {
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

    init() {
        self.backlogURL = UserDefaults.standard.string(forKey: "backlogURL") ?? ""
        self.backlogAPIKey = KeychainHelper.backlogAPIKey ?? ""
        self.openAIAPIKey = KeychainHelper.openAIAPIKey ?? ""
        self.openAIBaseURL = UserDefaults.standard.string(forKey: "openAIBaseURL") ?? "https://api.deepseek.com"
        self.selectedModel = UserDefaults.standard.string(forKey: "selectedModel") ?? "deepseek-chat"
        self.calendarEnabled = UserDefaults.standard.bool(forKey: "calendarEnabled")
        self.selectedCalendarIds = UserDefaults.standard.stringArray(forKey: "selectedCalendarIds") ?? []
        self.calendarDaysAhead = UserDefaults.standard.integer(forKey: "calendarDaysAhead") != 0 ? UserDefaults.standard.integer(forKey: "calendarDaysAhead") : 1
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
}
