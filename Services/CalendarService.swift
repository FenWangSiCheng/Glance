import EventKit
import Foundation

actor CalendarService {
    enum CalendarError: LocalizedError {
        case accessDenied
        case accessRestricted
        case noCalendarFound(String)
        case fetchError(Error)
        
        var errorDescription: String? {
            switch self {
            case .accessDenied:
                return "日历访问被拒绝，请在系统设置中授权"
            case .accessRestricted:
                return "日历访问受限"
            case .noCalendarFound(let name):
                return "未找到日历: \(name)"
            case .fetchError(let error):
                return "获取日历事件失败: \(error.localizedDescription)"
            }
        }
    }
    
    private let eventStore = EKEventStore()

    func requestAccess() async throws -> Bool {
        print("📅 [CalendarService] Requesting calendar access...")

        let currentStatus = await checkAuthorizationStatus()
        print("📅 [CalendarService] Current authorization status: \(currentStatus.rawValue) (\(statusDescription(currentStatus)))")

        if currentStatus == .authorized {
            print("✅ [CalendarService] Already have calendar access")
            return true
        }

        if #available(macOS 14.0, *) {
            if currentStatus == .fullAccess {
                print("✅ [CalendarService] Already have full calendar access")
                return true
            }
        }

        if currentStatus == .denied {
            print("❌ [CalendarService] Calendar access denied, user needs to grant permission in System Settings")
            throw CalendarError.accessDenied
        }

        if currentStatus == .restricted {
            print("❌ [CalendarService] Calendar access restricted")
            throw CalendarError.accessRestricted
        }

        let result: Bool
        if #available(macOS 14.0, *) {
            print("📅 [CalendarService] Using macOS 14.0+ API - requesting full access")
            do {
                result = try await eventStore.requestFullAccessToEvents()
                print("📅 [CalendarService] requestFullAccessToEvents result: \(result)")
            } catch {
                print("❌ [CalendarService] Error requesting access: \(error)")
                throw error
            }

            let finalStatus = await checkAuthorizationStatus()
            print("📅 [CalendarService] Final authorization status: \(finalStatus.rawValue) (\(statusDescription(finalStatus)))")

            return finalStatus == .fullAccess || finalStatus == .authorized
        } else {
            print("📅 [CalendarService] Using macOS 13.0 API")
            result = try await withCheckedThrowingContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, error in
                    print("📅 [CalendarService] Access callback: granted=\(granted), error=\(String(describing: error))")
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
            print("📅 [CalendarService] Access request completed, result: \(result)")
            return result
        }
    }

    private func statusDescription(_ status: EKAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "未决定"
        case .restricted:
            return "受限"
        case .denied:
            return "被拒绝"
        case .authorized:
            return "已授权"
        case .fullAccess:
            if #available(macOS 14.0, *) {
                return "完整访问"
            }
            return "未知"
        case .writeOnly:
            if #available(macOS 14.0, *) {
                return "仅写入"
            }
            return "未知"
        @unknown default:
            return "未知状态"
        }
    }

    func checkAuthorizationStatus() async -> EKAuthorizationStatus {
        if #available(macOS 14.0, *) {
            return EKEventStore.authorizationStatus(for: .event)
        } else {
            return EKEventStore.authorizationStatus(for: .event)
        }
    }

    /// Returns calendar info (id and title) in a Sendable format
    func fetchCalendarInfo() async -> [CalendarInfo] {
        eventStore.calendars(for: .event).map { calendar in
            CalendarInfo(id: calendar.calendarIdentifier, title: calendar.title)
        }
    }

    func fetchEvents(
        calendarIds: [String]?,
        daysAhead: Int = 1
    ) async throws -> [CalendarEvent] {
        let calendars: [EKCalendar]?
        if let ids = calendarIds, !ids.isEmpty {
            calendars = eventStore.calendars(for: .event)
                .filter { ids.contains($0.calendarIdentifier) }
        } else {
            calendars = nil
        }

        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: Date())
        let endDate: Date
        if daysAhead == 1 {
            endDate = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: Date()) ?? calendar.date(byAdding: .day, value: 1, to: startDate)!
        } else {
            endDate = calendar.date(byAdding: .day, value: daysAhead, to: startDate)!
        }

        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: calendars
        )

        return eventStore.events(matching: predicate).map { event in
            CalendarEvent(
                id: event.eventIdentifier,
                title: event.title ?? "无标题",
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay,
                location: event.location,
                calendarName: event.calendar.title
            )
        }
    }
}

/// Sendable representation of calendar info for cross-actor use
struct CalendarInfo: Sendable {
    let id: String
    let title: String
}

