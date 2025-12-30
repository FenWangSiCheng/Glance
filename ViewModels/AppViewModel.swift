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
        self.calendarDaysAhead = UserDefaults.standard.integer(forKey: "calendarDaysAhead") != 0 ? UserDefaults.standard.integer(forKey: "calendarDaysAhead") : 7
        self.todoItems = Self.loadTodoItems()
        
        // Check calendar access status
        Task {
            await checkCalendarAccessStatus()
        }
    }

    // MARK: - 待办事项持久化

    private static let todoItemsKey = "todoItems"

    private static func loadTodoItems() -> [TodoItem] {
        guard let data = UserDefaults.standard.data(forKey: todoItemsKey) else {
            return []
        }
        do {
            return try JSONDecoder().decode([TodoItem].self, from: data)
        } catch {
            print("❌ [AppViewModel] 加载待办事项失败: \(error)")
            return []
        }
    }

    private func saveTodoItems() {
        do {
            let data = try JSONEncoder().encode(todoItems)
            UserDefaults.standard.set(data, forKey: Self.todoItemsKey)
        } catch {
            print("❌ [AppViewModel] 保存待办事项失败: \(error)")
        }
    }

    /// 合并待办事项
    /// - 保留所有自定义待办
    /// - Backlog 待办根据 issueKey 匹配，保留已完成状态
    /// - Calendar 待办根据 eventId 匹配，保留已完成状态
    /// - 新的 Backlog 和 Calendar 待办添加到列表
    private func mergeTodoItems(
        existing: [TodoItem],
        newBacklogItems: [TodoItem],
        newCalendarItems: [TodoItem]
    ) -> [TodoItem] {
        // 1. 保留所有自定义待办
        var result = existing.filter { $0.source == .custom }

        // 2. 建立现有 Backlog 待办的索引 (issueKey -> TodoItem)
        var existingBacklogMap: [String: TodoItem] = [:]
        for item in existing where item.source == .backlog {
            if let key = item.issueKey {
                existingBacklogMap[key] = item
            }
        }

        // 3. 处理新生成的 Backlog 待办
        for newItem in newBacklogItems {
            guard let issueKey = newItem.issueKey else { continue }

            if let existingItem = existingBacklogMap[issueKey] {
                // 已存在：保留完成状态，更新标题
                var updatedItem = newItem
                updatedItem.isCompleted = existingItem.isCompleted
                result.append(updatedItem)
                existingBacklogMap.removeValue(forKey: issueKey)
            } else {
                // 新增的待办
                result.append(newItem)
            }
        }

        // 4. 保留那些在 Backlog 中已不存在但用户标记为完成的待办（可选）
        for (_, item) in existingBacklogMap where item.isCompleted {
            result.append(item)
        }
        
        // 5. 建立现有 Calendar 待办的索引 (eventId -> TodoItem)
        var existingCalendarMap: [String: TodoItem] = [:]
        for item in existing where item.source == .calendar {
            if let eventId = item.eventId {
                existingCalendarMap[eventId] = item
            }
        }
        
        // 6. 处理新的 Calendar 待办
        for newItem in newCalendarItems {
            guard let eventId = newItem.eventId else { continue }
            
            if let existingItem = existingCalendarMap[eventId] {
                // 已存在：保留完成状态，更新标题
                var updatedItem = newItem
                updatedItem.isCompleted = existingItem.isCompleted
                result.append(updatedItem)
                existingCalendarMap.removeValue(forKey: eventId)
            } else {
                // 新增的待办
                result.append(newItem)
            }
        }
        
        // 7. 保留那些在 Calendar 中已不存在但用户标记为完成的待办
        for (_, item) in existingCalendarMap where item.isCompleted {
            result.append(item)
        }

        return result
    }

    /// 一键获取票据并生成待办清单
    func fetchAndGenerateTodos() async {
        print("🚀 [AppViewModel] fetchAndGenerateTodos 开始")

        guard isConfigured else {
            print("❌ [AppViewModel] 配置不完整，终止")
            showError("请先配置 API 信息")
            return
        }

        isGeneratingTodos = true
        errorMessage = nil

        do {
            var backlogTodos: [TodoItem] = []
            var calendarTodos: [TodoItem] = []
            
            // 1. 获取 Backlog 票据
            print("📋 [AppViewModel] 正在获取 Backlog 票据...")
            let backlogService = BacklogService(backlogURL: backlogURL, apiKey: backlogAPIKey)
            let issues = try await backlogService.fetchMyIssues()
            print("✅ [AppViewModel] 获取到 \(issues.count) 个票据")
            
            // 2. 获取日历事件（如果启用）
            var calendarEvents: [CalendarEvent] = []
            if calendarEnabled && calendarAccessGranted {
                print("📅 [AppViewModel] 正在获取日历事件...")
                let calendarService = CalendarService()
                do {
                    calendarEvents = try await calendarService.fetchEvents(
                        calendarIds: selectedCalendarIds.isEmpty ? nil : selectedCalendarIds,
                        daysAhead: calendarDaysAhead
                    )
                    print("✅ [AppViewModel] 获取到 \(calendarEvents.count) 个日历事件")
                    
                    // 转换日历事件为 TodoItem
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
                    print("⚠️ [AppViewModel] 获取日历事件失败: \(error.localizedDescription)")
                }
            }

            // 3. 如果既没有票据也没有日历事件，提示用户
            if issues.isEmpty && calendarEvents.isEmpty {
                showError("暂无分配给您的票据或日历事件")
                isGeneratingTodos = false
                return
            }

            // 4. 生成待办清单（使用 AI 排序）
            if !issues.isEmpty {
                print("🤖 [AppViewModel] 正在生成待办清单...")
                let aiService = AIService(
                    apiKey: openAIAPIKey,
                    baseURL: openAIBaseURL,
                    model: selectedModel,
                    backlogURL: backlogURL
                )
                backlogTodos = try await aiService.generateTodoList(from: issues, calendarEvents: calendarEvents)
            }

            // 5. 合并待办事项（保留自定义待办和已有状态）
            todoItems = mergeTodoItems(
                existing: todoItems,
                newBacklogItems: backlogTodos,
                newCalendarItems: calendarTodos
            )
            print("✅ [AppViewModel] 合并后共 \(todoItems.count) 个待办事项")

        } catch {
            print("❌ [AppViewModel] 错误: \(error.localizedDescription)")
            showError(error.localizedDescription)
        }

        isGeneratingTodos = false
        print("🏁 [AppViewModel] fetchAndGenerateTodos 结束")
    }

    func toggleTodoCompletion(_ todo: TodoItem) {
        if let index = todoItems.firstIndex(where: { $0.id == todo.id }) {
            todoItems[index].isCompleted.toggle()
        }
    }

    func deleteTodo(_ todo: TodoItem) {
        todoItems.removeAll { $0.id == todo.id }
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
    
    /// 请求日历访问权限
    func requestCalendarAccess() async {
        print("📅 [AppViewModel] 开始请求日历访问权限...")
        let service = CalendarService()
        do {
            let granted = try await service.requestAccess()
            print("📅 [AppViewModel] 日历权限请求结果: \(granted)")
            
            // 重新检查状态
            await checkCalendarAccessStatus()
            
            if !calendarAccessGranted {
                print("❌ [AppViewModel] 日历访问未授予")
                showError("日历访问被拒绝。\n\n如果没有看到权限弹窗，请前往：\n系统设置 > 隐私与安全性 > 日历\n手动添加 Glance 的访问权限")
            } else {
                print("✅ [AppViewModel] 日历访问权限已授予")
            }
        } catch let error as CalendarService.CalendarError {
            print("❌ [AppViewModel] 日历权限错误: \(error)")
            calendarAccessGranted = false
            
            // 如果是访问被拒绝，提示用户打开系统设置
            if case .accessDenied = error {
                showError("日历访问权限已被拒绝。\n\n请按以下步骤操作：\n1. 点击下方按钮打开系统设置\n2. 前往 隐私与安全性 > 日历\n3. 点击 🔒 解锁并添加 Glance")
            } else {
                showError(error.localizedDescription)
            }
        } catch {
            print("❌ [AppViewModel] 请求日历权限失败: \(error)")
            calendarAccessGranted = false
            showError("请求日历权限失败: \(error.localizedDescription)\n\n请前往系统设置手动授予权限")
        }
    }
    
    /// 打开系统隐私设置
    func openSystemPrivacySettings() {
        print("🔧 [AppViewModel] 尝试打开系统隐私设置...")
        
        // 方法 1: 尝试打开日历隐私设置（macOS 13+）
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
            print("✅ [AppViewModel] 已打开系统设置")
            return
        }
        
        // 方法 2: 尝试打开通用隐私设置
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
            NSWorkspace.shared.open(url)
            print("✅ [AppViewModel] 已打开系统设置（通用）")
            return
        }
        
        // 方法 3: 打开系统设置主页
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
        print("✅ [AppViewModel] 已打开系统设置主页")
    }
    
    /// 检查日历访问状态
    func checkCalendarAccessStatus() async {
        let service = CalendarService()
        let status = await service.checkAuthorizationStatus()
        
        print("📅 [AppViewModel] 检查日历状态: \(status.rawValue)")
        
        // macOS 14.0+ 引入了 .fullAccess，需要完整访问权限才能读取事件
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
