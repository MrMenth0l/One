#if DEBUG && os(iOS) && canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

@MainActor
private enum OnePreviewFixtures {
    static let anchorDate = "2026-04-11"

    static func makeContainer() -> OneAppContainer {
        let sessionStore = InMemoryAuthSessionStore()
        let stack = try! LocalPersistenceFactory.makeInMemory(sessionStore: sessionStore)

        return OneAppContainer(
            authRepository: DefaultAuthRepository(apiClient: stack.apiClient),
            tasksRepository: DefaultTasksRepository(apiClient: stack.apiClient, syncQueue: stack.syncQueue),
            todayRepository: DefaultTodayRepository(apiClient: stack.apiClient, syncQueue: stack.syncQueue),
            financeRepository: LocalFinanceRepository(container: stack.container, sessionStore: sessionStore),
            analyticsRepository: DefaultAnalyticsRepository(apiClient: stack.apiClient),
            reflectionsRepository: DefaultReflectionsRepository(apiClient: stack.apiClient),
            profileRepository: DefaultProfileRepository(apiClient: stack.apiClient),
            coachRepository: DefaultCoachRepository(apiClient: stack.apiClient),
            notificationApplier: NoopNotificationPreferenceApplier()
        )
    }

    static func seedIfNeeded(_ container: OneAppContainer) async {
        if container.todayViewModel.totalCount > 0 {
            return
        }

        if container.authViewModel.user == nil {
            await container.authViewModel.createLocalProfile(displayName: "Preview User")
        }

        await container.tasksViewModel.loadCategories()
        let categories = container.tasksViewModel.categories
        guard categories.count >= 3 else {
            await container.refreshAll(anchorDate: anchorDate)
            return
        }

        if container.tasksViewModel.habits.isEmpty && container.tasksViewModel.todos.isEmpty {
            _ = await container.tasksViewModel.createTodo(
                input: TodoCreateInput(
                    categoryId: categories[1].id,
                    title: "Prepare review summary",
                    notes: "Pull the missed items into one clear sequence.",
                    dueAt: previewDate(hour: 9),
                    priority: 95,
                    isPinned: true
                )
            )
            _ = await container.tasksViewModel.createTodo(
                input: TodoCreateInput(
                    categoryId: categories[2].id,
                    title: "Ship layout cleanup",
                    notes: "Tighten hierarchy and remove visual collisions before lunch.",
                    dueAt: previewDate(hour: 13),
                    priority: 76
                )
            )
            _ = await container.tasksViewModel.createHabit(
                input: HabitCreateInput(
                    categoryId: categories[0].id,
                    title: "Movement block",
                    notes: "Keep it light and consistent.",
                    recurrenceRule: "DAILY",
                    startDate: anchorDate,
                    preferredTime: "07:30:00"
                )
            )
            _ = await container.tasksViewModel.createHabit(
                input: HabitCreateInput(
                    categoryId: categories[3].id,
                    title: "Evening reset",
                    notes: "Short reflection plus desk reset.",
                    recurrenceRule: "DAILY",
                    startDate: anchorDate,
                    preferredTime: "20:00:00"
                )
            )
        }

        await container.refreshAll(anchorDate: anchorDate)
    }

    private static func previewDate(hour: Int) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        let base = calendar.startOfDay(for: Date())
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: base) ?? base
    }
}

private struct OneAppShellPreviewHost: View {
    @StateObject private var container = OnePreviewFixtures.makeContainer()

    var body: some View {
        OneAppShell(container: container)
            .task {
                await OnePreviewFixtures.seedIfNeeded(container)
            }
    }
}

private struct TodaySurfacePreviewHost: View {
    @StateObject private var container = OnePreviewFixtures.makeContainer()

    var body: some View {
        TodayOperationalSurfaceView(
            todayViewModel: container.todayViewModel,
            tasksViewModel: container.tasksViewModel,
            currentDateLocal: OnePreviewFixtures.anchorDate,
            onOpenSheet: { _ in },
            onOpenReview: { _ in },
            onRefreshTasksContext: {
                await container.refreshTasksContext(anchorDate: OnePreviewFixtures.anchorDate)
            },
            onRefreshAnalytics: {
                await container.refreshAnalytics(anchorDate: OnePreviewFixtures.anchorDate)
            }
        )
        .task {
            await OnePreviewFixtures.seedIfNeeded(container)
        }
    }
}

#Preview("App Shell") {
    OneAppShellPreviewHost()
}

#Preview("Today Surface") {
    TodaySurfacePreviewHost()
}

#Preview("Today Surface Dark") {
    TodaySurfacePreviewHost()
        .preferredColorScheme(.dark)
}
#endif
