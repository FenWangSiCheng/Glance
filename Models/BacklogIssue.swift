import Foundation

struct BacklogIssue: Identifiable, Codable, Hashable, Sendable {
    let id: Int
    let issueKey: String
    let summary: String
    let description: String?
    let priority: Priority?
    let status: Status?
    let startDate: String?
    let dueDate: String?
    let milestone: [Milestone]

    struct Priority: Codable, Hashable, Sendable {
        let id: Int
        let name: String
    }

    struct Status: Codable, Hashable, Sendable {
        let id: Int
        let name: String
    }

    struct Milestone: Codable, Hashable, Sendable {
        let id: Int
        let name: String
    }

    var milestoneNames: [String] {
        milestone.map { $0.name }
    }

    var priorityDisplayName: String {
        priority?.name ?? "未设置"
    }

    var formattedDueDate: String {
        guard let dueDate = dueDate else { return "无截止日期" }
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"

        guard let date = inputFormatter.date(from: dueDate) else { return dueDate }

        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "MM-dd"
        return outputFormatter.string(from: date)
    }
}
