import Foundation

public enum PendingMutationKind: String, Codable, Sendable {
    case completionToggle = "completion_toggle"
    case todayReorder = "today_reorder"
    case habitPatch = "habit_patch"
    case habitDelete = "habit_delete"
    case todoPatch = "todo_patch"
    case todoDelete = "todo_delete"
}

public struct PendingMutationPayload: Codable, Sendable, Equatable {
    public var itemType: ItemType?
    public var itemId: String?
    public var dateLocal: String?
    public var state: CompletionState?
    public var orderItems: [TodayOrderItem]?
    public var habitId: String?
    public var todoId: String?
    public var habitUpdate: HabitUpdateInput?
    public var todoUpdate: TodoUpdateInput?
    public var clientUpdatedAt: Date?

    public init(
        itemType: ItemType? = nil,
        itemId: String? = nil,
        dateLocal: String? = nil,
        state: CompletionState? = nil,
        orderItems: [TodayOrderItem]? = nil,
        habitId: String? = nil,
        todoId: String? = nil,
        habitUpdate: HabitUpdateInput? = nil,
        todoUpdate: TodoUpdateInput? = nil,
        clientUpdatedAt: Date? = nil
    ) {
        self.itemType = itemType
        self.itemId = itemId
        self.dateLocal = dateLocal
        self.state = state
        self.orderItems = orderItems
        self.habitId = habitId
        self.todoId = todoId
        self.habitUpdate = habitUpdate
        self.todoUpdate = todoUpdate
        self.clientUpdatedAt = clientUpdatedAt
    }
}

public struct PendingMutation: Sendable, Equatable, Identifiable, Codable {
    public let id: UUID
    public let kind: PendingMutationKind
    public let payload: PendingMutationPayload

    public init(id: UUID = UUID(), kind: PendingMutationKind, payload: PendingMutationPayload) {
        self.id = id
        self.kind = kind
        self.payload = payload
    }

    public static func completionToggle(itemType: ItemType, itemId: String, dateLocal: String, state: CompletionState) -> PendingMutation {
        PendingMutation(
            kind: .completionToggle,
            payload: PendingMutationPayload(
                itemType: itemType,
                itemId: itemId,
                dateLocal: dateLocal,
                state: state
            )
        )
    }

    public static func todayReorder(dateLocal: String, items: [TodayOrderItem]) -> PendingMutation {
        PendingMutation(
            kind: .todayReorder,
            payload: PendingMutationPayload(
                dateLocal: dateLocal,
                orderItems: items
            )
        )
    }

    public static func habitPatch(id: String, input: HabitUpdateInput, clientUpdatedAt: Date?) -> PendingMutation {
        PendingMutation(
            kind: .habitPatch,
            payload: PendingMutationPayload(
                habitId: id,
                habitUpdate: input,
                clientUpdatedAt: clientUpdatedAt
            )
        )
    }

    public static func habitDelete(id: String) -> PendingMutation {
        PendingMutation(
            kind: .habitDelete,
            payload: PendingMutationPayload(habitId: id)
        )
    }

    public static func todoPatch(id: String, input: TodoUpdateInput, clientUpdatedAt: Date?) -> PendingMutation {
        PendingMutation(
            kind: .todoPatch,
            payload: PendingMutationPayload(
                todoId: id,
                todoUpdate: input,
                clientUpdatedAt: clientUpdatedAt
            )
        )
    }

    public static func todoDelete(id: String) -> PendingMutation {
        PendingMutation(
            kind: .todoDelete,
            payload: PendingMutationPayload(todoId: id)
        )
    }
}

public protocol SyncQueue: Sendable {
    func enqueue(_ mutation: PendingMutation) async
    func drain(using apiClient: APIClient) async
    func all() async -> [PendingMutation]
}

public actor InMemorySyncQueue: SyncQueue {
    private var queue: [PendingMutation] = []

    public init() {}

    public func enqueue(_ mutation: PendingMutation) async {
        queue.append(mutation)
    }

    public func all() async -> [PendingMutation] {
        queue
    }

    public func drain(using apiClient: APIClient) async {
        var remaining: [PendingMutation] = []
        for mutation in queue {
            do {
                try await mutation.apply(using: apiClient)
            } catch {
                remaining.append(mutation)
                if case APIError.unauthorized = error {
                    remaining.append(contentsOf: queue.drop(while: { $0.id != mutation.id }).dropFirst())
                    break
                }
            }
        }
        queue = remaining
    }
}

extension PendingMutation {
    func apply(using apiClient: APIClient) async throws {
        switch kind {
        case .completionToggle:
            guard let itemType = payload.itemType,
                  let itemId = payload.itemId,
                  let dateLocal = payload.dateLocal,
                  let state = payload.state else {
                return
            }
            try await apiClient.updateCompletion(itemType: itemType, itemId: itemId, dateLocal: dateLocal, state: state)
        case .todayReorder:
            guard let dateLocal = payload.dateLocal,
                  let orderItems = payload.orderItems else {
                return
            }
            _ = try await apiClient.putTodayOrder(dateLocal: dateLocal, items: orderItems)
        case .habitPatch:
            guard let habitId = payload.habitId,
                  let input = payload.habitUpdate else {
                return
            }
            _ = try await apiClient.patchHabit(id: habitId, input: input, clientUpdatedAt: payload.clientUpdatedAt)
        case .habitDelete:
            guard let habitId = payload.habitId else {
                return
            }
            try await apiClient.deleteHabit(id: habitId)
        case .todoPatch:
            guard let todoId = payload.todoId,
                  let input = payload.todoUpdate else {
                return
            }
            _ = try await apiClient.patchTodo(id: todoId, input: input, clientUpdatedAt: payload.clientUpdatedAt)
        case .todoDelete:
            guard let todoId = payload.todoId else {
                return
            }
            try await apiClient.deleteTodo(id: todoId)
        }
    }
}

public protocol AuthRepository: Sendable {
    func restoreSession() async -> User?
    func localProfileCandidate() async -> User?
    func login(email: String, password: String) async throws -> User
    func signup(email: String, password: String, displayName: String, timezone: String) async throws -> User
    func logout() async
}

protocol LocalProfileInspectable: Sendable {
    func persistedLocalUser() async -> User?
}

public struct DefaultAuthRepository: AuthRepository {
    private let apiClient: APIClient

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    public func restoreSession() async -> User? {
        guard await apiClient.currentSession() != nil else {
            return nil
        }
        do {
            return try await apiClient.fetchMe()
        } catch {
            await apiClient.clearSession()
            return nil
        }
    }

    public func localProfileCandidate() async -> User? {
        guard let inspectable = apiClient as? any LocalProfileInspectable else {
            return nil
        }
        return await inspectable.persistedLocalUser()
    }

    public func login(email: String, password: String) async throws -> User {
        let session = try await apiClient.login(email: email, password: password)
        return session.user
    }

    public func signup(email: String, password: String, displayName: String, timezone: String) async throws -> User {
        let session = try await apiClient.signup(
            email: email,
            password: password,
            displayName: displayName,
            timezone: timezone
        )
        return session.user
    }

    public func logout() async {
        await apiClient.clearSession()
    }
}

public protocol TasksRepository: Sendable {
    func loadCategories() async throws -> [Category]
    func loadHabits() async throws -> [Habit]
    func loadTodos() async throws -> [Todo]
    func createHabit(_ input: HabitCreateInput) async throws -> Habit
    func createTodo(_ input: TodoCreateInput) async throws -> Todo
    func updateHabit(id: String, input: HabitUpdateInput, clientUpdatedAt: Date?) async throws -> Habit
    func updateTodo(id: String, input: TodoUpdateInput, clientUpdatedAt: Date?) async throws -> Todo
    func deleteHabit(id: String) async throws
    func deleteTodo(id: String) async throws
    func loadHabitStats(habitId: String, anchorDate: String?, windowDays: Int?) async throws -> HabitStats
}

public struct DefaultTasksRepository: TasksRepository {
    private let apiClient: APIClient
    private let syncQueue: SyncQueue

    public init(apiClient: APIClient, syncQueue: SyncQueue) {
        self.apiClient = apiClient
        self.syncQueue = syncQueue
    }

    public func loadCategories() async throws -> [Category] {
        try await apiClient.fetchCategories()
    }

    public func loadHabits() async throws -> [Habit] {
        try await apiClient.fetchHabits()
    }

    public func loadTodos() async throws -> [Todo] {
        try await apiClient.fetchTodos()
    }

    public func createHabit(_ input: HabitCreateInput) async throws -> Habit {
        try await apiClient.createHabit(input: input)
    }

    public func createTodo(_ input: TodoCreateInput) async throws -> Todo {
        try await apiClient.createTodo(input: input)
    }

    public func updateHabit(id: String, input: HabitUpdateInput, clientUpdatedAt: Date?) async throws -> Habit {
        do {
            return try await apiClient.patchHabit(id: id, input: input, clientUpdatedAt: clientUpdatedAt)
        } catch {
            await syncQueue.enqueue(.habitPatch(id: id, input: input, clientUpdatedAt: clientUpdatedAt))
            throw error
        }
    }

    public func updateTodo(id: String, input: TodoUpdateInput, clientUpdatedAt: Date?) async throws -> Todo {
        do {
            return try await apiClient.patchTodo(id: id, input: input, clientUpdatedAt: clientUpdatedAt)
        } catch {
            await syncQueue.enqueue(.todoPatch(id: id, input: input, clientUpdatedAt: clientUpdatedAt))
            throw error
        }
    }

    public func deleteHabit(id: String) async throws {
        do {
            try await apiClient.deleteHabit(id: id)
        } catch {
            await syncQueue.enqueue(.habitDelete(id: id))
            throw error
        }
    }

    public func deleteTodo(id: String) async throws {
        do {
            try await apiClient.deleteTodo(id: id)
        } catch {
            await syncQueue.enqueue(.todoDelete(id: id))
            throw error
        }
    }

    public func loadHabitStats(habitId: String, anchorDate: String?, windowDays: Int?) async throws -> HabitStats {
        try await apiClient.fetchHabitStats(habitId: habitId, anchorDate: anchorDate, windowDays: windowDays)
    }
}

public protocol TodayRepository: Sendable {
    func loadToday(date: String?) async throws -> TodayResponse
    func setCompletion(itemType: ItemType, itemId: String, dateLocal: String, state: CompletionState) async throws -> TodayResponse
    func reorder(dateLocal: String, items: [TodayOrderItem]) async throws -> TodayResponse
}

public actor DefaultTodayRepository: TodayRepository {
    private let apiClient: APIClient
    private let syncQueue: SyncQueue
    private var cached: TodayResponse?

    public init(apiClient: APIClient, syncQueue: SyncQueue) {
        self.apiClient = apiClient
        self.syncQueue = syncQueue
    }

    public func loadToday(date: String?) async throws -> TodayResponse {
        let result = try await apiClient.fetchToday(date: date).normalized()
        cached = result
        return result
    }

    public func setCompletion(itemType: ItemType, itemId: String, dateLocal: String, state: CompletionState) async throws -> TodayResponse {
        if var current = cached {
            var items = current.items
            if let index = items.firstIndex(where: { $0.itemType == itemType && $0.itemId == itemId }) {
                items[index].completed = (state == .completed)
            }
            let completed = items.filter { $0.completed }.count
            current = TodayResponse(
                dateLocal: current.dateLocal,
                items: items,
                completedCount: completed,
                totalCount: items.count,
                completionRatio: items.isEmpty ? 0 : Double(completed) / Double(items.count)
            ).normalized()
            cached = current
        }

        await MainActor.run {
            OneSyncFeedbackCenter.shared.showSyncing(
                title: "Syncing today",
                message: "Updating your daily progress."
            )
        }
        await syncQueue.enqueue(.completionToggle(itemType: itemType, itemId: itemId, dateLocal: dateLocal, state: state))
        await syncQueue.drain(using: apiClient)

        do {
            let refreshed = try await apiClient.fetchToday(date: dateLocal).normalized()
            cached = refreshed
            await MainActor.run {
                OneSyncFeedbackCenter.shared.showSynced(
                    title: "Today updated",
                    message: "Your latest completion is synced."
                )
            }
            return refreshed
        } catch {
            let pending = await syncQueue.all()
            if !pending.isEmpty, let cached {
                await MainActor.run {
                    OneSyncFeedbackCenter.shared.showLocal(
                        title: "Saved locally",
                        message: "Today's change will sync when the connection returns."
                    )
                }
                return cached.normalized()
            }

            await MainActor.run {
                OneSyncFeedbackCenter.shared.showFailed(
                    title: "Sync issue",
                    message: "Today's change could not be confirmed."
                )
            }
            throw error
        }
    }

    public func reorder(dateLocal: String, items: [TodayOrderItem]) async throws -> TodayResponse {
        if let current = cached {
            cached = applyReorder(items: items, current: current)
        }

        await MainActor.run {
            OneSyncFeedbackCenter.shared.showSyncing(
                title: "Saving order",
                message: "Updating the action queue."
            )
        }
        await syncQueue.enqueue(.todayReorder(dateLocal: dateLocal, items: items))
        await syncQueue.drain(using: apiClient)

        do {
            let refreshed = try await apiClient.fetchToday(date: dateLocal).normalized()
            cached = refreshed
            await MainActor.run {
                OneSyncFeedbackCenter.shared.showSynced(
                    title: "Order saved",
                    message: "Your action queue is in sync."
                )
            }
            return refreshed
        } catch {
            let pending = await syncQueue.all()
            if !pending.isEmpty, let cached {
                await MainActor.run {
                    OneSyncFeedbackCenter.shared.showLocal(
                        title: "Order saved locally",
                        message: "The new order will sync when possible."
                    )
                }
                return cached.normalized()
            }

            await MainActor.run {
                OneSyncFeedbackCenter.shared.showFailed(
                    title: "Order not confirmed",
                    message: "The action queue could not be synced yet."
                )
            }
            throw error
        }
    }

    private func applyReorder(items: [TodayOrderItem], current: TodayResponse) -> TodayResponse {
        let lookup = current.items.reduce(into: [String: TodayItem]()) { partial, item in
            partial[item.id] = partial[item.id] ?? item
        }
        var ordered: [TodayItem] = []
        var seen: Set<String> = []
        for entry in items.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            let key = "\(entry.itemType.rawValue):\(entry.itemId)"
            guard let item = lookup[key] else {
                continue
            }
            ordered.append(item)
            seen.insert(key)
        }
        ordered.append(contentsOf: current.items.filter { !seen.contains($0.id) })
        let completed = ordered.filter(\.completed).count
        return TodayResponse(
            dateLocal: current.dateLocal,
            items: ordered,
            completedCount: completed,
            totalCount: ordered.count,
            completionRatio: ordered.isEmpty ? 0 : Double(completed) / Double(ordered.count)
        ).normalized()
    }
}

public protocol AnalyticsRepository: Sendable {
    func loadWeekly(anchorDate: String) async throws -> PeriodSummary
    func loadPeriod(anchorDate: String, periodType: PeriodType) async throws -> PeriodSummary
    func loadDaily(startDate: String, endDate: String) async throws -> [DailySummary]
}

public struct DefaultAnalyticsRepository: AnalyticsRepository {
    private let apiClient: APIClient

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    public func loadWeekly(anchorDate: String) async throws -> PeriodSummary {
        try await apiClient.fetchPeriod(anchorDate: anchorDate, periodType: .weekly)
    }

    public func loadPeriod(anchorDate: String, periodType: PeriodType) async throws -> PeriodSummary {
        try await apiClient.fetchPeriod(anchorDate: anchorDate, periodType: periodType)
    }

    public func loadDaily(startDate: String, endDate: String) async throws -> [DailySummary] {
        try await apiClient.fetchDaily(startDate: startDate, endDate: endDate)
    }
}

public protocol ReflectionsRepository: Sendable {
    func list(periodType: PeriodType?) async throws -> [ReflectionNote]
    func upsert(input: ReflectionWriteInput) async throws -> ReflectionNote
    func delete(id: String) async throws
}

public struct NoopReflectionsRepository: ReflectionsRepository {
    public init() {}

    public func list(periodType: PeriodType?) async throws -> [ReflectionNote] {
        []
    }

    public func upsert(input: ReflectionWriteInput) async throws -> ReflectionNote {
        throw APIError.transport("Reflections repository unavailable")
    }

    public func delete(id: String) async throws {
        throw APIError.transport("Reflections repository unavailable")
    }
}

public struct DefaultReflectionsRepository: ReflectionsRepository {
    private let apiClient: APIClient

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    public func list(periodType: PeriodType?) async throws -> [ReflectionNote] {
        try await apiClient.fetchReflections(periodType: periodType)
    }

    public func upsert(input: ReflectionWriteInput) async throws -> ReflectionNote {
        try await apiClient.upsertReflection(input: input)
    }

    public func delete(id: String) async throws {
        try await apiClient.deleteReflection(id: id)
    }
}

public protocol CoachRepository: Sendable {
    func loadCards() async throws -> [CoachCard]
}

public struct DefaultCoachRepository: CoachRepository {
    private let apiClient: APIClient

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    public func loadCards() async throws -> [CoachCard] {
        try await apiClient.fetchCoachCards()
    }
}

public protocol ProfileRepository: Sendable {
    func loadProfile() async throws -> User
    func updateProfile(_ input: UserProfileUpdateInput) async throws -> User
    func loadPreferences() async throws -> UserPreferences
    func updatePreferences(_ input: UserPreferencesUpdateInput) async throws -> UserPreferences
}

public struct DefaultProfileRepository: ProfileRepository {
    private let apiClient: APIClient

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    public func loadProfile() async throws -> User {
        try await apiClient.fetchMe()
    }

    public func updateProfile(_ input: UserProfileUpdateInput) async throws -> User {
        try await apiClient.patchUser(input: input)
    }

    public func loadPreferences() async throws -> UserPreferences {
        try await apiClient.fetchPreferences()
    }

    public func updatePreferences(_ input: UserPreferencesUpdateInput) async throws -> UserPreferences {
        try await apiClient.patchPreferences(input: input)
    }
}
