import Foundation

public struct ReminderSchedule: Sendable, Equatable {
    public let id: String
    public let hour: Int
    public let minute: Int

    public init(id: String, hour: Int, minute: Int) {
        self.id = id
        self.hour = hour
        self.minute = minute
    }
}

public struct ReminderScheduler {
    public init() {}

    public func isInQuietHours(hour: Int, minute: Int, quietStart: String?, quietEnd: String?) -> Bool {
        guard let quietStart, let quietEnd,
              let start = parseHHMM(quietStart), let end = parseHHMM(quietEnd) else {
            return false
        }

        let current = hour * 60 + minute
        let startValue = start.hour * 60 + start.minute
        let endValue = end.hour * 60 + end.minute

        if startValue < endValue {
            return current >= startValue && current < endValue
        }

        return current >= startValue || current < endValue
    }

    public func dueReminders(
        schedules: [ReminderSchedule],
        nowHour: Int,
        nowMinute: Int,
        quietStart: String?,
        quietEnd: String?
    ) -> [ReminderSchedule] {
        guard !isInQuietHours(hour: nowHour, minute: nowMinute, quietStart: quietStart, quietEnd: quietEnd) else {
            return []
        }

        return schedules.filter { $0.hour == nowHour && $0.minute == nowMinute }
    }

    public func buildSchedules(
        habits: [Habit],
        todos: [Todo],
        preferences: UserPreferences
    ) -> [ReminderSchedule] {
        var output: [ReminderSchedule] = []
        let habitEnabled = preferences.notificationFlags["habit_reminders"] ?? true
        let todoEnabled = preferences.notificationFlags["todo_reminders"] ?? true

        if habitEnabled {
            for habit in habits where habit.isActive {
                guard let preferredTime = habit.preferredTime,
                      let parsed = parseHHMM(preferredTime) else {
                    continue
                }
                output.append(
                    ReminderSchedule(
                        id: "habit:\(habit.id)",
                        hour: parsed.hour,
                        minute: parsed.minute
                    )
                )
            }
        }

        if todoEnabled {
            let cal = Calendar.current
            for todo in todos where todo.status == .open {
                guard let dueAt = todo.dueAt else {
                    continue
                }
                let comps = cal.dateComponents([.hour, .minute], from: dueAt)
                guard let hour = comps.hour, let minute = comps.minute else {
                    continue
                }
                output.append(
                    ReminderSchedule(
                        id: "todo:\(todo.id)",
                        hour: hour,
                        minute: minute
                    )
                )
            }
        }
        return output
    }

    private func parseHHMM(_ value: String) -> (hour: Int, minute: Int)? {
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
}
