import Foundation
import Network

// MARK: - Email Service

actor EmailService {
    // MARK: - Errors

    enum EmailError: LocalizedError {
        case invalidConfiguration
        case connectionFailed(String)
        case authenticationFailed
        case sendFailed(String)
        case tlsError
        case timeout
        case invalidResponse(String)

        var errorDescription: String? {
            switch self {
            case .invalidConfiguration:
                return "邮件配置无效"
            case .connectionFailed(let reason):
                return "连接失败: \(reason)"
            case .authenticationFailed:
                return "SMTP 认证失败，请检查邮箱地址和客户端专用密码"
            case .sendFailed(let reason):
                return "发送失败: \(reason)"
            case .tlsError:
                return "TLS/SSL 连接错误"
            case .timeout:
                return "连接超时"
            case .invalidResponse(let response):
                return "服务器响应异常: \(response)"
            }
        }
    }

    // MARK: - Properties

    private let smtpHost: String
    private let smtpPort: UInt16
    private let username: String
    private let password: String
    private let useSSL: Bool
    private let connectionTimeout: TimeInterval = 30

    // MARK: - Initialization

    init(smtpHost: String, smtpPort: Int, username: String, password: String, useSSL: Bool = true) {
        self.smtpHost = smtpHost
        self.smtpPort = UInt16(smtpPort)
        self.username = username
        self.password = password
        self.useSSL = useSSL
    }

    // MARK: - Public Methods

    func sendEmail(
        to recipients: [String],
        subject: String,
        body: String,
        from senderName: String? = nil,
        isHTML: Bool = false
    ) async throws {
        let connection = try await createConnection()
        defer { connection.cancel() }

        try await performSMTPHandshake(connection: connection)
        try await authenticate(connection: connection)
        try await sendMailCommands(
            connection: connection,
            from: username,
            to: recipients,
            subject: subject,
            body: body,
            senderName: senderName,
            isHTML: isHTML
        )
        try await quit(connection: connection)
    }

    func testConnection() async throws -> Bool {
        let connection = try await createConnection()
        defer { connection.cancel() }

        try await performSMTPHandshake(connection: connection)
        try await authenticate(connection: connection)
        try await quit(connection: connection)

        return true
    }

    // MARK: - Private Methods

    private func createConnection() async throws -> NWConnection {
        let host = NWEndpoint.Host(smtpHost)
        let port = NWEndpoint.Port(rawValue: smtpPort)!

        let parameters: NWParameters
        if useSSL {
            let tlsOptions = NWProtocolTLS.Options()
            parameters = NWParameters(tls: tlsOptions, tcp: .init())
        } else {
            parameters = NWParameters.tcp
        }

        let connection = NWConnection(host: host, port: port, using: parameters)
        let timeout = connectionTimeout

        return try await withCheckedThrowingContinuation { continuation in
            connection.stateUpdateHandler = { @Sendable state in
                switch state {
                case .ready:
                    connection.stateUpdateHandler = nil
                    continuation.resume(returning: connection)
                case .failed(let error):
                    connection.stateUpdateHandler = nil
                    continuation.resume(throwing: EmailError.connectionFailed(error.localizedDescription))
                case .cancelled:
                    connection.stateUpdateHandler = nil
                    continuation.resume(throwing: EmailError.connectionFailed("Connection cancelled"))
                default:
                    break
                }
            }
            connection.start(queue: .global())

            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { @Sendable in
                if case .setup = connection.state {
                    connection.cancel()
                }
            }
        }
    }

    private func performSMTPHandshake(connection: NWConnection) async throws {
        let greeting = try await readResponse(connection: connection)
        guard greeting.hasPrefix("220") else {
            throw EmailError.invalidResponse(greeting)
        }

        try await sendCommand(connection: connection, command: "EHLO \(smtpHost)")
        let ehloResponse = try await readResponse(connection: connection)
        guard ehloResponse.contains("250") else {
            throw EmailError.invalidResponse(ehloResponse)
        }
    }

    private func authenticate(connection: NWConnection) async throws {
        try await sendCommand(connection: connection, command: "AUTH LOGIN")
        let authResponse = try await readResponse(connection: connection)
        guard authResponse.hasPrefix("334") else {
            throw EmailError.authenticationFailed
        }

        let usernameBase64 = Data(username.utf8).base64EncodedString()
        try await sendCommand(connection: connection, command: usernameBase64)
        let usernameResponse = try await readResponse(connection: connection)
        guard usernameResponse.hasPrefix("334") else {
            throw EmailError.authenticationFailed
        }

        let passwordBase64 = Data(password.utf8).base64EncodedString()
        try await sendCommand(connection: connection, command: passwordBase64)
        let passwordResponse = try await readResponse(connection: connection)
        guard passwordResponse.hasPrefix("235") else {
            throw EmailError.authenticationFailed
        }
    }

    private func sendMailCommands(
        connection: NWConnection,
        from sender: String,
        to recipients: [String],
        subject: String,
        body: String,
        senderName: String?,
        isHTML: Bool = false
    ) async throws {
        try await sendCommand(connection: connection, command: "MAIL FROM:<\(sender)>")
        let mailFromResponse = try await readResponse(connection: connection)
        guard mailFromResponse.hasPrefix("250") else {
            throw EmailError.sendFailed("MAIL FROM rejected: \(mailFromResponse)")
        }

        for recipient in recipients {
            try await sendCommand(connection: connection, command: "RCPT TO:<\(recipient)>")
            let rcptResponse = try await readResponse(connection: connection)
            guard rcptResponse.hasPrefix("250") else {
                throw EmailError.sendFailed("RCPT TO rejected for \(recipient): \(rcptResponse)")
            }
        }

        try await sendCommand(connection: connection, command: "DATA")
        let dataResponse = try await readResponse(connection: connection)
        guard dataResponse.hasPrefix("354") else {
            throw EmailError.sendFailed("DATA command rejected: \(dataResponse)")
        }

        let emailContent = buildEmailContent(
            from: sender,
            senderName: senderName,
            to: recipients,
            subject: subject,
            body: body,
            isHTML: isHTML
        )

        try await sendCommand(connection: connection, command: emailContent + "\r\n.")
        let sendResponse = try await readResponse(connection: connection)
        guard sendResponse.hasPrefix("250") else {
            throw EmailError.sendFailed("Message rejected: \(sendResponse)")
        }
    }

    private func quit(connection: NWConnection) async throws {
        try await sendCommand(connection: connection, command: "QUIT")
    }

    private func buildEmailContent(
        from sender: String,
        senderName: String?,
        to recipients: [String],
        subject: String,
        body: String,
        isHTML: Bool = false
    ) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        let dateString = dateFormatter.string(from: Date())

        let encodedSubject = encodeSubject(subject)

        let fromHeader: String
        if let senderName, !senderName.isEmpty {
            let encodedName = encodeSubject(senderName)
            fromHeader = "\(encodedName) <\(sender)>"
        } else {
            fromHeader = sender
        }

        let contentType = isHTML ? "text/html; charset=UTF-8" : "text/plain; charset=UTF-8"

        let headers = [
            "From: \(fromHeader)",
            "To: \(recipients.joined(separator: ", "))",
            "Subject: \(encodedSubject)",
            "Date: \(dateString)",
            "MIME-Version: 1.0",
            "Content-Type: \(contentType)",
            "Content-Transfer-Encoding: 8bit",
        ]

        return headers.joined(separator: "\r\n") + "\r\n\r\n" + body
    }

    private func encodeSubject(_ subject: String) -> String {
        let base64 = Data(subject.utf8).base64EncodedString()
        return "=?UTF-8?B?\(base64)?="
    }

    private func sendCommand(connection: NWConnection, command: String) async throws {
        let data = Data((command + "\r\n").utf8)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(
                content: data,
                completion: .contentProcessed { @Sendable error in
                    if let error {
                        continuation.resume(throwing: EmailError.sendFailed(error.localizedDescription))
                    } else {
                        continuation.resume()
                    }
                })
        }
    }

    private func readResponse(connection: NWConnection) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) {
                @Sendable data, _, _, error in
                if let error {
                    continuation.resume(throwing: EmailError.connectionFailed(error.localizedDescription))
                    return
                }

                guard let data, let response = String(data: data, encoding: .utf8) else {
                    continuation.resume(throwing: EmailError.invalidResponse("Empty response"))
                    return
                }

                continuation.resume(returning: response.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
    }
}
