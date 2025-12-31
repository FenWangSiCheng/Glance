import Foundation

enum TodoSource: String, Codable, Hashable {
    case backlog
    case custom
    case calendar
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
    let eventId: String?
    let eventStartTime: Date?
    let eventEndTime: Date?
    let eventLocation: String?

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

    static func custom(title: String) -> TodoItem {
        TodoItem(title: title, source: .custom)
    }
    
    static func calendar(
        title: String,
        eventId: String,
        startTime: Date,
        endTime: Date,
        location: String? = nil
    ) -> TodoItem {
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
