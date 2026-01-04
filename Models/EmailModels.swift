import Foundation

// MARK: - Email Configuration

struct EmailConfiguration: Codable {
    var senderEmail: String
    var recipientEmails: [String]
    var smtpHost: String
    var smtpPort: Int
    var useSSL: Bool
    var isEnabled: Bool

    static var defaultTencentExmail: EmailConfiguration {
        EmailConfiguration(
            senderEmail: "",
            recipientEmails: [],
            smtpHost: "smtp.exmail.qq.com",
            smtpPort: 465,
            useSSL: true,
            isEnabled: false
        )
    }
}

// MARK: - Daily Report Data

struct DailyReportData {
    let date: String
    let entries: [ReportEntry]
    let userName: String

    struct ReportEntry {
        let projectName: String
        let issueId: Int
        let issueSubject: String
        let hours: Double
        let comments: String
        let activityName: String
    }

    var totalHours: Double {
        entries.reduce(0) { $0 + $1.hours }
    }

    // Group entries by project
    var entriesByProject: [(projectName: String, entries: [ReportEntry], totalHours: Double)] {
        var grouped: [String: [ReportEntry]] = [:]
        for entry in entries {
            grouped[entry.projectName, default: []].append(entry)
        }
        return grouped.map { (projectName: $0.key, entries: $0.value, totalHours: $0.value.reduce(0) { $0 + $1.hours }) }
            .sorted { $0.totalHours > $1.totalHours }
    }

    // Generate HTML daily report
    func generateHTMLReport() -> String {
        var body = """
        各位好，我是\(userName)<br/>
        下面是今日的工作汇报，请查收。<br/><br/>
        ■ 今日成果 <br/>
        """

        for group in entriesByProject {
            body += "<h3>\(group.projectName)</h3>\n"

            // Combine work content for this project
            let contents = group.entries.map { entry -> String in
                if !entry.comments.isEmpty {
                    return entry.comments
                } else {
                    return entry.issueSubject
                }
            }
            let combinedContent = contents.joined(separator: "；")

            let hoursStr = String(format: "%.1f", group.totalHours)
            body += "内容：\(combinedContent)<br/>时间：\(hoursStr)h<br/>\n"
        }

        // Wrap in complete HTML structure for better email client compatibility
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
        
        return html
    }

    // Generate email subject
    func generateSubject() -> String {
        return "[日报] \(userName)"
    }
}

// MARK: - Email Send Result

struct EmailSendResult {
    let success: Bool
    let message: String?
    let error: Error?

    static func succeeded() -> EmailSendResult {
        EmailSendResult(success: true, message: nil, error: nil)
    }

    static func failed(message: String, error: Error? = nil) -> EmailSendResult {
        EmailSendResult(success: false, message: message, error: error)
    }
}
