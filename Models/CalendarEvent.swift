import Foundation

struct CalendarEvent: Identifiable, Codable, Sendable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let location: String?
    let calendarName: String
}

