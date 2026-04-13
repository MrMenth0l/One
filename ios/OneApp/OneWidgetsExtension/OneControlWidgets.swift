import SwiftUI
import WidgetKit
import OneClient
import AppIntents

@available(iOS 18.0, *)
private struct OneControlLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
    }
}

@available(iOS 18.0, *)
private enum OneControlActionURL {
    static let addNote = OneSystemRoute.addNote(anchorDate: nil).url()
    static let addTask = OneSystemRoute.addTask.url()
    static let addExpense = OneSystemRoute.addExpense.url()
    static let addIncome = OneSystemRoute.addIncome.url()
}

@available(iOS 18.0, *)
struct OneAddNoteControlWidget: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.yehosuah.one.control.add-note") {
            // Lock Screen controls are single-action surfaces, so New Note is the fallback
            // quick action entry point instead of attempting a multi-action control cluster.
            ControlWidgetButton(action: OpenURLIntent(OneControlActionURL.addNote)) {
                OneControlLabel(title: "Add Note", systemImage: "square.and.pencil")
            }
        }
        .displayName("Add Note")
        .description("Open One directly into a quick note.")
    }
}

@available(iOS 18.0, *)
struct OneAddTaskControlWidget: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.yehosuah.one.control.add-task") {
            ControlWidgetButton(action: OpenURLIntent(OneControlActionURL.addTask)) {
                OneControlLabel(title: "Add Task", systemImage: "checklist")
            }
        }
        .displayName("Add Task")
        .description("Open One directly into task capture.")
    }
}

@available(iOS 18.0, *)
struct OneAddExpenseControlWidget: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.yehosuah.one.control.add-expense") {
            ControlWidgetButton(action: OpenURLIntent(OneControlActionURL.addExpense)) {
                OneControlLabel(title: "Add Expense", systemImage: "minus.circle")
            }
        }
        .displayName("Add Expense")
        .description("Open One directly into expense capture.")
    }
}

@available(iOS 18.0, *)
struct OneAddIncomeControlWidget: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.yehosuah.one.control.add-income") {
            ControlWidgetButton(action: OpenURLIntent(OneControlActionURL.addIncome)) {
                OneControlLabel(title: "Add Income", systemImage: "plus.circle")
            }
        }
        .displayName("Add Income")
        .description("Open One directly into income capture.")
    }
}
