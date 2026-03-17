import Foundation

public protocol LocalNotificationService: Sendable {
    func refresh(
        habits: [Habit],
        todos: [Todo],
        preferences: UserPreferences
    ) async -> NotificationScheduleStatus
}

public struct NoopLocalNotificationService: LocalNotificationService {
    public init() {}

    public func refresh(
        habits: [Habit],
        todos: [Todo],
        preferences: UserPreferences
    ) async -> NotificationScheduleStatus {
        NotificationScheduleStatus(
            permissionGranted: false,
            scheduledCount: 0,
            lastRefreshedAt: Date(),
            lastError: "Local notifications are unavailable on this platform."
        )
    }
}

#if canImport(UserNotifications) && os(iOS)
import UserNotifications

public struct UserNotificationCenterService: LocalNotificationService, @unchecked Sendable {
    private let center: UNUserNotificationCenter
    private let reminderScheduler: ReminderScheduler

    public init(
        center: UNUserNotificationCenter = .current(),
        reminderScheduler: ReminderScheduler = ReminderScheduler()
    ) {
        self.center = center
        self.reminderScheduler = reminderScheduler
    }

    public func refresh(
        habits: [Habit],
        todos: [Todo],
        preferences: UserPreferences
    ) async -> NotificationScheduleStatus {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            guard granted else {
                await clearManagedRequests()
                return NotificationScheduleStatus(
                    permissionGranted: false,
                    scheduledCount: 0,
                    lastRefreshedAt: Date(),
                    lastError: "Notification permission not granted."
                )
            }

            var scheduledCount = 0
            await clearManagedRequests()

            if preferences.notificationFlags["habit_reminders"] ?? true {
                for habit in habits where habit.isActive {
                    guard let preferredTime = habit.preferredTime,
                          let parsed = parseTime(preferredTime),
                          !reminderScheduler.isInQuietHours(
                              hour: parsed.hour,
                              minute: parsed.minute,
                              quietStart: preferences.quietHoursStart,
                              quietEnd: preferences.quietHoursEnd
                          ) else {
                        continue
                    }

                    let content = UNMutableNotificationContent()
                    content.title = "Habit Reminder"
                    content.body = habit.title
                    content.sound = .default
                    content.userInfo = ["type": "habit", "habit_id": habit.id]

                    var components = DateComponents()
                    components.hour = parsed.hour
                    components.minute = parsed.minute
                    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                    let request = UNNotificationRequest(
                        identifier: "one.reminder.habit.\(habit.id)",
                        content: content,
                        trigger: trigger
                    )
                    try await add(request)
                    scheduledCount += 1
                }
            }

            if preferences.notificationFlags["todo_reminders"] ?? true {
                for todo in todos where todo.status == .open {
                    guard let dueAt = todo.dueAt, dueAt > Date() else {
                        continue
                    }
                    let cal = Calendar.current
                    let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: dueAt)
                    guard let hour = comps.hour, let minute = comps.minute else {
                        continue
                    }
                    if reminderScheduler.isInQuietHours(
                        hour: hour,
                        minute: minute,
                        quietStart: preferences.quietHoursStart,
                        quietEnd: preferences.quietHoursEnd
                    ) {
                        continue
                    }

                    let content = UNMutableNotificationContent()
                    content.title = "Todo Reminder"
                    content.body = todo.title
                    content.sound = .default
                    content.userInfo = ["type": "todo", "todo_id": todo.id]

                    let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                    let request = UNNotificationRequest(
                        identifier: "one.reminder.todo.\(todo.id)",
                        content: content,
                        trigger: trigger
                    )
                    try await add(request)
                    scheduledCount += 1
                }
            }

            return NotificationScheduleStatus(
                permissionGranted: true,
                scheduledCount: scheduledCount,
                lastRefreshedAt: Date(),
                lastError: nil
            )
        } catch {
            return NotificationScheduleStatus(
                permissionGranted: false,
                scheduledCount: 0,
                lastRefreshedAt: Date(),
                lastError: String(describing: error)
            )
        }
    }

    private func parseTime(_ value: String) -> (hour: Int, minute: Int)? {
        let parts = value.split(separator: ":")
        guard parts.count == 2 || parts.count == 3,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            return nil
        }
        return (hour, minute)
    }

    private func clearManagedRequests() async {
        let ids = await managedRequestIDs()
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    private func managedRequestIDs() async -> [String] {
        await withCheckedContinuation { (continuation: CheckedContinuation<[String], Never>) in
            center.getPendingNotificationRequests { requests in
                let ids = requests
                    .map(\.identifier)
                    .filter { $0.hasPrefix("one.reminder.habit.") || $0.hasPrefix("one.reminder.todo.") }
                continuation.resume(returning: ids)
            }
        }
    }

    private func add(_ request: UNNotificationRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            center.add(request, withCompletionHandler: { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            })
        }
    }
}
#endif
