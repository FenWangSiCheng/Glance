import Foundation

enum TodoSource: String, Codable, Hashable {
    case backlog    // 来自 Backlog 的票
    case custom     // 用户自定义的待办
    case calendar   // 来自系统日历
}

struct TodoItem: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    let source: TodoSource
    let issueKey: String?
    let issueURL: String?
    let priority: String?
    let startDate: String?
    let dueDate: String?
    let eventId: String?       // 日历事件 ID，用于去重
    let eventStartTime: Date?  // 事件开始时间
    let eventEndTime: Date?    // 事件结束时间
    let eventLocation: String? // 事件地点

    init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        source: TodoSource,
        issueKey: String? = nil,
        issueURL: String? = nil,
        priority: String? = nil,
        startDate: String? = nil,
        dueDate: String? = nil,
        eventId: String? = nil,
        eventStartTime: Date? = nil,
        eventEndTime: Date? = nil,
        eventLocation: String? = nil
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.source = source
        self.issueKey = issueKey
        self.issueURL = issueURL
        self.priority = priority
        self.startDate = startDate
        self.dueDate = dueDate
        self.eventId = eventId
        self.eventStartTime = eventStartTime
        self.eventEndTime = eventEndTime
        self.eventLocation = eventLocation
    }

    /// 便捷初始化器 - 创建 Backlog 待办
    static func backlog(
        title: String,
        issueKey: String,
        issueURL: String,
        priority: String? = nil,
        startDate: String? = nil,
        dueDate: String? = nil
    ) -> TodoItem {
        TodoItem(
            title: title,
            source: .backlog,
            issueKey: issueKey,
            issueURL: issueURL,
            priority: priority,
            startDate: startDate,
            dueDate: dueDate
        )
    }

    /// 便捷初始化器 - 创建自定义待办
    static func custom(title: String) -> TodoItem {
        TodoItem(title: title, source: .custom)
    }
    
    /// 便捷初始化器 - 创建日历待办
    static func calendar(
        title: String,
        eventId: String,
        startTime: Date,
        endTime: Date,
        location: String? = nil
    ) -> TodoItem {
        // 只保留标题，不在标题中包含时间和地点
        // 时间和地点信息会在 UI 的第二行显示
        return TodoItem(
            title: title,
            source: .calendar,
            eventId: eventId,
            eventStartTime: startTime,
            eventEndTime: endTime,
            eventLocation: location
        )
    }
}
