import SwiftUI
import WidgetKit
import OneClient

@main
struct OneWidgetsBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        OneTodayQueueWidget()

        if #available(iOS 18.0, *) {
            OneAddNoteControlWidget()
            OneAddTaskControlWidget()
            OneAddExpenseControlWidget()
            OneAddIncomeControlWidget()
        }
    }
}
