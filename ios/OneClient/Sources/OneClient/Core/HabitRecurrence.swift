import Foundation

public enum HabitRecurrenceFrequency: String, Codable, Sendable, CaseIterable {
    case daily
    case weekly
    case monthly
    case yearly

    public var title: String {
        switch self {
        case .daily:
            return "Daily"
        case .weekly:
            return "Weekly"
        case .monthly:
            return "Monthly"
        case .yearly:
            return "Yearly"
        }
    }
}

public enum HabitRecurrenceWeekday: String, Codable, Sendable, CaseIterable, Hashable {
    case monday = "MON"
    case tuesday = "TUE"
    case wednesday = "WED"
    case thursday = "THU"
    case friday = "FRI"
    case saturday = "SAT"
    case sunday = "SUN"

    public var shortTitle: String {
        switch self {
        case .monday:
            return "Mon"
        case .tuesday:
            return "Tue"
        case .wednesday:
            return "Wed"
        case .thursday:
            return "Thu"
        case .friday:
            return "Fri"
        case .saturday:
            return "Sat"
        case .sunday:
            return "Sun"
        }
    }
}

public struct HabitRecurrenceYearlyDate: Codable, Sendable, Equatable, Hashable {
    public let month: Int
    public let day: Int

    public init(month: Int, day: Int) {
        self.month = min(max(month, 1), 12)
        self.day = min(max(day, 1), 31)
    }

    public var rawValue: String {
        String(format: "%02d-%02d", month, day)
    }

    public var title: String {
        guard
            let date = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: month, day: day))
        else {
            return rawValue
        }
        return Self.displayFormatter.string(from: date)
    }

    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"
        return formatter
    }()
}

public struct HabitRecurrenceRule: Codable, Sendable, Equatable {
    public var frequency: HabitRecurrenceFrequency
    public var weekdays: [HabitRecurrenceWeekday]
    public var monthDays: [Int]
    public var yearlyDates: [HabitRecurrenceYearlyDate]

    public init(
        frequency: HabitRecurrenceFrequency = .daily,
        weekdays: [HabitRecurrenceWeekday] = [],
        monthDays: [Int] = [],
        yearlyDates: [HabitRecurrenceYearlyDate] = []
    ) {
        self.frequency = frequency
        self.weekdays = Self.normalizeWeekdays(weekdays)
        self.monthDays = Self.normalizeMonthDays(monthDays)
        self.yearlyDates = Self.normalizeYearlyDates(yearlyDates)
    }

    public init(rawValue: String) {
        let segments = rawValue.split(separator: ":", maxSplits: 1).map(String.init)
        let mode = segments.first?.uppercased() ?? "DAILY"
        let values = segments.count > 1
            ? segments[1].split(separator: ",").map(String.init)
            : []

        switch mode {
        case "WEEKLY":
            self.init(
                frequency: .weekly,
                weekdays: values.compactMap(HabitRecurrenceWeekday.init(rawValue:))
            )
        case "MONTHLY":
            self.init(
                frequency: .monthly,
                monthDays: values.compactMap(Int.init)
            )
        case "YEARLY":
            self.init(
                frequency: .yearly,
                yearlyDates: values.compactMap(Self.parseYearlyDate)
            )
        default:
            self.init(frequency: .daily)
        }
    }

    public var rawValue: String {
        switch frequency {
        case .daily:
            return "DAILY"
        case .weekly:
            let values = Self.normalizeWeekdays(weekdays)
            return values.isEmpty ? "DAILY" : "WEEKLY:\(values.map(\.rawValue).joined(separator: ","))"
        case .monthly:
            let values = Self.normalizeMonthDays(monthDays)
            return values.isEmpty ? "DAILY" : "MONTHLY:\(values.map(String.init).joined(separator: ","))"
        case .yearly:
            let values = Self.normalizeYearlyDates(yearlyDates)
            return values.isEmpty ? "DAILY" : "YEARLY:\(values.map(\.rawValue).joined(separator: ","))"
        }
    }

    public var summary: String {
        switch frequency {
        case .daily:
            return "Every day"
        case .weekly:
            let values = Self.normalizeWeekdays(weekdays)
            if values.isEmpty {
                return "Every day"
            }
            return "Every \(values.map(\.shortTitle).joined(separator: ", "))"
        case .monthly:
            let values = Self.normalizeMonthDays(monthDays)
            if values.isEmpty {
                return "Every day"
            }
            return "Monthly on \(values.map(String.init).joined(separator: ", "))"
        case .yearly:
            let values = Self.normalizeYearlyDates(yearlyDates)
            if values.isEmpty {
                return "Every day"
            }
            return "Yearly on \(values.map(\.title).joined(separator: ", "))"
        }
    }

    private static func normalizeWeekdays(_ weekdays: [HabitRecurrenceWeekday]) -> [HabitRecurrenceWeekday] {
        HabitRecurrenceWeekday.allCases.filter { weekdays.contains($0) }
    }

    private static func normalizeMonthDays(_ days: [Int]) -> [Int] {
        Array(Set(days.filter { (1...31).contains($0) })).sorted()
    }

    private static func normalizeYearlyDates(_ dates: [HabitRecurrenceYearlyDate]) -> [HabitRecurrenceYearlyDate] {
        Array(Set(dates)).sorted {
            if $0.month != $1.month {
                return $0.month < $1.month
            }
            return $0.day < $1.day
        }
    }

    private static func parseYearlyDate(_ rawValue: String) -> HabitRecurrenceYearlyDate? {
        let parts = rawValue.split(separator: "-").map(String.init)
        guard parts.count == 2, let month = Int(parts[0]), let day = Int(parts[1]) else {
            return nil
        }
        return HabitRecurrenceYearlyDate(month: month, day: day)
    }
}
