import Foundation
import OneClient

@main
struct OneClientChecks {
    static func main() async {
        do {
            try await run()
            print("OneClient checks: OK")
        } catch {
            print("OneClient checks failed: \(error)")
            exit(1)
        }
    }

    static func run() async throws {
        try await checkOfflineLocalDataFlow()
        try await checkStoredLocalPersistenceBootstrap()
        try await checkStoredLocalSessionRepairAcrossRelaunch()
        try await checkExplicitLocalSignOutRequiresResumeAndKeepsData()
        try await checkWeeklyRecurrenceAcrossDeviceTimezones()
        try await checkTodayRepositoryToggle()
        try await checkTodayReorderPersistenceCall()
        try checkReminderScheduling()
        try await checkReflectionsUpsertAndList()
        try await checkServerTimestampWins()
        try await checkHTTPAPIClientMappingAndUnauthorizedHandoff()
        try await checkSyncQueueRetryBehavior()
        try await checkViewModelsFlow()
    }

    private static func checkOfflineLocalDataFlow() async throws {
        #if canImport(SwiftData)
        let sessionStore = InMemoryAuthSessionStore()
        let stack = try LocalPersistenceFactory.makeInMemory(sessionStore: sessionStore)

        let authRepository = DefaultAuthRepository(apiClient: stack.apiClient)
        let todayRepository = DefaultTodayRepository(apiClient: stack.apiClient, syncQueue: stack.syncQueue)
        let tasksRepository = DefaultTasksRepository(apiClient: stack.apiClient, syncQueue: stack.syncQueue)
        let analyticsRepository = DefaultAnalyticsRepository(apiClient: stack.apiClient)
        let reflectionsRepository = DefaultReflectionsRepository(apiClient: stack.apiClient)
        let profileRepository = DefaultProfileRepository(apiClient: stack.apiClient)
        let coachRepository = DefaultCoachRepository(apiClient: stack.apiClient)

        let user = try await authRepository.signup(
            email: "offline@one.local",
            password: "offline-local-profile",
            displayName: "Offline User",
            timezone: "America/Guatemala"
        )
        guard user.displayName == "Offline User" else {
            throw CheckError("expected local signup to persist user")
        }

        let categories = try await tasksRepository.loadCategories()
        guard categories.count == 5 else {
            throw CheckError("expected default categories to seed locally")
        }

        let habit = try await tasksRepository.createHabit(
            HabitCreateInput(
                categoryId: categories[0].id,
                title: "Workout",
                recurrenceRule: "DAILY",
                startDate: "2026-03-12",
                priorityWeight: 80,
                preferredTime: "06:30"
            )
        )
        let todo = try await tasksRepository.createTodo(
            TodoCreateInput(
                categoryId: categories[1].id,
                title: "Study quiz",
                dueAt: ISO8601DateFormatter().date(from: "2026-03-12T15:00:00Z"),
                priority: 70,
                isPinned: true
            )
        )

        let initialToday = try await todayRepository.loadToday(date: "2026-03-12")
        guard initialToday.totalCount == 2 else {
            throw CheckError("expected local today materialization to include habit and todo")
        }
        guard initialToday.items.first?.itemId == todo.id else {
            throw CheckError("expected pinned todo to order before habit in local runtime")
        }

        let reorderedToday = try await todayRepository.reorder(
            dateLocal: "2026-03-12",
            items: [
                TodayOrderItem(itemType: .habit, itemId: habit.id, orderIndex: 0),
                TodayOrderItem(itemType: .todo, itemId: todo.id, orderIndex: 1),
            ]
        )
        guard reorderedToday.items.first?.itemId == habit.id else {
            throw CheckError("expected manual today reorder to persist locally")
        }

        let completedToday = try await todayRepository.setCompletion(
            itemType: .habit,
            itemId: habit.id,
            dateLocal: "2026-03-12",
            state: .completed
        )
        guard completedToday.completedCount == 1 else {
            throw CheckError("expected offline completion toggle to update today counters")
        }

        let weekly = try await analyticsRepository.loadPeriod(anchorDate: "2026-03-12", periodType: .weekly)
        guard weekly.completedItems >= 1 else {
            throw CheckError("expected offline analytics to include completed item")
        }

        _ = try await reflectionsRepository.upsert(
            input: ReflectionWriteInput(
                periodType: .daily,
                periodStart: "2026-03-12",
                periodEnd: "2026-03-12",
                content: "Solid session",
                sentiment: .focused
            )
        )
        _ = try await reflectionsRepository.upsert(
            input: ReflectionWriteInput(
                periodType: .daily,
                periodStart: "2026-03-12",
                periodEnd: "2026-03-12",
                content: "Second note",
                sentiment: .great
            )
        )
        let reflections = try await reflectionsRepository.list(periodType: .daily)
        guard reflections.count == 2 else {
            throw CheckError("expected quick notes to append locally")
        }

        let cards = try await coachRepository.loadCards()
        guard !cards.isEmpty else {
            throw CheckError("expected coach cards to seed locally")
        }
        guard cards.contains(where: { ($0.verseText ?? "").isEmpty == false }) else {
            throw CheckError("expected coach cards to include verse text")
        }

        let restored = await authRepository.restoreSession()
        guard restored?.id == user.id else {
            throw CheckError("expected local session restore to reuse stored profile")
        }

        let preferences = try await profileRepository.loadPreferences()
        guard preferences.notificationFlags["habit_reminders"] == true else {
            throw CheckError("expected default preferences to seed locally")
        }
        #endif
    }

    private static func checkStoredLocalPersistenceBootstrap() async throws {
        #if canImport(SwiftData)
        let sessionStore = InMemoryAuthSessionStore()
        let stack = try LocalPersistenceFactory.makeStored(sessionStore: sessionStore)
        let authRepository = DefaultAuthRepository(apiClient: stack.apiClient)
        let profileRepository = DefaultProfileRepository(apiClient: stack.apiClient)
        let suffix = String(UUID().uuidString.prefix(8))

        let user = try await authRepository.signup(
            email: "stored-\(suffix)@one.local",
            password: "offline-local-profile",
            displayName: "Stored \(suffix)",
            timezone: "America/Guatemala"
        )
        let restored = await authRepository.restoreSession()
        guard restored?.id == user.id else {
            throw CheckError("expected stored local signup to restore session")
        }

        let preferences = try await profileRepository.loadPreferences()
        guard preferences.userId == user.id else {
            throw CheckError("expected stored local signup to seed preferences")
        }
        #endif
    }

    private static func checkStoredLocalSessionRepairAcrossRelaunch() async throws {
        #if canImport(SwiftData)
        let suffix = String(UUID().uuidString.prefix(8))
        let initialSessionStore = InMemoryAuthSessionStore()
        let initialStack = try LocalPersistenceFactory.makeStored(sessionStore: initialSessionStore)
        let initialAuthRepository = DefaultAuthRepository(apiClient: initialStack.apiClient)
        let initialTasksRepository = DefaultTasksRepository(apiClient: initialStack.apiClient, syncQueue: initialStack.syncQueue)

        let user = try await initialAuthRepository.signup(
            email: "repair-\(suffix)@one.local",
            password: "offline-local-profile",
            displayName: "Repair \(suffix)",
            timezone: "America/Guatemala"
        )
        let categories = try await initialTasksRepository.loadCategories()
        let habitTitle = "Recovered Habit \(suffix)"
        let todoTitle = "Recovered Todo \(suffix)"
        _ = try await initialTasksRepository.createHabit(
            HabitCreateInput(
                categoryId: categories[0].id,
                title: habitTitle,
                recurrenceRule: "DAILY",
                startDate: "2026-03-12"
            )
        )
        _ = try await initialTasksRepository.createTodo(
            TodoCreateInput(
                categoryId: categories[1].id,
                title: todoTitle,
                dueAt: ISO8601DateFormatter().date(from: "2026-03-12T15:00:00Z")
            )
        )

        let relaunchedSessionStore = InMemoryAuthSessionStore()
        let relaunchedStack = try LocalPersistenceFactory.makeStored(sessionStore: relaunchedSessionStore)
        let relaunchedAuthRepository = DefaultAuthRepository(apiClient: relaunchedStack.apiClient)
        let relaunchedTasksRepository = DefaultTasksRepository(apiClient: relaunchedStack.apiClient, syncQueue: relaunchedStack.syncQueue)

        let restored = await relaunchedAuthRepository.restoreSession()
        guard restored?.id == user.id else {
            throw CheckError("expected stored local relaunch to repair missing session")
        }
        let habits = try await relaunchedTasksRepository.loadHabits()
        guard habits.contains(where: { $0.title == habitTitle }) else {
            throw CheckError("expected stored local habit to persist across relaunch")
        }
        let todos = try await relaunchedTasksRepository.loadTodos()
        guard todos.contains(where: { $0.title == todoTitle }) else {
            throw CheckError("expected stored local todo to persist across relaunch")
        }
        #endif
    }

    private static func checkExplicitLocalSignOutRequiresResumeAndKeepsData() async throws {
        #if canImport(SwiftData)
        let suffix = String(UUID().uuidString.prefix(8))
        let sessionStore = InMemoryAuthSessionStore()
        let stack = try LocalPersistenceFactory.makeInMemory(sessionStore: sessionStore)
        let authRepository = DefaultAuthRepository(apiClient: stack.apiClient)
        let tasksRepository = DefaultTasksRepository(apiClient: stack.apiClient, syncQueue: stack.syncQueue)

        let user = try await authRepository.signup(
            email: "signout-\(suffix)@one.local",
            password: "offline-local-profile",
            displayName: "Sign Out \(suffix)",
            timezone: "America/Guatemala"
        )
        let categories = try await tasksRepository.loadCategories()
        let habitTitle = "Saved After Signout \(suffix)"
        _ = try await tasksRepository.createHabit(
            HabitCreateInput(
                categoryId: categories[0].id,
                title: habitTitle,
                recurrenceRule: "DAILY",
                startDate: "2026-03-12"
            )
        )

        await authRepository.logout()
        guard await authRepository.restoreSession() == nil else {
            throw CheckError("expected explicit sign out to require resume before restoring a local session")
        }

        let resumed = try await authRepository.login(email: user.email, password: "")
        guard resumed.id == user.id else {
            throw CheckError("expected explicit resume to reopen the stored local profile")
        }

        let habits = try await tasksRepository.loadHabits()
        guard habits.contains(where: { $0.title == habitTitle }) else {
            throw CheckError("expected local habits to persist after explicit sign out")
        }
        #endif
    }

    private static func checkWeeklyRecurrenceAcrossDeviceTimezones() async throws {
        #if canImport(SwiftData)
        let originalTimeZone = NSTimeZone.default
        defer { NSTimeZone.default = originalTimeZone }

        for identifier in ["America/Los_Angeles", "Asia/Tokyo"] {
            guard let timeZone = TimeZone(identifier: identifier) else {
                throw CheckError("expected timezone \(identifier) to exist")
            }
            NSTimeZone.default = timeZone

            let sessionStore = InMemoryAuthSessionStore()
            let stack = try LocalPersistenceFactory.makeInMemory(sessionStore: sessionStore)
            let authRepository = DefaultAuthRepository(apiClient: stack.apiClient)
            let tasksRepository = DefaultTasksRepository(apiClient: stack.apiClient, syncQueue: stack.syncQueue)
            let todayRepository = DefaultTodayRepository(apiClient: stack.apiClient, syncQueue: stack.syncQueue)

            _ = try await authRepository.signup(
                email: "weekly-\(identifier.replacingOccurrences(of: "/", with: "-"))@one.local",
                password: "offline-local-profile",
                displayName: "Weekly \(identifier)",
                timezone: "America/Guatemala"
            )

            let categories = try await tasksRepository.loadCategories()
            _ = try await tasksRepository.createHabit(
                HabitCreateInput(
                    categoryId: categories[0].id,
                    title: "Midweek reset",
                    recurrenceRule: "WEEKLY:WED",
                    startDate: "2026-03-11"
                )
            )

            let wednesday = try await todayRepository.loadToday(date: "2026-03-11")
            let thursday = try await todayRepository.loadToday(date: "2026-03-12")

            if wednesday.items.filter({ $0.itemType == .habit }).count != 1 {
                throw CheckError("expected Wednesday habit on Wednesday for device timezone \(identifier)")
            }
            if thursday.items.contains(where: { $0.itemType == .habit }) {
                throw CheckError("did not expect Wednesday habit on Thursday for device timezone \(identifier)")
            }
        }
        #endif
    }

    private static func checkTodayRepositoryToggle() async throws {
        let api = MockAPIClient()
        await api.setTodayResponse(
            TodayResponse(
                dateLocal: "2026-03-12",
                items: [TodayItem(itemType: .habit, itemId: "h1", title: "Workout", categoryId: "c1", completed: false, sortBucket: 2, sortScore: 50)],
                completedCount: 0,
                totalCount: 1,
                completionRatio: 0
            )
        )

        let queue = InMemorySyncQueue()
        let repo = DefaultTodayRepository(apiClient: api, syncQueue: queue)
        _ = try await repo.loadToday(date: "2026-03-12")

        let updated = try await repo.setCompletion(itemType: .habit, itemId: "h1", dateLocal: "2026-03-12", state: .completed)
        guard updated.completedCount == 1 else {
            throw CheckError("expected completedCount == 1")
        }
    }

    private static func checkReminderScheduling() throws {
        let scheduler = ReminderScheduler()
        let dueAt = makeDate("2026-03-12T06:30:00Z")
        let habits = [
            Habit(
                id: "h1",
                userId: "u1",
                categoryId: "c1",
                title: "Workout",
                recurrenceRule: "DAILY",
                startDate: "2026-03-01",
                preferredTime: "06:30:00"
            )
        ]
        let todos = [
            Todo(
                id: "t1",
                userId: "u1",
                categoryId: "c1",
                title: "Submit",
                dueAt: dueAt,
                status: .open
            )
        ]
        let preferences = UserPreferences(
            id: "p1",
            userId: "u1",
            notificationFlags: [
                "habit_reminders": true,
                "todo_reminders": true,
                "reflection_prompts": true,
                "weekly_summary": true,
            ],
            quietHoursStart: "22:00:00",
            quietHoursEnd: "07:00:00"
        )

        let schedules = scheduler.buildSchedules(habits: habits, todos: todos, preferences: preferences)
        guard schedules.count == 2 else {
            throw CheckError("expected habit and todo local schedules")
        }

        var habitOnlyPreferences = preferences
        habitOnlyPreferences.notificationFlags["todo_reminders"] = false
        let habitOnly = scheduler.buildSchedules(habits: habits, todos: todos, preferences: habitOnlyPreferences)
        guard habitOnly.count == 1, habitOnly.first?.id == "habit:h1" else {
            throw CheckError("expected todo reminder disable flag to suppress todo schedules")
        }

        let blocked = scheduler.dueReminders(
            schedules: schedules,
            nowHour: 6,
            nowMinute: 30,
            quietStart: preferences.quietHoursStart,
            quietEnd: preferences.quietHoursEnd
        )
        guard blocked.isEmpty else {
            throw CheckError("expected quiet-hours reminder suppression")
        }
    }

    private static func checkTodayReorderPersistenceCall() async throws {
        let api = MockAPIClient()
        await api.setTodayResponse(
            TodayResponse(
                dateLocal: "2026-03-12",
                items: [
                    TodayItem(itemType: .todo, itemId: "t1", title: "Todo", categoryId: "c1", completed: false, sortBucket: 0, sortScore: 80),
                    TodayItem(itemType: .habit, itemId: "h1", title: "Habit", categoryId: "c1", completed: false, sortBucket: 2, sortScore: 50),
                ],
                completedCount: 0,
                totalCount: 2,
                completionRatio: 0
            )
        )

        let queue = InMemorySyncQueue()
        let repo = DefaultTodayRepository(apiClient: api, syncQueue: queue)
        _ = try await repo.loadToday(date: "2026-03-12")
        let reordered = try await repo.reorder(
            dateLocal: "2026-03-12",
            items: [
                TodayOrderItem(itemType: .habit, itemId: "h1", orderIndex: 0),
                TodayOrderItem(itemType: .todo, itemId: "t1", orderIndex: 1),
            ]
        )
        guard reordered.items.first?.itemId == "h1" else {
            throw CheckError("expected reordered list to place habit first")
        }
    }

    private static func checkReflectionsUpsertAndList() async throws {
        let api = MockAPIClient()
        let repo = DefaultReflectionsRepository(apiClient: api)
        _ = try await repo.upsert(
            input: ReflectionWriteInput(
                periodType: .weekly,
                periodStart: "2026-03-09",
                periodEnd: "2026-03-15",
                content: "Wins and misses",
                sentiment: .focused
            )
        )
        let weekly = try await repo.list(periodType: .weekly)
        guard weekly.count == 1 else {
            throw CheckError("expected reflection upsert/list to return one note")
        }
    }

    private static func checkServerTimestampWins() async throws {
        let api = MockAPIClient()
        let newer = Date()
        let stale = newer.addingTimeInterval(-120)
        await api.setTodos(["t1": Todo(id: "t1", categoryId: "c1", title: "Server", updatedAt: newer)])
        let result = try await api.patchTodo(id: "t1", fields: ["title": "Stale"], clientUpdatedAt: stale)
        guard result.title == "Server" else {
            throw CheckError("expected server timestamp wins behavior")
        }
    }

    private static func checkHTTPAPIClientMappingAndUnauthorizedHandoff() async throws {
        let transport = ScriptedTransport()
        let sessionStore = InMemoryAuthSessionStore(
            session: AuthSessionTokens(
                accessToken: "token",
                refreshToken: "refresh",
                expiresAt: Date().addingTimeInterval(3600)
            )
        )
        let api = HTTPAPIClient(
            baseURL: URL(string: "http://localhost:8000")!,
            transport: transport,
            sessionStore: sessionStore
        )

        let today = try await api.fetchToday(date: "2026-03-12")
        guard today.items.count == 1, today.items[0].itemType == .habit else {
            throw CheckError("expected snake_case today payload to map to domain model")
        }

        do {
            _ = try await api.fetchPreferences()
            throw CheckError("expected unauthorized preferences call")
        } catch APIError.unauthorized {
            let cleared = await sessionStore.read()
            guard cleared == nil else {
                throw CheckError("expected session to clear after 401")
            }
        }
    }

    private static func checkSyncQueueRetryBehavior() async throws {
        let flaky = FlakyCompletionAPIClient()
        let queue = InMemorySyncQueue()
        let repo = DefaultTodayRepository(apiClient: flaky, syncQueue: queue)

        _ = try await repo.loadToday(date: "2026-03-12")
        _ = try await repo.setCompletion(itemType: .habit, itemId: "h1", dateLocal: "2026-03-12", state: .completed)

        let firstPending = await queue.all()
        guard firstPending.count == 1 else {
            throw CheckError("expected one queued mutation after first transient failure")
        }

        await queue.drain(using: flaky)
        let pending = await queue.all()
        guard pending.isEmpty else {
            throw CheckError("expected queued mutation to flush after retry")
        }
    }

    private static func checkViewModelsFlow() async throws {
        let api = MockAPIClient()
        await api.setTodayResponse(
            TodayResponse(
                dateLocal: "2026-03-12",
                items: [TodayItem(itemType: .habit, itemId: "h1", title: "Workout", categoryId: "c1", completed: false, sortBucket: 2, sortScore: 50)],
                completedCount: 0,
                totalCount: 1,
                completionRatio: 0
            )
        )
        let syncQueue = InMemorySyncQueue()

        let authVM = await MainActor.run {
            AuthViewModel(repository: DefaultAuthRepository(apiClient: api))
        }
        await authVM.login(email: "vm@example.com", password: "password123")
        guard await MainActor.run(body: { authVM.user != nil }) else {
            throw CheckError("expected AuthViewModel login to set user")
        }

        let todayVM = await MainActor.run {
            TodayViewModel(repository: DefaultTodayRepository(apiClient: api, syncQueue: syncQueue))
        }
        await todayVM.load(date: "2026-03-12")
        guard let first = await MainActor.run(body: { todayVM.items.first }) else {
            throw CheckError("expected TodayViewModel to load items")
        }
        await todayVM.toggle(item: first, dateLocal: "2026-03-12")
        let ratio = await MainActor.run(body: { todayVM.completionRatio })
        guard ratio == 1 else {
            throw CheckError("expected TodayViewModel toggle to update completion ratio")
        }
    }

    private static func makeDate(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value) ?? Date()
    }
}

struct CheckError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}

private actor ScriptedTransport: HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        guard let url = request.url else {
            throw APIError.transport("Missing URL")
        }
        switch url.path {
        case "/today":
            let body = """
            {
              "date_local": "2026-03-12",
              "items": [
                {
                  "item_type": "habit",
                  "item_id": "h1",
                  "title": "Workout",
                  "category_id": "c1",
                  "completed": false,
                  "sort_bucket": 2,
                  "sort_score": 50
                },
                {
                  "item_type": "habit",
                  "item_id": "h1",
                  "title": "Workout duplicate",
                  "category_id": "c1",
                  "completed": false,
                  "sort_bucket": 3,
                  "sort_score": 10
                }
              ],
              "completed_count": 0,
              "total_count": 2,
              "completion_ratio": 0
            }
            """
            return try makeResponse(url: url, statusCode: 200, body: body)
        case "/preferences":
            let body = #"{"detail":"Missing bearer token"}"#
            return try makeResponse(url: url, statusCode: 401, body: body)
        default:
            return try makeResponse(url: url, statusCode: 404, body: #"{"detail":"not found"}"#)
        }
    }

    private func makeResponse(url: URL, statusCode: Int, body: String) throws -> (Data, HTTPURLResponse) {
        let data = Data(body.utf8)
        guard let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: [:]) else {
            throw APIError.transport("Unable to create response")
        }
        return (data, response)
    }
}

private actor FlakyCompletionAPIClient: APIClient {
    private var session: AuthSessionTokens? = AuthSessionTokens(
        accessToken: "token",
        refreshToken: "refresh",
        expiresAt: Date().addingTimeInterval(3600)
    )
    private var remainingFailures = 1
    private var today = TodayResponse(
        dateLocal: "2026-03-12",
        items: [
            TodayItem(
                itemType: .habit,
                itemId: "h1",
                title: "Workout",
                categoryId: "c1",
                completed: false,
                sortBucket: 2,
                sortScore: 50
            )
        ],
        completedCount: 0,
        totalCount: 1,
        completionRatio: 0
    )

    func currentSession() async -> AuthSessionTokens? { session }
    func clearSession() async { session = nil }
    func login(email: String, password: String) async throws -> AuthSession { throw APIError.transport("unused") }
    func signup(email: String, password: String, displayName: String, timezone: String) async throws -> AuthSession { throw APIError.transport("unused") }
    func fetchMe() async throws -> User { throw APIError.transport("unused") }
    func fetchCategories() async throws -> [OneClient.Category] { throw APIError.transport("unused") }
    func fetchHabits() async throws -> [Habit] { throw APIError.transport("unused") }
    func fetchTodos() async throws -> [Todo] { throw APIError.transport("unused") }
    func fetchCoachCards() async throws -> [CoachCard] { throw APIError.transport("unused") }
    func createHabit(input: HabitCreateInput) async throws -> Habit { throw APIError.transport("unused") }
    func createTodo(input: TodoCreateInput) async throws -> Todo { throw APIError.transport("unused") }
    func fetchToday(date: String?) async throws -> TodayResponse { today }
    func putTodayOrder(dateLocal: String, items: [TodayOrderItem]) async throws -> TodayResponse { today }
    func fetchDaily(startDate: String, endDate: String) async throws -> [DailySummary] { throw APIError.transport("unused") }
    func fetchPeriod(anchorDate: String, periodType: PeriodType) async throws -> PeriodSummary { throw APIError.transport("unused") }
    func fetchHabitStats(habitId: String, anchorDate: String?, windowDays: Int?) async throws -> HabitStats { throw APIError.transport("unused") }
    func fetchReflections(periodType: PeriodType?) async throws -> [ReflectionNote] { throw APIError.transport("unused") }
    func upsertReflection(input: ReflectionWriteInput) async throws -> ReflectionNote { throw APIError.transport("unused") }
    func deleteReflection(id: String) async throws { throw APIError.transport("unused") }
    func fetchPreferences() async throws -> UserPreferences { throw APIError.transport("unused") }
    func patchPreferences(input: UserPreferencesUpdateInput) async throws -> UserPreferences { throw APIError.transport("unused") }
    func patchUser(input: UserProfileUpdateInput) async throws -> User { throw APIError.transport("unused") }
    func patchHabit(id: String, input: HabitUpdateInput, clientUpdatedAt: Date?) async throws -> Habit { throw APIError.transport("unused") }
    func patchTodo(id: String, fields: [String: String], clientUpdatedAt: Date?) async throws -> Todo { throw APIError.transport("unused") }
    func patchTodo(id: String, input: TodoUpdateInput, clientUpdatedAt: Date?) async throws -> Todo { throw APIError.transport("unused") }
    func deleteHabit(id: String) async throws {}
    func deleteTodo(id: String) async throws {}

    func updateCompletion(itemType: ItemType, itemId: String, dateLocal: String, state: CompletionState) async throws {
        if remainingFailures > 0 {
            remainingFailures -= 1
            throw APIError.transport("transient failure")
        }

        let completed = state == .completed
        today = TodayResponse(
            dateLocal: dateLocal,
            items: [
                TodayItem(
                    itemType: itemType,
                    itemId: itemId,
                    title: "Workout",
                    categoryId: "c1",
                    completed: completed,
                    sortBucket: 2,
                    sortScore: 50
                )
            ],
            completedCount: completed ? 1 : 0,
            totalCount: 1,
            completionRatio: completed ? 1 : 0
        )
    }
}
