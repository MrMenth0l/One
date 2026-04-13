import Foundation

#if canImport(SwiftData)
import SwiftData

public struct OneWidgetQueueMaterializer {
    public init() {}

    public func makePayload(referenceDate: Date = Date()) throws -> OneWidgetSnapshotPayload {
        let container = try OneSharedPersistenceStore.makeContainer(inMemory: false)
        return try makePayload(container: container, referenceDate: referenceDate)
    }

    public func makePayload(
        container: ModelContainer,
        referenceDate: Date = Date()
    ) throws -> OneWidgetSnapshotPayload {
        let context = ModelContext(container)

        guard let user = try activeUsers(in: context).first.map(mapUser) else {
            return .signedOut(generatedAt: referenceDate)
        }

        let categories = try activeCategories(in: context, userID: user.id).map(mapCategory)
        let habits = try activeHabits(in: context, userID: user.id).map(mapHabit)
        let todos = try activeTodos(in: context, userID: user.id).map(mapTodo)
        let completionLogs = try activeCompletionLogs(in: context, userID: user.id).map(mapCompletionLog)
        let overrides = try activeOverrides(in: context, userID: user.id).map(mapOverride)

        let targetDate = OfflineDateCoding.localDateString(
            from: referenceDate,
            timezoneID: user.timezone
        )
        let materialized = LocalTodayService().materialize(
            user: user,
            targetDate: targetDate,
            categories: categories,
            habits: habits,
            todos: todos,
            completionLogs: completionLogs,
            overrides: overrides
        )
        let categoryLookup = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        let queueItems = materialized.response.items
            .filter { !$0.completed && $0.surfaceZone == .flow }
            .map { item in
                let category = categoryLookup[item.categoryId]
                return OneWidgetQueueItem(
                    itemType: item.itemType,
                    itemId: item.itemId,
                    dateLocal: materialized.response.dateLocal,
                    title: item.title,
                    subtitle: item.subtitle,
                    categoryName: category?.name ?? "Category",
                    categoryIcon: category?.oneIconKey ?? .categoryGeneric,
                    urgency: item.urgency,
                    timeBucket: item.timeBucket,
                    isPinned: item.isPinned ?? false
                )
            }

        return .ready(
            todayQueue: OneWidgetQueueSnapshot(
                dateLocal: materialized.response.dateLocal,
                items: queueItems,
                completedCount: materialized.response.completedCount,
                totalCount: materialized.response.totalCount,
                isConfigured: true
            ),
            generatedAt: referenceDate
        )
    }

    private func activeUsers(in context: ModelContext) throws -> [LocalUserEntity] {
        try context.fetch(FetchDescriptor<LocalUserEntity>())
            .filter { $0.deletedAt == nil }
            .sorted {
                if $0.updatedAt != $1.updatedAt {
                    return $0.updatedAt > $1.updatedAt
                }
                return $0.createdAt > $1.createdAt
            }
    }

    private func activeCategories(in context: ModelContext, userID: String) throws -> [LocalCategoryEntity] {
        try context.fetch(FetchDescriptor<LocalCategoryEntity>())
            .filter { $0.deletedAt == nil && $0.userId == userID }
    }

    private func activeHabits(in context: ModelContext, userID: String) throws -> [LocalHabitEntity] {
        try context.fetch(FetchDescriptor<LocalHabitEntity>())
            .filter { $0.deletedAt == nil && $0.userId == userID }
    }

    private func activeTodos(in context: ModelContext, userID: String) throws -> [LocalTodoEntity] {
        try context.fetch(FetchDescriptor<LocalTodoEntity>())
            .filter { $0.deletedAt == nil && $0.userId == userID }
    }

    private func activeCompletionLogs(in context: ModelContext, userID: String) throws -> [LocalCompletionLogEntity] {
        try context.fetch(FetchDescriptor<LocalCompletionLogEntity>())
            .filter { $0.deletedAt == nil && $0.userId == userID }
    }

    private func activeOverrides(in context: ModelContext, userID: String) throws -> [LocalTodayOrderOverrideEntity] {
        try context.fetch(FetchDescriptor<LocalTodayOrderOverrideEntity>())
            .filter { $0.userId == userID }
    }

    private func mapUser(_ entity: LocalUserEntity) -> User {
        User(
            id: entity.id,
            email: entity.email,
            appleSub: entity.appleSub,
            displayName: entity.displayName,
            timezone: entity.timezone,
            createdAt: entity.createdAt
        )
    }

    private func mapCategory(_ entity: LocalCategoryEntity) -> Category {
        Category(
            id: entity.id,
            userId: entity.userId,
            name: entity.name,
            icon: OneIconKey.normalizedTaskCategoryID(name: entity.name, storedIcon: entity.icon),
            color: entity.color,
            sortOrder: entity.sortOrder,
            isDefault: entity.isDefault,
            archivedAt: entity.archivedAt
        )
    }

    private func mapHabit(_ entity: LocalHabitEntity) -> Habit {
        Habit(
            id: entity.id,
            userId: entity.userId,
            categoryId: entity.categoryId,
            title: entity.title,
            notes: entity.notes,
            recurrenceRule: entity.recurrenceRule,
            startDate: entity.startDate,
            endDate: entity.endDate,
            priorityWeight: entity.priorityWeight,
            preferredTime: entity.preferredTime,
            isActive: entity.isActive
        )
    }

    private func mapTodo(_ entity: LocalTodoEntity) -> Todo {
        Todo(
            id: entity.id,
            userId: entity.userId,
            categoryId: entity.categoryId,
            title: entity.title,
            notes: entity.notes,
            dueAt: entity.dueAt,
            priority: entity.priority,
            isPinned: entity.isPinned,
            status: TodoStatus(rawValue: entity.status) ?? .open,
            completedAt: entity.completedAt,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt
        )
    }

    private func mapCompletionLog(_ entity: LocalCompletionLogEntity) -> CompletionLog {
        CompletionLog(
            id: entity.id,
            userId: entity.userId,
            itemType: ItemType(rawValue: entity.itemType) ?? .habit,
            itemId: entity.itemId,
            dateLocal: entity.dateLocal,
            state: CompletionState(rawValue: entity.state) ?? .notCompleted,
            completedAt: entity.completedAt,
            source: entity.source,
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt
        )
    }

    private func mapOverride(_ entity: LocalTodayOrderOverrideEntity) -> TodayOrderOverrideRecord {
        TodayOrderOverrideRecord(
            dateLocal: entity.dateLocal,
            itemType: ItemType(rawValue: entity.itemType) ?? .habit,
            itemId: entity.itemId,
            orderIndex: entity.orderIndex
        )
    }
}
#endif
