#if canImport(AppIntents) && os(iOS)
import AppIntents
import Foundation

@available(iOS 17.0, *)
public struct OneAppIntentsPackage: AppIntentsPackage {
    public static var includedPackages: [any AppIntentsPackage.Type] { [] }
}

@available(iOS 17.0, *)
public enum OneTodayItemIntentType: String, AppEnum {
    case habit
    case todo

    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Today Item"
    }

    public static var caseDisplayRepresentations: [Self: DisplayRepresentation] {
        [
            .habit: DisplayRepresentation(title: "Habit"),
            .todo: DisplayRepresentation(title: "Task"),
        ]
    }

    var itemType: ItemType {
        switch self {
        case .habit:
            return .habit
        case .todo:
            return .todo
        }
    }
}

@available(iOS 17.0, *)
public protocol OneOpenAppRouteIntent: AppIntent {
    var route: OneSystemRoute { get }
}

@available(iOS 17.0, *)
public extension OneOpenAppRouteIntent {
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes {
        .foreground(.immediate)
    }

    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        try OneSystemRouteStore.storePending(route)
        return .result()
    }
}

@available(iOS 17.0, *)
public struct AddNoteIntent: OneOpenAppRouteIntent {
    public static let title: LocalizedStringResource = "Add Note"
    public static let description = IntentDescription("Open One directly into the quick note composer.")

    public init() {}

    public var route: OneSystemRoute {
        .addNote(anchorDate: nil)
    }
}

@available(iOS 17.0, *)
public struct AddTaskIntent: OneOpenAppRouteIntent {
    public static let title: LocalizedStringResource = "Add Task"
    public static let description = IntentDescription("Open One directly into the task quick-entry flow.")

    public init() {}

    public var route: OneSystemRoute {
        .addTask
    }
}

@available(iOS 17.0, *)
public struct AddExpenseIntent: OneOpenAppRouteIntent {
    public static let title: LocalizedStringResource = "Add Expense"
    public static let description = IntentDescription("Open One directly into the expense quick-entry flow.")

    public init() {}

    public var route: OneSystemRoute {
        .addExpense
    }
}

@available(iOS 17.0, *)
public struct AddIncomeIntent: OneOpenAppRouteIntent {
    public static let title: LocalizedStringResource = "Add Income"
    public static let description = IntentDescription("Open One directly into the income quick-entry flow.")

    public init() {}

    public var route: OneSystemRoute {
        .addIncome
    }
}

@available(iOS 17.0, *)
public struct OpenTodayConfirmationIntent: OneOpenAppRouteIntent {
    public static let title: LocalizedStringResource = "Open Today Confirmation"
    public static let description = IntentDescription("Open One into the lightweight confirmation flow for a Today item.")
    public static var isDiscoverable: Bool { false }

    @Parameter(title: "Item Type")
    public var itemType: OneTodayItemIntentType

    @Parameter(title: "Item ID")
    public var itemId: String

    @Parameter(title: "Date")
    public var dateLocal: String

    public init() {}

    public init(itemType: OneTodayItemIntentType, itemId: String, dateLocal: String) {
        self.itemType = itemType
        self.itemId = itemId
        self.dateLocal = dateLocal
    }

    public var route: OneSystemRoute {
        .confirmTodayItem(itemType: itemType.itemType, itemId: itemId, dateLocal: dateLocal)
    }
}

@available(iOS 17.0, *)
public struct OneShortcutsProvider: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddNoteIntent(),
            phrases: [
                "Add note in \(.applicationName)",
                "Capture note in \(.applicationName)",
            ],
            shortTitle: "Add Note",
            systemImageName: "square.and.pencil"
        )

        AppShortcut(
            intent: AddTaskIntent(),
            phrases: [
                "Add task in \(.applicationName)",
                "Queue task in \(.applicationName)",
            ],
            shortTitle: "Add Task",
            systemImageName: "checklist"
        )

        AppShortcut(
            intent: AddExpenseIntent(),
            phrases: [
                "Add expense in \(.applicationName)",
                "Log expense in \(.applicationName)",
            ],
            shortTitle: "Add Expense",
            systemImageName: "minus.circle"
        )

        AppShortcut(
            intent: AddIncomeIntent(),
            phrases: [
                "Add income in \(.applicationName)",
                "Log income in \(.applicationName)",
            ],
            shortTitle: "Add Income",
            systemImageName: "plus.circle"
        )
    }
}
#endif
