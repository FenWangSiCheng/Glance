import Foundation

// MARK: - Redmine Project

struct RedmineProject: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let identifier: String
    let status: Int

    var isArchived: Bool { status == 5 }
}

struct RedmineProjectsResponse: Codable, Sendable {
    let projects: [RedmineProject]
    let totalCount: Int
    let offset: Int
    let limit: Int

    enum CodingKeys: String, CodingKey {
        case projects
        case totalCount = "total_count"
        case offset
        case limit
    }
}

// MARK: - Redmine Issue

struct RedmineIssue: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let subject: String
    let project: Reference
    let tracker: Reference
    let status: Reference

    struct Reference: Codable, Hashable, Sendable {
        let id: Int
        let name: String
    }

    var displayTitle: String {
        "#\(id) \(subject)"
    }
}

struct RedmineIssuesResponse: Codable, Sendable {
    let issues: [RedmineIssue]
    let totalCount: Int
    let offset: Int
    let limit: Int

    enum CodingKeys: String, CodingKey {
        case issues
        case totalCount = "total_count"
        case offset
        case limit
    }
}

// MARK: - Redmine Activity

struct RedmineActivity: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
}

struct RedmineActivitiesResponse: Codable, Sendable {
    let timeEntryActivities: [RedmineActivity]

    enum CodingKeys: String, CodingKey {
        case timeEntryActivities = "time_entry_activities"
    }
}

// MARK: - Redmine Time Entry

struct RedmineTimeEntry: Codable, Sendable {
    let projectId: Int
    let issueId: Int
    let activityId: Int
    let spentOn: String
    let hours: String
    let comments: String

    enum CodingKeys: String, CodingKey {
        case projectId = "project_id"
        case issueId = "issue_id"
        case activityId = "activity_id"
        case spentOn = "spent_on"
        case hours
        case comments
    }
}

struct RedmineTimeEntryRequest: Codable, Sendable {
    let timeEntry: RedmineTimeEntry

    enum CodingKeys: String, CodingKey {
        case timeEntry = "time_entry"
    }
}

// MARK: - Pending Time Entry (Local)

struct PendingTimeEntry: Identifiable, Codable, Sendable {
    let id: UUID
    let timeEntry: RedmineTimeEntry

    // Display info (for UI)
    let projectName: String
    let issueSubject: String
    let issueId: Int
    let activityName: String

    var displaySummary: String {
        "\(timeEntry.spentOn) | \(projectName) | #\(issueId) | \(timeEntry.hours)h"
    }

    init(
        id: UUID = UUID(),
        timeEntry: RedmineTimeEntry,
        projectName: String,
        issueSubject: String,
        issueId: Int,
        activityName: String
    ) {
        self.id = id
        self.timeEntry = timeEntry
        self.projectName = projectName
        self.issueSubject = issueSubject
        self.issueId = issueId
        self.activityName = activityName
    }
}

// MARK: - Redmine User (for connection test)

struct RedmineUser: Codable, Sendable {
    let id: Int
    let login: String
    let firstname: String
    let lastname: String
    let apiKey: String?

    enum CodingKeys: String, CodingKey {
        case id
        case login
        case firstname
        case lastname
        case apiKey = "api_key"
    }

    var fullName: String {
        "\(lastname)\(firstname)"
    }
}

struct RedmineUserResponse: Codable, Sendable {
    let user: RedmineUser
}
