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
    
    /// 请求日历访问权限
    func requestAccess() async throws -> Bool {
        print("📅 [CalendarService] 开始请求日历访问权限...")
        
        // 先检查当前状态
        let currentStatus = await checkAuthorizationStatus()
        print("📅 [CalendarService] 当前授权状态: \(currentStatus.rawValue) (\(statusDescription(currentStatus)))")
        
        // 如果已经授权，直接返回
        if currentStatus == .authorized {
            print("✅ [CalendarService] 已经拥有日历访问权限")
            return true
        }
        
        if #available(macOS 14.0, *) {
            // macOS 14.0+ 检查是否有完整访问权限
            if currentStatus == .fullAccess {
                print("✅ [CalendarService] 已经拥有完整日历访问权限")
                return true
            }
        }
        
        // 如果权限被拒绝，抛出特定错误
        if currentStatus == .denied {
            print("❌ [CalendarService] 日历权限已被拒绝，需要用户在系统设置中手动授权")
            throw CalendarError.accessDenied
        }
        
        // 如果权限受限
        if currentStatus == .restricted {
            print("❌ [CalendarService] 日历权限受限")
            throw CalendarError.accessRestricted
        }
        
        let result: Bool
        if #available(macOS 14.0, *) {
            print("📅 [CalendarService] 使用 macOS 14.0+ API - 请求完整访问权限")
            // macOS 14.0+ 需要请求完整访问权限才能读取事件
            do {
                result = try await eventStore.requestFullAccessToEvents()
                print("📅 [CalendarService] requestFullAccessToEvents 结果: \(result)")
            } catch {
                print("❌ [CalendarService] 请求权限时发生错误: \(error)")
                throw error
            }
            
            // 检查最终状态
            let finalStatus = await checkAuthorizationStatus()
            print("📅 [CalendarService] 最终授权状态: \(finalStatus.rawValue) (\(statusDescription(finalStatus)))")
            
            // macOS 14.0+ 需要 fullAccess 才能读取所有事件详情
            return finalStatus == .fullAccess || finalStatus == .authorized
        } else {
            print("📅 [CalendarService] 使用 macOS 13.0 API")
            result = try await withCheckedThrowingContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, error in
                    print("📅 [CalendarService] 权限回调: granted=\(granted), error=\(String(describing: error))")
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
            print("📅 [CalendarService] 权限请求完成，结果: \(result)")
            return result
        }
    }
    
    /// 获取状态描述（用于调试）
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
    
    /// 检查当前授权状态
    func checkAuthorizationStatus() async -> EKAuthorizationStatus {
        if #available(macOS 14.0, *) {
            return EKEventStore.authorizationStatus(for: .event)
        } else {
            return EKEventStore.authorizationStatus(for: .event)
        }
    }
    
    /// 获取所有日历列表（供用户选择）
    func fetchCalendars() async -> [EKCalendar] {
        eventStore.calendars(for: .event)
    }
    
    /// 获取指定日历的今日及未来事件
    func fetchEvents(
        calendarIds: [String]?,  // nil = 所有日历
        daysAhead: Int = 7
    ) async throws -> [CalendarEvent] {
        let calendars: [EKCalendar]?
        if let ids = calendarIds, !ids.isEmpty {
            calendars = eventStore.calendars(for: .event)
                .filter { ids.contains($0.calendarIdentifier) }
        } else {
            calendars = nil
        }
        
        let startDate = Calendar.current.startOfDay(for: Date())
        let endDate = Calendar.current.date(byAdding: .day, value: daysAhead, to: startDate)!
        
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

