import Foundation
import Combine
import SwiftUI

private func userFacingError(_ error: Error) -> String {
    if let apiError = error as? APIError {
        switch apiError {
        case .unauthorized:
            return "Session ended on this device. Continue to resume your saved profile."
        case .transport:
            let environment = AppEnvironment.current()
            switch environment.runtimeMode {
            case .local:
                return "Local data store is unavailable. Restart the app and try again."
            case .remote:
                return "Backend unreachable at \(environment.apiBaseURL.absoluteString). Check API URL and network connection."
            }
        case .server(let statusCode, let message):
            return "Server error (\(statusCode)): \(message)"
        case .decoding:
            return "Received an unexpected response. Please update the app or try again."
        case .conflict:
            return "Data conflict detected. Reloading your latest data."
        }
    }
    return String(describing: error)
}

@MainActor
public final class AuthViewModel: ObservableObject {
    @Published public private(set) var user: User?
    @Published public private(set) var localProfileCandidate: User?
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?

    private let repository: AuthRepository

    public init(repository: AuthRepository) {
        self.repository = repository
    }

    public func bootstrap() async {
        isLoading = true
        defer { isLoading = false }
        user = await repository.restoreSession()
        localProfileCandidate = user == nil ? await repository.localProfileCandidate() : nil
        errorMessage = nil
    }

    public func login(email: String, password: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            user = try await repository.login(email: email, password: password)
            localProfileCandidate = nil
            errorMessage = nil
        } catch {
            errorMessage = userFacingError(error)
        }
    }

    public func signup(email: String, password: String, displayName: String, timezone: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            user = try await repository.signup(
                email: email,
                password: password,
                displayName: displayName,
                timezone: timezone
            )
            localProfileCandidate = nil
            errorMessage = nil
        } catch {
            errorMessage = userFacingError(error)
        }
    }

    public func createLocalProfile(displayName: String) async {
        let slug = displayName
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined(separator: "-")
            .split(separator: "-")
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        let localPart = slug.isEmpty ? "local-user" : slug
        await signup(
            email: "\(localPart)@one.local",
            password: "offline-local-profile",
            displayName: displayName,
            timezone: TimeZone.autoupdatingCurrent.identifier
        )
    }

    public func logout() async {
        await repository.logout()
        user = nil
        localProfileCandidate = await repository.localProfileCandidate()
        errorMessage = nil
    }

    public func resumeLocalProfile() async {
        isLoading = true
        defer { isLoading = false }
        if let candidate = await repository.localProfileCandidate() {
            do {
                user = try await repository.login(email: candidate.email, password: "")
                localProfileCandidate = nil
                errorMessage = nil
            } catch {
                user = nil
                localProfileCandidate = await repository.localProfileCandidate()
                errorMessage = userFacingError(error)
            }
            return
        }

        user = await repository.restoreSession()
        localProfileCandidate = user == nil ? await repository.localProfileCandidate() : nil
        errorMessage = user == nil ? "Unable to resume your saved profile." : nil
    }
}

@MainActor
public protocol NotificationScheduleRefresher {
    func refreshSchedules() async
}

@MainActor
public struct NoopNotificationScheduleRefresher: NotificationScheduleRefresher {
    public init() {}

    public func refreshSchedules() async {}
}

@MainActor
public final class TasksViewModel: ObservableObject {
    @Published public private(set) var categories: [Category] = []
    @Published public private(set) var habits: [Habit] = []
    @Published public private(set) var todos: [Todo] = []
    @Published public private(set) var errorMessage: String?

    private let repository: TasksRepository
    private let scheduleRefresher: NotificationScheduleRefresher
    private let onWidgetDataChanged: @MainActor () async -> Void

    public init(
        repository: TasksRepository,
        scheduleRefresher: NotificationScheduleRefresher = NoopNotificationScheduleRefresher(),
        onWidgetDataChanged: @escaping @MainActor () async -> Void = {}
    ) {
        self.repository = repository
        self.scheduleRefresher = scheduleRefresher
        self.onWidgetDataChanged = onWidgetDataChanged
    }

    public func loadCategories() async {
        do {
            let loadedCategories = try await repository.loadCategories()
            withAnimation(OneMotion.animation(.calmRefresh)) {
                categories = loadedCategories
            }
            errorMessage = nil
        } catch {
            OneHaptics.shared.trigger(.saveFailed)
            errorMessage = userFacingError(error)
        }
    }

    public func loadTasks() async {
        do {
            async let loadedHabits = repository.loadHabits()
            async let loadedTodos = repository.loadTodos()
            let nextHabits = try await loadedHabits
            let nextTodos = try await loadedTodos
            withAnimation(OneMotion.animation(.calmRefresh)) {
                habits = nextHabits
                todos = nextTodos
            }
            errorMessage = nil
        } catch {
            OneHaptics.shared.trigger(.saveFailed)
            errorMessage = userFacingError(error)
        }
    }

    public func createHabit(input: HabitCreateInput) async -> Habit? {
        do {
            let created = try await repository.createHabit(input)
            withAnimation(OneMotion.animation(.stateChange)) {
                habits.append(created)
            }
            await scheduleRefresher.refreshSchedules()
            OneHaptics.shared.trigger(.saveSucceeded)
            OneSyncFeedbackCenter.shared.showSynced(
                title: "Habit added",
                message: "\(created.title) is ready for Today."
            )
            await onWidgetDataChanged()
            errorMessage = nil
            return created
        } catch {
            OneHaptics.shared.trigger(.saveFailed)
            errorMessage = userFacingError(error)
            return nil
        }
    }

    public func createTodo(input: TodoCreateInput) async -> Todo? {
        do {
            let created = try await repository.createTodo(input)
            withAnimation(OneMotion.animation(.stateChange)) {
                todos.append(created)
            }
            await scheduleRefresher.refreshSchedules()
            OneHaptics.shared.trigger(.saveSucceeded)
            OneSyncFeedbackCenter.shared.showSynced(
                title: "Task added",
                message: "\(created.title) was added to your queue."
            )
            await onWidgetDataChanged()
            errorMessage = nil
            return created
        } catch {
            OneHaptics.shared.trigger(.saveFailed)
            errorMessage = userFacingError(error)
            return nil
        }
    }

    public func updateHabit(id: String, input: HabitUpdateInput) async -> Habit? {
        do {
            let updated = try await repository.updateHabit(id: id, input: input, clientUpdatedAt: Date())
            if let index = habits.firstIndex(where: { $0.id == id }) {
                withAnimation(OneMotion.animation(.stateChange)) {
                    habits[index] = updated
                }
            }
            await scheduleRefresher.refreshSchedules()
            OneHaptics.shared.trigger(.saveSucceeded)
            OneSyncFeedbackCenter.shared.showSynced(
                title: "Habit saved",
                message: "\(updated.title) stays aligned with Today."
            )
            await onWidgetDataChanged()
            errorMessage = nil
            return updated
        } catch {
            OneHaptics.shared.trigger(.saveFailed)
            errorMessage = userFacingError(error)
            return nil
        }
    }

    public func updateTodo(id: String, input: TodoUpdateInput) async -> Todo? {
        do {
            let updated = try await repository.updateTodo(id: id, input: input, clientUpdatedAt: Date())
            if let index = todos.firstIndex(where: { $0.id == id }) {
                withAnimation(OneMotion.animation(.stateChange)) {
                    todos[index] = updated
                }
            }
            await scheduleRefresher.refreshSchedules()
            OneHaptics.shared.trigger(.saveSucceeded)
            OneSyncFeedbackCenter.shared.showSynced(
                title: "Task saved",
                message: "\(updated.title) was updated."
            )
            await onWidgetDataChanged()
            errorMessage = nil
            return updated
        } catch {
            OneHaptics.shared.trigger(.saveFailed)
            errorMessage = userFacingError(error)
            return nil
        }
    }

    public func deleteHabit(id: String) async -> Bool {
        do {
            try await repository.deleteHabit(id: id)
            withAnimation(OneMotion.animation(.dismiss)) {
                habits.removeAll { $0.id == id }
            }
            await scheduleRefresher.refreshSchedules()
            OneHaptics.shared.trigger(.destructiveConfirmed)
            await onWidgetDataChanged()
            errorMessage = nil
            return true
        } catch {
            OneHaptics.shared.trigger(.saveFailed)
            errorMessage = userFacingError(error)
            return false
        }
    }

    public func deleteTodo(id: String) async -> Bool {
        do {
            try await repository.deleteTodo(id: id)
            withAnimation(OneMotion.animation(.dismiss)) {
                todos.removeAll { $0.id == id }
            }
            await scheduleRefresher.refreshSchedules()
            OneHaptics.shared.trigger(.destructiveConfirmed)
            await onWidgetDataChanged()
            errorMessage = nil
            return true
        } catch {
            OneHaptics.shared.trigger(.saveFailed)
            errorMessage = userFacingError(error)
            return false
        }
    }

    public func loadHabitStats(habitId: String, anchorDate: String? = nil, windowDays: Int? = nil) async -> HabitStats? {
        do {
            let stats = try await repository.loadHabitStats(habitId: habitId, anchorDate: anchorDate, windowDays: windowDays)
            errorMessage = nil
            return stats
        } catch {
            errorMessage = userFacingError(error)
            return nil
        }
    }
}

@MainActor
public final class TodayViewModel: ObservableObject {
    @Published public private(set) var dateLocal: String = ""
    @Published public private(set) var items: [TodayItem] = []
    @Published public private(set) var completedCount: Int = 0
    @Published public private(set) var totalCount: Int = 0
    @Published public private(set) var completionRatio: Double = 0
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var highlightedItemID: String?
    @Published public private(set) var milestoneCount = 0

    private let repository: TodayRepository
    private let onWidgetDataChanged: @MainActor () async -> Void

    public init(
        repository: TodayRepository,
        onWidgetDataChanged: @escaping @MainActor () async -> Void = {}
    ) {
        self.repository = repository
        self.onWidgetDataChanged = onWidgetDataChanged
    }

    public func load(date: String? = nil) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await repository.loadToday(date: date)
            withAnimation(OneMotion.animation(.calmRefresh)) {
                dateLocal = response.dateLocal
                items = response.items
                completedCount = response.completedCount
                totalCount = response.totalCount
                completionRatio = response.completionRatio
            }
            errorMessage = nil
        } catch {
            errorMessage = userFacingError(error)
        }
    }

    public func toggle(item: TodayItem, dateLocal: String) async {
        let next: CompletionState = item.completed ? .notCompleted : .completed
        do {
            let response = try await repository.setCompletion(
                itemType: item.itemType,
                itemId: item.itemId,
                dateLocal: dateLocal,
                state: next
            )
            withAnimation(OneMotion.animation(next == .completed ? .stateChange : .dismiss)) {
                self.items = response.items
                self.completedCount = response.completedCount
                self.totalCount = response.totalCount
                self.completionRatio = response.completionRatio
                self.highlightedItemID = item.id
            }

            let completedDay = next == .completed && response.totalCount > 0 && response.completedCount == response.totalCount
            OneHaptics.shared.trigger(completedDay ? .milestoneReached : .completionCommitted)
            if completedDay {
                milestoneCount += 1
            }
            await onWidgetDataChanged()
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.85))
                guard highlightedItemID == item.id else {
                    return
                }
                withAnimation(OneMotion.animation(.dismiss)) {
                    highlightedItemID = nil
                }
            }
            errorMessage = nil
        } catch {
            OneHaptics.shared.trigger(.saveFailed)
            errorMessage = userFacingError(error)
        }
    }

    public func reorder(items reordered: [TodayItem], dateLocal: String) async {
        let order = reordered.enumerated().map {
            TodayOrderItem(itemType: $0.element.itemType, itemId: $0.element.itemId, orderIndex: $0.offset)
        }
        do {
            let response = try await repository.reorder(dateLocal: dateLocal, items: order)
            withAnimation(OneMotion.animation(.reorder)) {
                self.items = response.items
                self.completedCount = response.completedCount
                self.totalCount = response.totalCount
                self.completionRatio = response.completionRatio
            }
            OneHaptics.shared.trigger(.reorderDrop)
            await onWidgetDataChanged()
            errorMessage = nil
        } catch {
            OneHaptics.shared.trigger(.saveFailed)
            errorMessage = userFacingError(error)
        }
    }

    public func highlight(itemType: ItemType, itemId: String) {
        let highlightID = "\(itemType.rawValue):\(itemId)"
        withAnimation(OneMotion.animation(.stateChange)) {
            highlightedItemID = highlightID
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            guard highlightedItemID == highlightID else {
                return
            }
            withAnimation(OneMotion.animation(.dismiss)) {
                highlightedItemID = nil
            }
        }
    }
}

public struct NotesDayOption: Sendable, Equatable, Identifiable {
    public let dateLocal: String
    public let weekdayLabel: String
    public let dayNumber: Int
    public let sentiment: ReflectionSentiment?
    public let hasNotes: Bool

    public var id: String { dateLocal }
}

public struct NotesMonthOption: Sendable, Equatable, Identifiable {
    public let month: Int
    public let label: String
    public let noteCount: Int
    public let dominant: ReflectionSentiment?

    public var id: Int { month }
}

public struct NotesSentimentSummary: Sendable, Equatable {
    public let noteCount: Int
    public let activeDays: Int
    public let dominant: ReflectionSentiment?
    public let distribution: [AnalyticsSentimentDistributionItem]
}

public enum NotesIntelligenceLens: String, CaseIterable, Sendable, Identifiable {
    case emotion
    case themes
    case behavior
    case timing
    case types

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .emotion:
            return "Emotion"
        case .themes:
            return "Themes"
        case .behavior:
            return "Behavior"
        case .timing:
            return "Timing"
        case .types:
            return "Types"
        }
    }
}

public enum NotesInferredType: String, CaseIterable, Sendable, Identifiable {
    case quickCapture = "quick_capture"
    case reflection
    case planning
    case idea

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .quickCapture:
            return "Quick Capture"
        case .reflection:
            return "Reflection"
        case .planning:
            return "Planning"
        case .idea:
            return "Idea"
        }
    }
}

public enum NotesTimeSegment: String, CaseIterable, Sendable, Identifiable {
    case early
    case morning
    case afternoon
    case evening
    case late

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .early:
            return "Early"
        case .morning:
            return "Morning"
        case .afternoon:
            return "Afternoon"
        case .evening:
            return "Evening"
        case .late:
            return "Late"
        }
    }
}

public struct NotesHeroPoint: Sendable, Equatable, Identifiable {
    public let id: String
    public let label: String
    public let detail: String
    public let rangeStart: String
    public let rangeEnd: String
    public let noteCount: Int
    public let dominant: ReflectionSentiment?
    public let sentimentBalance: Double
    public let volatility: Double
    public let clarity: Double
    public let averageWords: Int
    public let dominantType: NotesInferredType?
    public let completionRate: Double?
}

public struct NotesThemeCluster: Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let noteCount: Int
    public let supportingKeywords: [String]
    public let headline: String
    public let detail: String
    public let dominantSentiment: ReflectionSentiment?
}

public struct NotesTypeProfile: Sendable, Equatable, Identifiable {
    public let type: NotesInferredType
    public let noteCount: Int
    public let share: Double
    public let averageWords: Int
    public let dominantSentiment: ReflectionSentiment?
    public let headline: String
    public let detail: String

    public var id: NotesInferredType { type }
}

public struct NotesTimingProfile: Sendable, Equatable, Identifiable {
    public let segment: NotesTimeSegment
    public let noteCount: Int
    public let averageWords: Int
    public let averageClarity: Double
    public let averageSentiment: Double
    public let volatility: Double
    public let headline: String
    public let detail: String

    public var id: NotesTimeSegment { segment }
}

public struct NotesBehaviorMetric: Sendable, Equatable, Identifiable {
    public let title: String
    public let value: String
    public let detail: String

    public var id: String { title }
}

public struct NotesPatternShift: Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let detail: String
}

public struct NotesInsightStatement: Sendable, Equatable, Identifiable {
    public let id: String
    public let lens: NotesIntelligenceLens
    public let text: String
    public let confidence: Double
}

public struct NotesCrossDomainHook: Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let detail: String
}

public struct NotesIntelligenceSnapshot: Sendable, Equatable {
    public let heroTitle: String
    public let heroSubtitle: String
    public let heroDetail: String
    public let heroPoints: [NotesHeroPoint]
    public let themes: [NotesThemeCluster]
    public let types: [NotesTypeProfile]
    public let timing: [NotesTimingProfile]
    public let behaviorMetrics: [NotesBehaviorMetric]
    public let insights: [NotesInsightStatement]
    public let patternShifts: [NotesPatternShift]
    public let crossDomainHook: NotesCrossDomainHook?
}

private struct NotesAnalyzedNote: Sendable {
    let note: ReflectionNote
    let orderedTokens: [String]
    let keywords: [String]
    let phrases: [String]
    let wordCount: Int
    let clarity: Double
    let sentimentScore: Double
    let inferredType: NotesInferredType
    let timeSegment: NotesTimeSegment?
}

private struct NotesNoopAnalyticsRepository: AnalyticsRepository {
    func loadWeekly(anchorDate: String) async throws -> PeriodSummary {
        throw APIError.transport("Analytics repository unavailable")
    }

    func loadPeriod(anchorDate: String, periodType: PeriodType) async throws -> PeriodSummary {
        throw APIError.transport("Analytics repository unavailable")
    }

    func loadDaily(startDate: String, endDate: String) async throws -> [DailySummary] {
        throw APIError.transport("Analytics repository unavailable")
    }
}

public enum AnalyticsReviewRange: String, CaseIterable, Sendable {
    case week
    case month
    case quarter
    case year

    public var title: String {
        switch self {
        case .week:
            return "Week"
        case .month:
            return "Month"
        case .quarter:
            return "Quarter"
        case .year:
            return "Year"
        }
    }

    fileprivate var backingPeriodType: PeriodType {
        switch self {
        case .week:
            return .weekly
        case .month:
            return .monthly
        case .quarter, .year:
            return .yearly
        }
    }
}

public struct AnalyticsReliabilityHero: Sendable, Equatable {
    public let title: String
    public let narrative: String
    public let reliabilityScore: Double
    public let consistencyScore: Double
    public let keptCommitments: Int
    public let totalCommitments: Int
    public let missedCommitments: Int
    public let proofCount: Int
    public let proofLabel: String
}

public struct AnalyticsAccountabilityMark: Sendable, Equatable, Identifiable {
    public let dateLocal: String
    public let label: String
    public let shortLabel: String
    public let completedItems: Int
    public let expectedItems: Int
    public let missedItems: Int
    public let completionRate: Double
    public let isReliable: Bool

    public var id: String { dateLocal }
}

public struct AnalyticsReviewSlice: Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let completedItems: Int
    public let expectedItems: Int
    public let missedItems: Int
    public let reliability: Double
    public let consistency: Double
}

public struct AnalyticsLensComparisonCard: Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let completedItems: Int
    public let expectedItems: Int
    public let missedItems: Int
    public let reliability: Double
    public let reliableDays: Int
    public let commitmentDays: Int
}

public struct AnalyticsBreakdownCard: Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let metric: String
    public let detail: String
}

public struct AnalyticsInsightCard: Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let detail: String
}

private struct AnalyticsRawPeriodData: Sendable {
    let summary: PeriodSummary
    let dailySummaries: [DailySummary]
}

private struct AnalyticsPresentation: Sendable {
    let summary: PeriodSummary
    let dailySummaries: [DailySummary]
    let chartSeries: AnalyticsChartSeries
    let contributionSections: [AnalyticsContributionMonthSection]
    let monthWeekBuckets: [AnalyticsMonthWeekBucket]
    let executionRows: [AnalyticsExecutionSplitRow]
    let recoveryRows: [AnalyticsRecoveryRow]
    let hero: AnalyticsReliabilityHero
    let accountability: [AnalyticsAccountabilityMark]
    let reviewSlices: [AnalyticsReviewSlice]
    let lensCards: [AnalyticsLensComparisonCard]
    let breakdownCards: [AnalyticsBreakdownCard]
    let insightCards: [AnalyticsInsightCard]
}

private struct AnalyticsPeriodCacheKey: Hashable {
    let anchorDate: String
    let periodType: PeriodType
    let weekStart: Int
}

private struct AnalyticsPresentationCacheKey: Hashable {
    let periodKey: AnalyticsPeriodCacheKey
    let filter: AnalyticsActivityFilter
    let reviewRange: AnalyticsReviewRange
}

@MainActor
public final class AnalyticsViewModel: ObservableObject {
    @Published public var selectedPeriod: PeriodType = .weekly
    @Published public var selectedReviewRange: AnalyticsReviewRange = .week
    @Published public var selectedActivityFilter: AnalyticsActivityFilter = .all
    @Published public private(set) var pendingPeriod: PeriodType?
    @Published public private(set) var summary: PeriodSummary?
    @Published public private(set) var weekly: PeriodSummary?
    @Published public private(set) var dailySummaries: [DailySummary] = []
    @Published public private(set) var weeklyDailySummaries: [DailySummary] = []
    @Published public private(set) var chartSeries = AnalyticsChartSeries()
    @Published public private(set) var contributionSections: [AnalyticsContributionMonthSection] = []
    @Published public private(set) var monthWeekBuckets: [AnalyticsMonthWeekBucket] = []
    @Published public private(set) var selectedMonthWeek: Int?
    @Published public private(set) var sentimentOverview: AnalyticsSentimentOverview?
    @Published public private(set) var executionRows: [AnalyticsExecutionSplitRow] = []
    @Published public private(set) var recoveryRows: [AnalyticsRecoveryRow] = []
    @Published public private(set) var hero: AnalyticsReliabilityHero?
    @Published public private(set) var accountabilityMarks: [AnalyticsAccountabilityMark] = []
    @Published public private(set) var reviewSlices: [AnalyticsReviewSlice] = []
    @Published public private(set) var lensCards: [AnalyticsLensComparisonCard] = []
    @Published public private(set) var breakdownCards: [AnalyticsBreakdownCard] = []
    @Published public private(set) var insightCards: [AnalyticsInsightCard] = []
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var isTransitioning = false
    @Published public private(set) var isSwitchingPeriod = false

    private let repository: AnalyticsRepository
    private let reflectionsRepository: ReflectionsRepository
    private var rawPeriodCache: [AnalyticsPeriodCacheKey: AnalyticsRawPeriodData] = [:]
    private var presentationCache: [AnalyticsPresentationCacheKey: AnalyticsPresentation] = [:]
    private var currentPeriodKey: AnalyticsPeriodCacheKey?
    private var weeklyPeriodKey: AnalyticsPeriodCacheKey?
    private var rawDailyNotes: [ReflectionNote] = []
    private var activePeriodLoadTask: Task<(AnalyticsRawPeriodData, [ReflectionNote]), Error>?
    private var activePeriodLoadID = UUID()

    public init(
        repository: AnalyticsRepository,
        reflectionsRepository: ReflectionsRepository = NoopReflectionsRepository()
    ) {
        self.repository = repository
        self.reflectionsRepository = reflectionsRepository
    }

    public var selectedMonthWeekDetailLabel: String? {
        guard selectedReviewRange == .month,
              let selectedMonthWeek,
              let bucket = monthWeekBuckets.first(where: { $0.week == selectedMonthWeek }) else {
            return nil
        }
        return "\(bucket.title) · Days \(OneDate.dayNumber(from: bucket.startDate))-\(OneDate.dayNumber(from: bucket.endDate))"
    }

    public func selectActivityFilter(_ filter: AnalyticsActivityFilter) {
        withAnimation(OneMotion.animation(.stateChange)) {
            selectedActivityFilter = filter
            applyActivityFilter()
        }
        OneHaptics.shared.trigger(.selectionChanged)
    }

    public func selectReviewRange(
        _ range: AnalyticsReviewRange,
        anchorDate: String,
        weekStart: Int = 0
    ) async {
        let targetPeriod = range.backingPeriodType
        let targetKey = AnalyticsPeriodCacheKey(anchorDate: anchorDate, periodType: targetPeriod, weekStart: weekStart)

        await MainActor.run {
            selectedReviewRange = range
        }

        if currentPeriodKey == targetKey, rawPeriodCache[targetKey] != nil {
            await MainActor.run {
                applyActivityFilter()
            }
            OneHaptics.shared.trigger(.selectionChanged)
            return
        }

        await loadPeriod(anchorDate: anchorDate, periodType: targetPeriod, weekStart: weekStart)
    }

    public func selectMonthWeek(_ week: Int) {
        withAnimation(OneMotion.animation(.stateChange)) {
            selectedMonthWeek = week
            applyActivityFilter()
        }
        OneHaptics.shared.trigger(.selectionChanged)
    }

    public func loadWeekly(anchorDate: String, weekStart: Int = 0) async {
        let key = AnalyticsPeriodCacheKey(anchorDate: anchorDate, periodType: .weekly, weekStart: weekStart)
        isTransitioning = true
        defer { isTransitioning = false }
        do {
            let rawData: AnalyticsRawPeriodData
            if let cached = rawPeriodCache[key] {
                rawData = cached
            } else {
                let bounds = AnalyticsDateRange.bounds(anchorDate: anchorDate, periodType: .weekly, weekStart: weekStart)
                async let loadedSummary = repository.loadPeriod(anchorDate: anchorDate, periodType: .weekly)
                async let loadedDaily = repository.loadDaily(startDate: bounds.startDate, endDate: bounds.endDate)
                rawData = try await AnalyticsRawPeriodData(
                    summary: loadedSummary,
                    dailySummaries: loadedDaily
                )
                rawPeriodCache[key] = rawData
            }

            rawDailyNotes = try await reflectionsRepository.list(periodType: .daily)
            presentationCache = presentationCache.filter { $0.key.periodKey != key }
            weeklyPeriodKey = key
            let weeklyPresentation = presentation(for: rawData, key: key)
            withAnimation(OneMotion.animation(.calmRefresh)) {
                weeklyDailySummaries = weeklyPresentation.dailySummaries
                weekly = weeklyPresentation.summary
            }
            if selectedReviewRange == .week {
                currentPeriodKey = key
                applyPresentation(weeklyPresentation, key: key)
            }
            errorMessage = nil
        } catch {
            OneHaptics.shared.trigger(.saveFailed)
            errorMessage = userFacingError(error)
        }
    }

    public func loadPeriod(anchorDate: String, periodType: PeriodType, weekStart: Int = 0) async {
        let key = AnalyticsPeriodCacheKey(anchorDate: anchorDate, periodType: periodType, weekStart: weekStart)
        let cachedRawData = rawPeriodCache[key]
        let loadID = UUID()

        activePeriodLoadID = loadID
        activePeriodLoadTask?.cancel()
        pendingPeriod = periodType
        isSwitchingPeriod = true
        isTransitioning = true

        let repository = self.repository
        let reflectionsRepository = self.reflectionsRepository
        let task = Task<(AnalyticsRawPeriodData, [ReflectionNote]), Error> {
            let rawData: AnalyticsRawPeriodData
            if let cachedRawData {
                rawData = cachedRawData
            } else {
                let bounds = AnalyticsDateRange.bounds(anchorDate: anchorDate, periodType: periodType, weekStart: weekStart)
                async let loadedSummary = repository.loadPeriod(anchorDate: anchorDate, periodType: periodType)
                async let loadedDaily = repository.loadDaily(startDate: bounds.startDate, endDate: bounds.endDate)
                rawData = try await AnalyticsRawPeriodData(
                    summary: loadedSummary,
                    dailySummaries: loadedDaily
                )
            }

            let notes = try await reflectionsRepository.list(periodType: .daily)
            try Task.checkCancellation()
            return (rawData, notes)
        }

        activePeriodLoadTask = task

        do {
            let (rawData, notes) = try await task.value
            guard activePeriodLoadID == loadID else {
                return
            }

            if cachedRawData == nil {
                rawPeriodCache[key] = rawData
            }
            rawDailyNotes = notes
            presentationCache = presentationCache.filter { $0.key.periodKey != key }
            currentPeriodKey = key
            let currentPresentation = presentation(for: rawData, key: key)
            applyPresentation(currentPresentation, key: key, committedPeriod: periodType)
            if periodType == .weekly {
                weeklyPeriodKey = key
                let weeklyPresentation = presentation(for: rawData, key: key, reviewRange: .week)
                weeklyDailySummaries = weeklyPresentation.dailySummaries
                weekly = weeklyPresentation.summary
            }

            if periodType == selectedReviewRange.backingPeriodType {
                selectedPeriod = periodType
            }

            if periodType == .weekly, selectedReviewRange == .week {
                weekly = currentPresentation.summary
            } else if periodType == .weekly {
                weekly = currentPresentation.summary
            }

            pendingPeriod = nil
            isSwitchingPeriod = false
            isTransitioning = false
            OneHaptics.shared.trigger(.periodSwitched)
            errorMessage = nil
        } catch is CancellationError {
            guard activePeriodLoadID == loadID else {
                return
            }
            pendingPeriod = nil
            isSwitchingPeriod = false
            isTransitioning = false
        } catch {
            guard activePeriodLoadID == loadID else {
                return
            }
            pendingPeriod = nil
            isSwitchingPeriod = false
            isTransitioning = false
            OneHaptics.shared.trigger(.saveFailed)
            errorMessage = userFacingError(error)
        }
    }

    private func applyActivityFilter() {
        if let key = currentPeriodKey,
           let rawData = rawPeriodCache[key] {
            let currentPresentation = presentation(for: rawData, key: key)
            applyPresentation(currentPresentation, key: key)
        }

        if let weeklyPeriodKey,
           let rawData = rawPeriodCache[weeklyPeriodKey] {
            let weeklyPresentation = presentation(for: rawData, key: weeklyPeriodKey, reviewRange: .week)
            weeklyDailySummaries = weeklyPresentation.dailySummaries
            weekly = weeklyPresentation.summary
        }
    }

    private func presentation(
        for rawData: AnalyticsRawPeriodData,
        key: AnalyticsPeriodCacheKey,
        reviewRange: AnalyticsReviewRange? = nil
    ) -> AnalyticsPresentation {
        let activeRange = reviewRange ?? selectedReviewRange
        let cacheKey = AnalyticsPresentationCacheKey(periodKey: key, filter: selectedActivityFilter, reviewRange: activeRange)
        if let cached = presentationCache[cacheKey] {
            return cached
        }

        let rangeFiltered = summaries(for: rawData.dailySummaries, key: key, reviewRange: activeRange)
        let filtered = filteredSummaries(from: rangeFiltered)
        let summary = makeSummary(
            periodType: key.periodType,
            startDate: activeBounds(anchorDate: key.anchorDate, reviewRange: activeRange, weekStart: key.weekStart).startDate,
            endDate: activeBounds(anchorDate: key.anchorDate, reviewRange: activeRange, weekStart: key.weekStart).endDate,
            summaries: filtered
        )
        let lensCards = buildLensCards(from: rangeFiltered)
        let presentation = AnalyticsPresentation(
            summary: summary,
            dailySummaries: filtered,
            chartSeries: buildChartSeries(from: filtered, reviewRange: activeRange, weekStart: key.weekStart),
            contributionSections: buildContributionSections(from: filtered),
            monthWeekBuckets: buildMonthWeekBuckets(from: filtered),
            executionRows: buildExecutionRows(from: rangeFiltered),
            recoveryRows: buildRecoveryRows(from: filtered, reviewRange: activeRange, weekStart: key.weekStart),
            hero: buildHero(from: filtered, range: activeRange),
            accountability: buildAccountabilityMarks(from: filtered, range: activeRange),
            reviewSlices: buildReviewSlices(from: filtered, range: activeRange, weekStart: key.weekStart),
            lensCards: lensCards,
            breakdownCards: buildBreakdownCards(from: filtered, comparisonCards: lensCards, range: activeRange),
            insightCards: buildInsightCards(from: rangeFiltered, comparisonCards: lensCards, range: activeRange, weekStart: key.weekStart)
        )
        presentationCache[cacheKey] = presentation
        return presentation
    }

    private func applyPresentation(
        _ presentation: AnalyticsPresentation,
        key: AnalyticsPeriodCacheKey,
        committedPeriod: PeriodType? = nil
    ) {
        withAnimation(OneMotion.animation(.stateChange)) {
            if let committedPeriod {
                if selectedReviewRange.backingPeriodType == committedPeriod {
                    selectedPeriod = committedPeriod
                }
            }
            summary = presentation.summary
            chartSeries = presentation.chartSeries
            executionRows = presentation.executionRows
            recoveryRows = presentation.recoveryRows
            hero = presentation.hero
            accountabilityMarks = presentation.accountability
            reviewSlices = presentation.reviewSlices
            lensCards = presentation.lensCards
            breakdownCards = presentation.breakdownCards
            insightCards = presentation.insightCards

            switch selectedReviewRange {
            case .month:
                monthWeekBuckets = presentation.monthWeekBuckets
                let defaultWeek = monthSegment(for: key.anchorDate)
                if let selectedMonthWeek,
                   monthWeekBuckets.contains(where: { $0.week == selectedMonthWeek }) {
                    self.selectedMonthWeek = selectedMonthWeek
                } else {
                    self.selectedMonthWeek = monthWeekBuckets.first(where: { $0.week == defaultWeek })?.week ?? monthWeekBuckets.first?.week
                }
                dailySummaries = monthlyDetailSummaries(from: presentation.dailySummaries)
                contributionSections = []
                sentimentOverview = buildSentimentOverview(key: key)
            case .quarter, .year:
                monthWeekBuckets = []
                selectedMonthWeek = nil
                dailySummaries = presentation.dailySummaries
                contributionSections = presentation.contributionSections
                sentimentOverview = buildSentimentOverview(key: key)
            case .week:
                monthWeekBuckets = []
                selectedMonthWeek = nil
                dailySummaries = presentation.dailySummaries
                contributionSections = []
                sentimentOverview = buildSentimentOverview(key: key)
            }
        }
    }

    private func filteredSummaries(from summaries: [DailySummary]) -> [DailySummary] {
        guard selectedActivityFilter != .all else {
            return summaries
        }

        return summaries.map { summary in
            let completedItems: Int
            let expectedItems: Int
            switch selectedActivityFilter {
            case .all:
                completedItems = summary.completedItems
                expectedItems = summary.expectedItems
            case .habits:
                completedItems = summary.habitCompleted
                expectedItems = summary.habitExpected
            case .todos:
                completedItems = summary.todoCompleted
                expectedItems = summary.todoExpected
            }

            let completionRate = expectedItems == 0 ? 0 : Double(completedItems) / Double(expectedItems)
            return DailySummary(
                dateLocal: summary.dateLocal,
                completedItems: completedItems,
                expectedItems: expectedItems,
                completionRate: completionRate,
                habitCompleted: selectedActivityFilter == .todos ? 0 : summary.habitCompleted,
                habitExpected: selectedActivityFilter == .todos ? 0 : summary.habitExpected,
                todoCompleted: selectedActivityFilter == .habits ? 0 : summary.todoCompleted,
                todoExpected: selectedActivityFilter == .habits ? 0 : summary.todoExpected
            )
        }
    }

    private func summaries(
        for summaries: [DailySummary],
        key: AnalyticsPeriodCacheKey,
        reviewRange: AnalyticsReviewRange
    ) -> [DailySummary] {
        let bounds = activeBounds(anchorDate: key.anchorDate, reviewRange: reviewRange, weekStart: key.weekStart)
        return summaries
            .filter { $0.dateLocal >= bounds.startDate && $0.dateLocal <= bounds.endDate }
            .sorted { $0.dateLocal < $1.dateLocal }
    }

    private func activeBounds(
        anchorDate: String,
        reviewRange: AnalyticsReviewRange,
        weekStart: Int
    ) -> (startDate: String, endDate: String) {
        switch reviewRange {
        case .week:
            return AnalyticsDateRange.bounds(anchorDate: anchorDate, periodType: .weekly, weekStart: weekStart)
        case .month:
            return AnalyticsDateRange.bounds(anchorDate: anchorDate, periodType: .monthly, weekStart: weekStart)
        case .year:
            return AnalyticsDateRange.bounds(anchorDate: anchorDate, periodType: .yearly, weekStart: weekStart)
        case .quarter:
            guard let anchor = OneDate.calendarDate(for: anchorDate) else {
                return (anchorDate, anchorDate)
            }
            let month = OneDate.monthBucket(from: anchorDate)
            let quarterStartMonth = (((month - 1) / 3) * 3) + 1
            let year = OneDate.year(from: anchorDate) ?? 2026
            let calendar = OfflineDateCoding.canonicalCalendar
            let startDate = calendar.date(from: DateComponents(year: year, month: quarterStartMonth, day: 1)) ?? anchor
            let endBase = calendar.date(from: DateComponents(year: year, month: quarterStartMonth + 2, day: 1)) ?? anchor
            let endDate = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: endBase) ?? endBase
            return (AnalyticsDateRange.isoDate(startDate), AnalyticsDateRange.isoDate(endDate))
        }
    }

    private func reliableThreshold(for filter: AnalyticsActivityFilter = .all) -> Double {
        switch filter {
        case .all:
            return 0.8
        case .habits:
            return 0.85
        case .todos:
            return 0.75
        }
    }

    private func makeSummary(
        periodType: PeriodType,
        startDate: String,
        endDate: String,
        summaries: [DailySummary]
    ) -> PeriodSummary {
        let completedItems = summaries.reduce(0) { $0 + $1.completedItems }
        let expectedItems = summaries.reduce(0) { $0 + $1.expectedItems }
        let activeDays = summaries.filter { $0.completedItems > 0 }.count
        let commitmentDays = summaries.filter { $0.expectedItems > 0 }.count
        let reliableDays = summaries.filter { $0.expectedItems > 0 && $0.completionRate >= reliableThreshold(for: selectedActivityFilter) }.count
        let completionRate = expectedItems == 0 ? 0 : Double(completedItems) / Double(expectedItems)
        let consistencyScore = commitmentDays == 0 ? 0 : Double(reliableDays) / Double(commitmentDays)

        return PeriodSummary(
            periodType: periodType,
            periodStart: startDate,
            periodEnd: endDate,
            completedItems: completedItems,
            expectedItems: expectedItems,
            completionRate: completionRate,
            activeDays: activeDays,
            consistencyScore: consistencyScore
        )
    }

    private func buildChartSeries(
        from summaries: [DailySummary],
        reviewRange: AnalyticsReviewRange,
        weekStart: Int
    ) -> AnalyticsChartSeries {
        switch reviewRange {
        case .week:
            return AnalyticsChartSeries(
                values: summaries.map(\.completionRate),
                labels: summaries.map { OneDate.shortWeekday(from: $0.dateLocal) }
            )
        case .month, .quarter:
            let slices = buildReviewSlices(from: summaries, range: reviewRange, weekStart: weekStart)
            return AnalyticsChartSeries(
                values: slices.map(\.reliability),
                labels: slices.enumerated().map { "W\($0.offset + 1)" }
            )
        case .year:
            let grouped = Dictionary(grouping: summaries) { OneDate.monthBucket(from: $0.dateLocal) }
            return AnalyticsChartSeries(
                values: (1...12).map { month in
                    let entries = grouped[month] ?? []
                    let completed = Double(entries.reduce(0) { $0 + $1.completedItems })
                    let expected = Double(entries.reduce(0) { $0 + $1.expectedItems })
                    return expected == 0 ? 0 : completed / expected
                },
                labels: (1...12).map(OneDate.shortMonth(for:))
            )
        }
    }

    private func buildExecutionRows(from summaries: [DailySummary]) -> [AnalyticsExecutionSplitRow] {
        let habitCompleted = summaries.reduce(0) { $0 + $1.habitCompleted }
        let habitExpected = summaries.reduce(0) { $0 + $1.habitExpected }
        let todoCompleted = summaries.reduce(0) { $0 + $1.todoCompleted }
        let todoExpected = summaries.reduce(0) { $0 + $1.todoExpected }

        return [
            AnalyticsExecutionSplitRow(
                id: "habits",
                title: "Habits",
                completedItems: habitCompleted,
                expectedItems: habitExpected,
                completionRate: habitExpected == 0 ? 0 : Double(habitCompleted) / Double(habitExpected)
            ),
            AnalyticsExecutionSplitRow(
                id: "tasks",
                title: "Tasks",
                completedItems: todoCompleted,
                expectedItems: todoExpected,
                completionRate: todoExpected == 0 ? 0 : Double(todoCompleted) / Double(todoExpected)
            ),
        ]
    }

    private func buildRecoveryRows(
        from summaries: [DailySummary],
        reviewRange: AnalyticsReviewRange,
        weekStart: Int
    ) -> [AnalyticsRecoveryRow] {
        let rows: [AnalyticsRecoveryRow]

        switch reviewRange {
        case .week:
            rows = summaries.map {
                makeRecoveryRow(
                    id: $0.dateLocal,
                    label: OneDate.shortWeekday(from: $0.dateLocal),
                    completedItems: $0.completedItems,
                    expectedItems: $0.expectedItems
                )
            }
        case .month, .quarter:
            rows = buildReviewSlices(from: summaries, range: reviewRange, weekStart: weekStart).map { slice in
                return makeRecoveryRow(
                    id: slice.id,
                    label: slice.title,
                    completedItems: slice.completedItems,
                    expectedItems: slice.expectedItems
                )
            }
        case .year:
            let grouped = Dictionary(grouping: summaries) { OneDate.monthBucket(from: $0.dateLocal) }
            rows = grouped.keys.sorted().map { month in
                let entries = grouped[month] ?? []
                return makeRecoveryRow(
                    id: "month-\(month)",
                    label: OneDate.shortMonth(for: month),
                    completedItems: entries.reduce(0) { $0 + $1.completedItems },
                    expectedItems: entries.reduce(0) { $0 + $1.expectedItems }
                )
            }
        }

        return rows
            .filter { $0.expectedItems > 0 || $0.completedItems > 0 }
            .sorted { lhs, rhs in
                if lhs.gap != rhs.gap {
                    return lhs.gap > rhs.gap
                }
                if lhs.completionRate != rhs.completionRate {
                    return lhs.completionRate < rhs.completionRate
                }
                return lhs.label < rhs.label
            }
            .prefix(4)
            .map { $0 }
    }

    private func makeRecoveryRow(
        id: String,
        label: String,
        completedItems: Int,
        expectedItems: Int
    ) -> AnalyticsRecoveryRow {
        let gap = max(expectedItems - completedItems, 0)
        let completionRate = expectedItems == 0 ? 0 : Double(completedItems) / Double(expectedItems)
        return AnalyticsRecoveryRow(
            id: id,
            label: label,
            completedItems: completedItems,
            expectedItems: expectedItems,
            gap: gap,
            completionRate: completionRate
        )
    }

    private func buildHero(from summaries: [DailySummary], range: AnalyticsReviewRange) -> AnalyticsReliabilityHero {
        let keptCommitments = summaries.reduce(0) { $0 + $1.completedItems }
        let totalCommitments = summaries.reduce(0) { $0 + $1.expectedItems }
        let missedCommitments = max(totalCommitments - keptCommitments, 0)
        let commitmentDays = summaries.filter { $0.expectedItems > 0 }.count
        let reliableDays = summaries.filter { $0.expectedItems > 0 && $0.completionRate >= reliableThreshold(for: selectedActivityFilter) }.count
        let reliabilityScore = totalCommitments == 0 ? 0 : Double(keptCommitments) / Double(totalCommitments)
        let consistencyScore = commitmentDays == 0 ? 0 : Double(reliableDays) / Double(commitmentDays)
        let proofCount = currentReliableStreak(from: summaries)
        let proofLabel = range == .week ? "day streak" : "reliable span"

        let title: String
        let narrative: String
        if totalCommitments == 0 {
            title = "No commitments are visible yet"
            narrative = "Reliability starts once this range contains real promises to keep."
        } else if reliabilityScore >= 0.82 && consistencyScore >= 0.65 {
            title = "You are keeping promises with repeatability"
            narrative = "Follow-through is showing up often enough to feel structural, not accidental."
        } else if reliabilityScore >= 0.68 {
            title = "Reliability is present, but still uneven"
            narrative = "You are closing enough work to prove progress, but the misses are still visible."
        } else {
            title = "Too many commitments are breaking inside this range"
            narrative = "The screen is showing real gaps between what you planned and what you kept."
        }

        return AnalyticsReliabilityHero(
            title: title,
            narrative: narrative,
            reliabilityScore: reliabilityScore,
            consistencyScore: consistencyScore,
            keptCommitments: keptCommitments,
            totalCommitments: totalCommitments,
            missedCommitments: missedCommitments,
            proofCount: proofCount,
            proofLabel: proofLabel
        )
    }

    private func buildAccountabilityMarks(
        from summaries: [DailySummary],
        range: AnalyticsReviewRange
    ) -> [AnalyticsAccountabilityMark] {
        let visible: [DailySummary]
        switch range {
        case .week:
            visible = summaries
        case .month:
            visible = Array(summaries.suffix(31))
        case .quarter, .year:
            visible = Array(summaries.suffix(28))
        }

        return visible.map { summary in
            AnalyticsAccountabilityMark(
                dateLocal: summary.dateLocal,
                label: OneDate.shortMonthDay(from: summary.dateLocal),
                shortLabel: range == .week ? OneDate.shortWeekday(from: summary.dateLocal) : OneDate.dayNumber(from: summary.dateLocal),
                completedItems: summary.completedItems,
                expectedItems: summary.expectedItems,
                missedItems: max(summary.expectedItems - summary.completedItems, 0),
                completionRate: summary.completionRate,
                isReliable: summary.expectedItems > 0 && summary.completionRate >= reliableThreshold(for: selectedActivityFilter)
            )
        }
    }

    private func buildReviewSlices(
        from summaries: [DailySummary],
        range: AnalyticsReviewRange,
        weekStart: Int
    ) -> [AnalyticsReviewSlice] {
        switch range {
        case .week:
            return summaries.map { summary in
                let reliableDays = summary.expectedItems > 0 && summary.completionRate >= reliableThreshold(for: selectedActivityFilter) ? 1 : 0
                let commitmentDays = summary.expectedItems > 0 ? 1 : 0
                return AnalyticsReviewSlice(
                    id: summary.dateLocal,
                    title: OneDate.shortWeekday(from: summary.dateLocal),
                    subtitle: OneDate.shortMonthDay(from: summary.dateLocal),
                    completedItems: summary.completedItems,
                    expectedItems: summary.expectedItems,
                    missedItems: max(summary.expectedItems - summary.completedItems, 0),
                    reliability: summary.completionRate,
                    consistency: commitmentDays == 0 ? 0 : Double(reliableDays)
                )
            }
        case .month, .quarter:
            let grouped = Dictionary(grouping: summaries) { weekGroupKey(for: $0.dateLocal, weekStart: weekStart) }
            let sortedKeys = grouped.keys.sorted()
            return sortedKeys.enumerated().map { offset, key in
                let entries = (grouped[key] ?? []).sorted { $0.dateLocal < $1.dateLocal }
                return makeReviewSlice(
                    id: "week-\(offset + 1)-\(key)",
                    title: "Week \(offset + 1)",
                    subtitle: weekSubtitle(for: entries),
                    summaries: entries
                )
            }
        case .year:
            let grouped = Dictionary(grouping: summaries) { OneDate.monthBucket(from: $0.dateLocal) }
            return grouped.keys.sorted().map { month in
                let entries = (grouped[month] ?? []).sorted { $0.dateLocal < $1.dateLocal }
                return makeReviewSlice(
                    id: "month-\(month)",
                    title: OneDate.shortMonth(for: month),
                    subtitle: "\(entries.count) days",
                    summaries: entries
                )
            }
        }
    }

    private func makeReviewSlice(
        id: String,
        title: String,
        subtitle: String,
        summaries: [DailySummary]
    ) -> AnalyticsReviewSlice {
        let completedItems = summaries.reduce(0) { $0 + $1.completedItems }
        let expectedItems = summaries.reduce(0) { $0 + $1.expectedItems }
        let missedItems = max(expectedItems - completedItems, 0)
        let commitmentDays = summaries.filter { $0.expectedItems > 0 }.count
        let reliableDays = summaries.filter { $0.expectedItems > 0 && $0.completionRate >= reliableThreshold(for: selectedActivityFilter) }.count
        return AnalyticsReviewSlice(
            id: id,
            title: title,
            subtitle: subtitle,
            completedItems: completedItems,
            expectedItems: expectedItems,
            missedItems: missedItems,
            reliability: expectedItems == 0 ? 0 : Double(completedItems) / Double(expectedItems),
            consistency: commitmentDays == 0 ? 0 : Double(reliableDays) / Double(commitmentDays)
        )
    }

    private func buildLensCards(from summaries: [DailySummary]) -> [AnalyticsLensComparisonCard] {
        [
            makeLensCard(id: "all", title: "Combined", subtitle: "All commitments", summaries: summaries, filter: .all),
            makeLensCard(id: "habits", title: "Habits", subtitle: "Cadence and recurrence", summaries: summaries, filter: .habits),
            makeLensCard(id: "todos", title: "Tasks", subtitle: "Deadline-based work", summaries: summaries, filter: .todos),
        ]
    }

    private func makeLensCard(
        id: String,
        title: String,
        subtitle: String,
        summaries: [DailySummary],
        filter: AnalyticsActivityFilter
    ) -> AnalyticsLensComparisonCard {
        let filtered = apply(filter: filter, to: summaries)
        let completedItems = filtered.reduce(0) { $0 + $1.completedItems }
        let expectedItems = filtered.reduce(0) { $0 + $1.expectedItems }
        let commitmentDays = filtered.filter { $0.expectedItems > 0 }.count
        let reliableDays = filtered.filter { $0.expectedItems > 0 && $0.completionRate >= reliableThreshold(for: filter) }.count
        return AnalyticsLensComparisonCard(
            id: id,
            title: title,
            subtitle: subtitle,
            completedItems: completedItems,
            expectedItems: expectedItems,
            missedItems: max(expectedItems - completedItems, 0),
            reliability: expectedItems == 0 ? 0 : Double(completedItems) / Double(expectedItems),
            reliableDays: reliableDays,
            commitmentDays: commitmentDays
        )
    }

    private func buildBreakdownCards(
        from summaries: [DailySummary],
        comparisonCards: [AnalyticsLensComparisonCard],
        range: AnalyticsReviewRange
    ) -> [AnalyticsBreakdownCard] {
        let missedDays = summaries.filter { $0.expectedItems > 0 && $0.completedItems < $0.expectedItems }
        let keptDays = summaries.filter { $0.expectedItems > 0 && $0.completedItems >= $0.expectedItems }
        let longestCluster = longestSequence(in: summaries) { $0.expectedItems > 0 && $0.completedItems < $0.expectedItems }
        let missedAverage = missedDays.isEmpty ? 0 : Double(missedDays.reduce(0) { $0 + $1.expectedItems }) / Double(missedDays.count)
        let keptAverage = keptDays.isEmpty ? 0 : Double(keptDays.reduce(0) { $0 + $1.expectedItems }) / Double(keptDays.count)
        let habits = comparisonCards.first(where: { $0.id == "habits" })
        let tasks = comparisonCards.first(where: { $0.id == "todos" })
        let alignmentDelta = abs((habits?.reliability ?? 0) - (tasks?.reliability ?? 0))

        return [
            AnalyticsBreakdownCard(
                id: "missed",
                title: "Missed Commitments",
                metric: "\(summaries.reduce(0) { $0 + max($1.expectedItems - $1.completedItems, 0) })",
                detail: missedDays.isEmpty
                    ? "No missed commitments are recorded inside this \(range.title.lowercased())."
                    : "Misses are showing on \(missedDays.count) distinct day\(missedDays.count == 1 ? "" : "s"), so failures stay visible."
            ),
            AnalyticsBreakdownCard(
                id: "cluster",
                title: "Longest Slip",
                metric: "\(longestCluster) day\(longestCluster == 1 ? "" : "s")",
                detail: longestCluster == 0
                    ? "There is no consecutive miss cluster right now."
                    : "The longest uninterrupted break in follow-through lasted \(longestCluster) day\(longestCluster == 1 ? "" : "s")."
            ),
            AnalyticsBreakdownCard(
                id: "load",
                title: "Load Pressure",
                metric: keptAverage == 0 ? "0.0x" : String(format: "%.1fx", missedAverage / max(keptAverage, 1.0)),
                detail: missedAverage <= keptAverage
                    ? "Misses are not being driven mainly by larger commitment volume."
                    : "Follow-through weakens when the planned load rises from \(String(format: "%.1f", keptAverage)) to \(String(format: "%.1f", missedAverage)) items per day."
            ),
            AnalyticsBreakdownCard(
                id: "alignment",
                title: "Habits vs Tasks",
                metric: "\(Int((alignmentDelta * 100).rounded()))pt",
                detail: alignmentDelta < 0.08
                    ? "Habits and tasks are staying close enough to show aligned reliability."
                    : "One side of your commitments is carrying more of the trust signal than the other."
            ),
        ]
    }

    private func buildInsightCards(
        from combinedSummaries: [DailySummary],
        comparisonCards: [AnalyticsLensComparisonCard],
        range: AnalyticsReviewRange,
        weekStart: Int
    ) -> [AnalyticsInsightCard] {
        guard combinedSummaries.contains(where: { $0.expectedItems > 0 }) else {
            return []
        }

        var cards: [AnalyticsInsightCard] = []
        let habits = comparisonCards.first(where: { $0.id == "habits" })
        let tasks = comparisonCards.first(where: { $0.id == "todos" })
        let delta = (habits?.reliability ?? 0) - (tasks?.reliability ?? 0)
        if abs(delta) >= 0.12 {
            cards.append(
                AnalyticsInsightCard(
                    id: "lens-gap",
                    title: delta > 0 ? "Habits are carrying more of the reliability" : "Tasks are holding better than recurring work",
                    detail: delta > 0
                        ? "Recurring commitments are landing more often than one-off work, which means the trust signal is uneven across commitment types."
                        : "Deadline-based work is landing more often than your recurring promises, so identity work is lagging behind throughput."
                )
            )
        }

        let missedDays = combinedSummaries.filter { $0.expectedItems > 0 && $0.completedItems < $0.expectedItems }
        let keptDays = combinedSummaries.filter { $0.expectedItems > 0 && $0.completedItems >= $0.expectedItems }
        let missedAverage = missedDays.isEmpty ? 0 : Double(missedDays.reduce(0) { $0 + $1.expectedItems }) / Double(missedDays.count)
        let keptAverage = keptDays.isEmpty ? 0 : Double(keptDays.reduce(0) { $0 + $1.expectedItems }) / Double(keptDays.count)
        if missedAverage >= keptAverage + 1.0 {
            cards.append(
                AnalyticsInsightCard(
                    id: "load-spike",
                    title: "Commitment volume is outrunning follow-through",
                    detail: "Missed days are carrying about \(String(format: "%.1f", missedAverage)) planned items versus \(String(format: "%.1f", keptAverage)) on kept days, so scope is likely part of the break."
                )
            )
        }

        let lateWeekShare = lateWeekMissShare(from: combinedSummaries)
        if lateWeekShare >= 0.55 {
            cards.append(
                AnalyticsInsightCard(
                    id: "late-week",
                    title: "Misses are clustering late in the week",
                    detail: "More than half of the missed commitments are landing between Thursday and Sunday, which points to finish-line drop-off rather than random variance."
                )
            )
        }

        let slices = buildReviewSlices(from: apply(filter: selectedActivityFilter, to: combinedSummaries), range: range, weekStart: weekStart)
        if slices.count >= 4 {
            let midpoint = slices.count / 2
            let firstHalf = slices.prefix(midpoint).map(\.reliability)
            let secondHalf = slices.suffix(from: midpoint).map(\.reliability)
            let firstAverage = firstHalf.isEmpty ? 0 : firstHalf.reduce(0, +) / Double(firstHalf.count)
            let secondAverage = secondHalf.isEmpty ? 0 : secondHalf.reduce(0, +) / Double(secondHalf.count)
            if secondAverage >= firstAverage + 0.08 {
                cards.append(
                    AnalyticsInsightCard(
                        id: "tightening",
                        title: "Consistency is tightening as the range progresses",
                        detail: "The later part of the range is more reliable than the opening half, which is a stronger identity signal than a single burst."
                    )
                )
            } else if firstAverage >= secondAverage + 0.08 {
                cards.append(
                    AnalyticsInsightCard(
                        id: "fade",
                        title: "The range starts stronger than it finishes",
                        detail: "Follow-through is losing shape over time, so the issue looks more like sustainment than motivation."
                    )
                )
            }
        }

        return Array(cards.prefix(3))
    }

    private func currentReliableStreak(from summaries: [DailySummary]) -> Int {
        var streak = 0
        for summary in summaries.sorted(by: { $0.dateLocal > $1.dateLocal }) {
            guard summary.expectedItems > 0 else {
                continue
            }
            guard summary.completionRate >= reliableThreshold(for: selectedActivityFilter) else {
                break
            }
            streak += 1
        }
        return streak
    }

    private func longestSequence(in summaries: [DailySummary], matches: (DailySummary) -> Bool) -> Int {
        var longest = 0
        var current = 0
        for summary in summaries.sorted(by: { $0.dateLocal < $1.dateLocal }) {
            if matches(summary) {
                current += 1
                longest = max(longest, current)
            } else {
                current = 0
            }
        }
        return longest
    }

    private func lateWeekMissShare(from summaries: [DailySummary]) -> Double {
        let missedByDay = summaries.reduce(into: (late: 0, total: 0)) { partial, summary in
            let missedItems = max(summary.expectedItems - summary.completedItems, 0)
            guard missedItems > 0, let date = OneDate.calendarDate(for: summary.dateLocal) else {
                return
            }
            let weekday = OfflineDateCoding.canonicalCalendar.component(.weekday, from: date)
            let normalizedWeekday = (weekday + 5) % 7
            partial.total += missedItems
            if normalizedWeekday >= 3 {
                partial.late += missedItems
            }
        }
        guard missedByDay.total > 0 else {
            return 0
        }
        return Double(missedByDay.late) / Double(missedByDay.total)
    }

    private func weekGroupKey(for isoDateString: String, weekStart: Int) -> String {
        guard let date = OneDate.calendarDate(for: isoDateString) else {
            return isoDateString
        }
        let calendar = OfflineDateCoding.canonicalCalendar
        let weekday = calendar.component(.weekday, from: date)
        let normalizedWeekday = (weekday + 5) % 7
        let offset = (normalizedWeekday - weekStart + 7) % 7
        let start = calendar.date(byAdding: .day, value: -offset, to: date) ?? date
        return AnalyticsDateRange.isoDate(start)
    }

    private func weekSubtitle(for entries: [DailySummary]) -> String {
        guard let start = entries.first?.dateLocal,
              let end = entries.last?.dateLocal else {
            return "No signal"
        }
        return "\(OneDate.shortMonthDay(from: start))-\(OneDate.dayNumber(from: end))"
    }

    private func apply(filter: AnalyticsActivityFilter, to summaries: [DailySummary]) -> [DailySummary] {
        guard filter != .all else {
            return summaries
        }
        return summaries.map { summary in
            let completedItems = filter == .habits ? summary.habitCompleted : summary.todoCompleted
            let expectedItems = filter == .habits ? summary.habitExpected : summary.todoExpected
            return DailySummary(
                dateLocal: summary.dateLocal,
                completedItems: completedItems,
                expectedItems: expectedItems,
                completionRate: expectedItems == 0 ? 0 : Double(completedItems) / Double(expectedItems),
                habitCompleted: filter == .todos ? 0 : summary.habitCompleted,
                habitExpected: filter == .todos ? 0 : summary.habitExpected,
                todoCompleted: filter == .habits ? 0 : summary.todoCompleted,
                todoExpected: filter == .habits ? 0 : summary.todoExpected
            )
        }
    }

    private func buildMonthWeekBuckets(from summaries: [DailySummary]) -> [AnalyticsMonthWeekBucket] {
        guard let firstDate = summaries.first?.dateLocal,
              let year = OneDate.year(from: firstDate),
              let month = Optional(OneDate.monthBucket(from: firstDate)) else {
            return []
        }

        let daysInMonth = OneDate.numberOfDays(inMonth: month, year: year)
        let totalWeeks = max(1, ((daysInMonth - 1) / 7) + 1)
        let grouped = Dictionary(grouping: summaries) { monthSegment(for: $0.dateLocal) }

        return (1...totalWeeks).map { week in
            let entries = grouped[week] ?? []
            let completed = Double(entries.reduce(0) { $0 + $1.completedItems })
            let expected = Double(entries.reduce(0) { $0 + $1.expectedItems })
            let startDay = ((week - 1) * 7) + 1
            let endDay = min(startDay + 6, daysInMonth)
            return AnalyticsMonthWeekBucket(
                week: week,
                title: "Week \(week)",
                shortLabel: "W\(week)",
                completionRate: expected == 0 ? 0 : completed / expected,
                startDate: String(format: "%04d-%02d-%02d", year, month, startDay),
                endDate: String(format: "%04d-%02d-%02d", year, month, endDay)
            )
        }
    }

    private func buildContributionSections(from summaries: [DailySummary]) -> [AnalyticsContributionMonthSection] {
        let year = summaries.compactMap { OneDate.year(from: $0.dateLocal) }.first ?? OneDate.year(from: OneDate.isoDate()) ?? 2026
        return (1...12).map { month in
            let monthSummaries = summaries.filter { OneDate.monthBucket(from: $0.dateLocal) == month }
            let byDate = Dictionary(uniqueKeysWithValues: monthSummaries.map { ($0.dateLocal, $0) })
            let firstDate = OneDate.calendarDate(for: String(format: "%04d-%02d-01", year, month))
            let leadingPlaceholders = firstDate.map { OneDate.canonicalWeekdayIndex(for: $0) } ?? 0
            let daysInMonth = OneDate.numberOfDays(inMonth: month, year: year)
            let cells = (1...daysInMonth).map { day -> AnalyticsContributionDayCell in
                let dateLocal = String(format: "%04d-%02d-%02d", year, month, day)
                let summary = byDate[dateLocal]
                return AnalyticsContributionDayCell(
                    dateLocal: dateLocal,
                    dayNumber: day,
                    completionRate: summary?.completionRate ?? 0,
                    hasSummary: summary != nil
                )
            }
            return AnalyticsContributionMonthSection(
                month: month,
                label: OneDate.shortMonth(for: month),
                completedItems: monthSummaries.reduce(0) { $0 + $1.completedItems },
                expectedItems: monthSummaries.reduce(0) { $0 + $1.expectedItems },
                leadingPlaceholders: leadingPlaceholders,
                days: cells
            )
        }
    }

    private func monthlyDetailSummaries(from summaries: [DailySummary]) -> [DailySummary] {
        guard let selectedMonthWeek else {
            return summaries
        }
        return summaries.filter { monthSegment(for: $0.dateLocal) == selectedMonthWeek }
    }

    private func buildSentimentOverview(key: AnalyticsPeriodCacheKey) -> AnalyticsSentimentOverview? {
        let dates = sentimentDates(for: key)
        let dateSet = Set(dates)
        let visibleNotes = rawDailyNotes.filter { $0.periodType == .daily && dateSet.contains($0.periodStart) }
        let groupedNotes = Dictionary(grouping: visibleNotes, by: \.periodStart)
        let overallSummary = reflectionSentimentSummary(for: visibleNotes)
        guard !visibleNotes.isEmpty else {
            return nil
        }

        let trend: [AnalyticsSentimentTrendPoint]
        switch selectedReviewRange {
        case .week, .month:
            trend = dates.map { dateLocal in
                let daySummary = reflectionSentimentSummary(for: groupedNotes[dateLocal] ?? [])
                return AnalyticsSentimentTrendPoint(
                    label: selectedReviewRange == .week ? OneDate.shortWeekday(from: dateLocal) : OneDate.dayNumber(from: dateLocal),
                    sentiment: daySummary.dominant,
                    dateLocal: dateLocal
                )
            }
        case .quarter, .year:
            let notesByMonth = Dictionary(grouping: visibleNotes) { OneDate.monthBucket(from: $0.periodStart) }
            let visibleMonths = Array(Set(visibleNotes.map { OneDate.monthBucket(from: $0.periodStart) })).sorted()
            let months = selectedReviewRange == .year ? Array(1...12) : visibleMonths
            trend = months.map { month in
                let monthLabel = OneDate.shortMonth(for: month)
                let dominantMonth = reflectionSentimentSummary(for: notesByMonth[month] ?? []).dominant
                return AnalyticsSentimentTrendPoint(label: monthLabel, sentiment: dominantMonth, dateLocal: nil)
            }
        }

        return AnalyticsSentimentOverview(
            dominant: overallSummary.dominant,
            distribution: overallSummary.distribution,
            trend: trend
        )
    }

    private func monthSegment(for isoDateString: String) -> Int {
        let day = Int(OneDate.dayNumber(from: isoDateString)) ?? 1
        return max(1, ((day - 1) / 7) + 1)
    }

    private func sentimentDates(for key: AnalyticsPeriodCacheKey) -> [String] {
        let bounds = activeBounds(anchorDate: key.anchorDate, reviewRange: selectedReviewRange, weekStart: key.weekStart)
        return sequenceDates(startDate: bounds.startDate, endDate: bounds.endDate)
    }

    private func sequenceDates(startDate: String, endDate: String) -> [String] {
        guard let start = OneDate.calendarDate(for: startDate),
              let end = OneDate.calendarDate(for: endDate) else {
            return []
        }

        return stride(from: start, through: end, by: 86_400).map { date in
            AnalyticsDateRange.isoDate(date)
        }
    }

}

public enum AnalyticsDateRange {
    public static func bounds(anchorDate: String, periodType: PeriodType, weekStart: Int) -> (startDate: String, endDate: String) {
        guard let anchor = isoDateFormatter.date(from: anchorDate) else {
            return (anchorDate, anchorDate)
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt

        switch periodType {
        case .daily:
            return (anchorDate, anchorDate)
        case .weekly:
            let weekday = calendar.component(.weekday, from: anchor)
            let normalizedWeekday = (weekday + 5) % 7
            let offset = (normalizedWeekday - weekStart + 7) % 7
            let start = calendar.date(byAdding: .day, value: -offset, to: anchor) ?? anchor
            let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
            return (isoDateFormatter.string(from: start), isoDateFormatter.string(from: end))
        case .monthly:
            let components = calendar.dateComponents([.year, .month], from: anchor)
            let start = calendar.date(from: components) ?? anchor
            let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start) ?? anchor
            return (isoDateFormatter.string(from: start), isoDateFormatter.string(from: end))
        case .yearly:
            let year = calendar.component(.year, from: anchor)
            let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? anchor
            let end = calendar.date(from: DateComponents(year: year, month: 12, day: 31)) ?? anchor
            return (isoDateFormatter.string(from: start), isoDateFormatter.string(from: end))
        }
    }

    private static let isoDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    public static func isoDate(_ date: Date) -> String {
        isoDateFormatter.string(from: date)
    }
}

@MainActor
public final class CoachViewModel: ObservableObject {
    @Published public private(set) var cards: [CoachCard] = []
    @Published public private(set) var errorMessage: String?

    private let repository: CoachRepository

    public init(repository: CoachRepository) {
        self.repository = repository
    }

    public func load() async {
        do {
            let loadedCards = try await repository.loadCards()
            withAnimation(OneMotion.animation(.calmRefresh)) {
                cards = loadedCards
            }
            errorMessage = nil
        } catch {
            errorMessage = userFacingError(error)
        }
    }
}

@MainActor
public final class ReflectionsViewModel: ObservableObject {
    @Published public private(set) var notes: [ReflectionNote] = []
    @Published public private(set) var errorMessage: String?

    private let repository: ReflectionsRepository

    public init(repository: ReflectionsRepository) {
        self.repository = repository
    }

    public func load(periodType: PeriodType? = nil) async {
        do {
            let loadedNotes = try await repository.list(periodType: periodType)
            withAnimation(OneMotion.animation(.calmRefresh)) {
                notes = loadedNotes
            }
            errorMessage = nil
        } catch {
            OneHaptics.shared.trigger(.saveFailed)
            errorMessage = userFacingError(error)
        }
    }

    public func upsert(input: ReflectionWriteInput) async -> ReflectionNote? {
        do {
            let note = try await repository.upsert(input: input)
            withAnimation(OneMotion.animation(.stateChange)) {
                if let index = notes.firstIndex(where: { $0.id == note.id }) {
                    notes[index] = note
                } else {
                    notes.insert(note, at: 0)
                }
            }
            OneHaptics.shared.trigger(.saveSucceeded)
            errorMessage = nil
            return note
        } catch {
            OneHaptics.shared.trigger(.saveFailed)
            errorMessage = userFacingError(error)
            return nil
        }
    }

    public func delete(id: String) async -> Bool {
        do {
            try await repository.delete(id: id)
            withAnimation(OneMotion.animation(.dismiss)) {
                notes.removeAll { $0.id == id }
            }
            OneHaptics.shared.trigger(.destructiveConfirmed)
            errorMessage = nil
            return true
        } catch {
            OneHaptics.shared.trigger(.saveFailed)
            errorMessage = userFacingError(error)
            return false
        }
    }

}

@MainActor
public final class NotesViewModel: ObservableObject {
    @Published public var selectedPeriod: PeriodType = .daily
    @Published public var selectedLens: NotesIntelligenceLens = .emotion
    @Published public private(set) var anchorDate: String = OneDate.isoDate()
    @Published public private(set) var selectedDateLocal: String = OneDate.isoDate()
    @Published public private(set) var selectedYearMonth: Int = OneDate.monthBucket(from: OneDate.isoDate())
    @Published public private(set) var dayOptions: [NotesDayOption] = []
    @Published public private(set) var monthOptions: [NotesMonthOption] = []
    @Published public private(set) var selectedDayNotes: [ReflectionNote] = []
    @Published public private(set) var sentimentSummary: NotesSentimentSummary?
    @Published public private(set) var leadingPlaceholders: Int = 0
    @Published public private(set) var allNotes: [ReflectionNote] = []
    @Published public private(set) var intelligence: NotesIntelligenceSnapshot?
    @Published public private(set) var selectedHeroPointID: String?
    @Published public private(set) var selectedThemeID: String?
    @Published public private(set) var selectedType: NotesInferredType?
    @Published public private(set) var selectedTimingSegment: NotesTimeSegment?
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?

    private let repository: ReflectionsRepository
    private let analyticsRepository: AnalyticsRepository
    private var weekStart: Int = 0
    private var allActivitySummaries: [DailySummary] = []
    private var activityCoverage: (startDate: String, endDate: String)?

    public init(
        repository: ReflectionsRepository,
        analyticsRepository: AnalyticsRepository? = nil
    ) {
        self.repository = repository
        self.analyticsRepository = analyticsRepository ?? NotesNoopAnalyticsRepository()
    }

    public var currentYear: Int {
        OneDate.year(from: anchorDate) ?? OneDate.year(from: OneDate.isoDate()) ?? 2026
    }

    public var selectedDayTitle: String {
        OneDate.longDate(from: selectedDateLocal)
    }

    public var currentRangeTitle: String {
        switch selectedPeriod {
        case .daily:
            return selectedDayTitle
        case .weekly:
            let bounds = AnalyticsDateRange.bounds(anchorDate: selectedDateLocal, periodType: .weekly, weekStart: weekStart)
            return "\(OneDate.shortMonthDay(from: bounds.startDate)) - \(OneDate.shortMonthDay(from: bounds.endDate))"
        case .monthly:
            return "\(OneDate.fullMonth(for: selectedYearMonth)) \(currentYear)"
        case .yearly:
            return "\(currentYear)"
        }
    }

    public var selectedMonthLabel: String {
        "\(OneDate.fullMonth(for: selectedYearMonth)) \(currentYear)"
    }

    public var selectedHeroPoint: NotesHeroPoint? {
        intelligence?.heroPoints.first(where: { $0.id == selectedHeroPointID })
            ?? intelligence?.heroPoints.last(where: { $0.noteCount > 0 })
            ?? intelligence?.heroPoints.last
    }

    public var selectedTheme: NotesThemeCluster? {
        intelligence?.themes.first(where: { $0.id == selectedThemeID })
            ?? intelligence?.themes.first
    }

    public var selectedTypeProfile: NotesTypeProfile? {
        intelligence?.types.first(where: { $0.type == selectedType })
            ?? intelligence?.types.first
    }

    public var selectedTimingProfile: NotesTimingProfile? {
        intelligence?.timing.first(where: { $0.segment == selectedTimingSegment })
            ?? intelligence?.timing.first
    }

    public func load(
        anchorDate: String,
        periodType: PeriodType,
        weekStart: Int = 0,
        forceReload: Bool = false
    ) async {
        isLoading = true
        defer { isLoading = false }
        self.weekStart = weekStart
        if forceReload || allNotes.isEmpty {
            do {
                allNotes = try await repository.list(periodType: .daily)
                errorMessage = nil
            } catch {
                errorMessage = userFacingError(error)
                return
            }
        }

        await refreshActivitySummariesIfNeeded(force: forceReload)

        selectedPeriod = periodType
        self.anchorDate = anchorDate
        selectedDateLocal = anchorDate
        selectedYearMonth = OneDate.monthBucket(from: anchorDate)
        withAnimation(OneMotion.animation(.calmRefresh)) {
            refreshDerivedState()
        }
    }

    public func refreshFromStore(anchorDate: String? = nil, weekStart: Int? = nil) async {
        await load(
            anchorDate: anchorDate ?? selectedDateLocal,
            periodType: selectedPeriod,
            weekStart: weekStart ?? self.weekStart,
            forceReload: true
        )
    }

    public func selectPeriod(_ period: PeriodType) {
        withAnimation(OneMotion.animation(.stateChange)) {
            selectedPeriod = period
            selectedYearMonth = OneDate.monthBucket(from: selectedDateLocal)
            refreshDerivedState()
        }
        OneHaptics.shared.trigger(.selectionChanged)
    }

    public func selectLens(_ lens: NotesIntelligenceLens) {
        guard selectedLens != lens else {
            return
        }
        withAnimation(OneMotion.animation(.stateChange)) {
            selectedLens = lens
        }
        OneHaptics.shared.trigger(.selectionChanged)
    }

    public func selectDay(_ dateLocal: String) {
        withAnimation(OneMotion.animation(.stateChange)) {
            anchorDate = dateLocal
            selectedDateLocal = dateLocal
            selectedYearMonth = OneDate.monthBucket(from: dateLocal)
            refreshDerivedState()
        }
        OneHaptics.shared.trigger(.selectionChanged)
    }

    public func selectHeroPoint(id: String) {
        guard selectedHeroPointID != id else {
            return
        }
        selectedHeroPointID = id
    }

    public func scrubHero(locationX: CGFloat, width: CGFloat) {
        guard let intelligence,
              !intelligence.heroPoints.isEmpty,
              width > 0 else {
            return
        }
        let progress = max(0, min(1, locationX / width))
        let index = min(
            intelligence.heroPoints.count - 1,
            max(0, Int((progress * CGFloat(intelligence.heroPoints.count - 1)).rounded()))
        )
        selectHeroPoint(id: intelligence.heroPoints[index].id)
    }

    public func selectTheme(id: String) {
        guard selectedThemeID != id else {
            return
        }
        selectedThemeID = id
        OneHaptics.shared.trigger(.selectionChanged)
    }

    public func selectType(_ type: NotesInferredType) {
        guard selectedType != type else {
            return
        }
        selectedType = type
        OneHaptics.shared.trigger(.selectionChanged)
    }

    public func selectTiming(_ segment: NotesTimeSegment) {
        guard selectedTimingSegment != segment else {
            return
        }
        selectedTimingSegment = segment
        OneHaptics.shared.trigger(.selectionChanged)
    }

    public func selectMonth(_ month: Int) {
        let day = Int(OneDate.dayNumber(from: selectedDateLocal)) ?? 1
        let clampedDay = min(day, OneDate.numberOfDays(inMonth: month, year: currentYear))
        let nextDate = String(format: "%04d-%02d-%02d", currentYear, month, clampedDay)
        withAnimation(OneMotion.animation(.stateChange)) {
            anchorDate = nextDate
            selectedDateLocal = nextDate
            selectedYearMonth = month
            refreshDerivedState()
        }
        OneHaptics.shared.trigger(.selectionChanged)
    }

    public func moveSelection(by offset: Int) {
        let nextDate: String
        switch selectedPeriod {
        case .daily:
            nextDate = shiftedDate(from: selectedDateLocal, days: offset)
        case .weekly:
            nextDate = shiftedDate(from: selectedDateLocal, days: offset * 7)
        case .monthly:
            nextDate = shiftedDate(from: selectedDateLocal, months: offset)
        case .yearly:
            nextDate = shiftedDate(from: selectedDateLocal, years: offset)
        }
        withAnimation(OneMotion.animation(.stateChange)) {
            anchorDate = nextDate
            selectedDateLocal = nextDate
            selectedYearMonth = OneDate.monthBucket(from: nextDate)
            refreshDerivedState()
        }
        OneHaptics.shared.trigger(.selectionChanged)
    }

    @discardableResult
    public func createNote(
        content: String,
        sentiment: ReflectionSentiment,
        for dateLocal: String? = nil
    ) async -> ReflectionNote? {
        let targetDate = dateLocal ?? selectedDateLocal
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        do {
            let note = try await repository.upsert(
                input: ReflectionWriteInput(
                    periodType: .daily,
                    periodStart: targetDate,
                    periodEnd: targetDate,
                    content: trimmed,
                    sentiment: sentiment,
                    tags: Self.derivedReflectionTags(
                        content: trimmed,
                        sentiment: sentiment,
                        existing: []
                    )
                )
            )
            allNotes.insert(note, at: 0)
            await refreshActivitySummariesIfNeeded(force: false)
            withAnimation(OneMotion.animation(.stateChange)) {
                anchorDate = targetDate
                selectedDateLocal = targetDate
                selectedYearMonth = OneDate.monthBucket(from: targetDate)
                refreshDerivedState()
            }
            OneHaptics.shared.trigger(.saveSucceeded)
            OneSyncFeedbackCenter.shared.showSynced(
                title: "Note saved",
                message: "Reflection added for \(OneDate.shortMonthDay(from: targetDate))."
            )
            errorMessage = nil
            return note
        } catch {
            OneHaptics.shared.trigger(.saveFailed)
            errorMessage = userFacingError(error)
            return nil
        }
    }

    public func delete(id: String) async -> Bool {
        do {
            try await repository.delete(id: id)
            allNotes.removeAll { $0.id == id }
            await refreshActivitySummariesIfNeeded(force: false)
            withAnimation(OneMotion.animation(.dismiss)) {
                refreshDerivedState()
            }
            OneHaptics.shared.trigger(.destructiveConfirmed)
            errorMessage = nil
            return true
        } catch {
            OneHaptics.shared.trigger(.saveFailed)
            errorMessage = userFacingError(error)
            return false
        }
    }

    private func refreshDerivedState() {
        let visibleDates = visibleDateRange()
        let visibleDateSet = Set(visibleDates)
        let allDailyNotes = allNotes.filter { $0.periodType == .daily }
        let notesByDate = Dictionary(grouping: allDailyNotes, by: \.periodStart)

        dayOptions = visibleDates.map { dateLocal in
            let dayNotes = notesByDate[dateLocal] ?? []
            let daySummary = reflectionSentimentSummary(for: dayNotes)
            return NotesDayOption(
                dateLocal: dateLocal,
                weekdayLabel: OneDate.shortWeekday(from: dateLocal),
                dayNumber: Int(OneDate.dayNumber(from: dateLocal)) ?? 0,
                sentiment: daySummary.dominant,
                hasNotes: !dayNotes.isEmpty
            )
        }

        if !visibleDateSet.contains(selectedDateLocal), let fallback = visibleDates.first {
            selectedDateLocal = fallback
            anchorDate = fallback
            selectedYearMonth = OneDate.monthBucket(from: fallback)
        }

        selectedDayNotes = allNotes
            .filter { $0.periodType == .daily && $0.periodStart == selectedDateLocal }
            .sorted(by: reflectionNoteSort(lhs:rhs:))

        monthOptions = (1...12).map { month in
            let notes = notesForMonth(month, year: currentYear)
            let monthSummary = reflectionSentimentSummary(for: notes)
            return NotesMonthOption(
                month: month,
                label: OneDate.shortMonth(for: month),
                noteCount: notes.count,
                dominant: monthSummary.dominant
            )
        }

        if let firstVisible = visibleDates.first,
           let firstDate = OneDate.calendarDate(for: firstVisible) {
            leadingPlaceholders = OneDate.canonicalWeekdayIndex(for: firstDate)
        } else {
            leadingPlaceholders = 0
        }

        let visibleNotes = allNotes.filter { visibleDateSet.contains($0.periodStart) }
        let visibleSummary = reflectionSentimentSummary(for: visibleNotes)

        sentimentSummary = visibleNotes.isEmpty ? nil : NotesSentimentSummary(
            noteCount: visibleNotes.count,
            activeDays: Set(visibleNotes.map(\.periodStart)).count,
            dominant: visibleSummary.dominant,
            distribution: visibleSummary.distribution
        )

        let intelligenceDates = intelligenceDateRange()
        let intelligenceDateSet = Set(intelligenceDates)
        let intelligenceNotes = allNotes.filter {
            $0.periodType == .daily && intelligenceDateSet.contains($0.periodStart)
        }
        intelligence = buildIntelligenceSnapshot(
            notes: intelligenceNotes,
            dateRange: intelligenceDates,
            activitySummaries: allActivitySummaries.filter { intelligenceDateSet.contains($0.dateLocal) }
        )
        normalizeIntelligenceSelections()
    }

    private func visibleDateRange() -> [String] {
        switch selectedPeriod {
        case .daily:
            return [selectedDateLocal]
        case .weekly:
            let bounds = AnalyticsDateRange.bounds(anchorDate: selectedDateLocal, periodType: .weekly, weekStart: weekStart)
            return sequenceDates(startDate: bounds.startDate, endDate: bounds.endDate)
        case .monthly:
            return monthDates(month: selectedYearMonth, year: currentYear)
        case .yearly:
            return monthDates(month: selectedYearMonth, year: currentYear)
        }
    }

    private func intelligenceDateRange() -> [String] {
        switch selectedPeriod {
        case .daily:
            let recentStart = shiftedDate(from: selectedDateLocal, days: -13)
            let recentRange = sequenceDates(startDate: recentStart, endDate: selectedDateLocal)
            if allNotes.filter({ recentRange.contains($0.periodStart) }).count >= 4 {
                return recentRange
            }
            let expandedStart = shiftedDate(from: selectedDateLocal, days: -29)
            return sequenceDates(startDate: expandedStart, endDate: selectedDateLocal)
        case .weekly:
            return visibleDateRange()
        case .monthly:
            return monthDates(month: selectedYearMonth, year: currentYear)
        case .yearly:
            return yearDates(year: currentYear)
        }
    }

    private func notesForMonth(_ month: Int, year: Int) -> [ReflectionNote] {
        allNotes.filter { note in
            note.periodType == .daily &&
            OneDate.year(from: note.periodStart) == year &&
            OneDate.monthBucket(from: note.periodStart) == month
        }
    }

    private func monthDates(month: Int, year: Int) -> [String] {
        let count = OneDate.numberOfDays(inMonth: month, year: year)
        return (1...count).map { day in
            String(format: "%04d-%02d-%02d", year, month, day)
        }
    }

    private func yearDates(year: Int) -> [String] {
        (1...12).flatMap { month in
            monthDates(month: month, year: year)
        }
    }

    private func sequenceDates(startDate: String, endDate: String) -> [String] {
        guard let start = OneDate.calendarDate(for: startDate),
              let end = OneDate.calendarDate(for: endDate) else {
            return []
        }

        return stride(from: start, through: end, by: 86_400).map { date in
            NotesViewModel.isoDateFormatter.string(from: date)
        }
    }

    private func shiftedDate(from dateLocal: String, days: Int = 0, months: Int = 0, years: Int = 0) -> String {
        guard let date = OneDate.calendarDate(for: dateLocal) else {
            return dateLocal
        }
        let components = DateComponents(year: years, month: months, day: days)
        let shifted = NotesViewModel.calendar.date(byAdding: components, to: date) ?? date
        return NotesViewModel.isoDateFormatter.string(from: shifted)
    }

    private func refreshActivitySummariesIfNeeded(force: Bool) async {
        let dailyNotes = allNotes.filter { $0.periodType == .daily }
        guard let startDate = dailyNotes.map(\.periodStart).min(),
              let endDate = dailyNotes.map(\.periodStart).max() else {
            allActivitySummaries = []
            activityCoverage = nil
            return
        }

        if !force,
           let activityCoverage,
           activityCoverage.startDate == startDate,
           activityCoverage.endDate == endDate {
            return
        }

        do {
            allActivitySummaries = try await analyticsRepository.loadDaily(startDate: startDate, endDate: endDate)
            activityCoverage = (startDate: startDate, endDate: endDate)
        } catch {
            allActivitySummaries = []
            activityCoverage = nil
        }
    }

    private func normalizeIntelligenceSelections() {
        guard let intelligence else {
            selectedHeroPointID = nil
            selectedThemeID = nil
            selectedType = nil
            selectedTimingSegment = nil
            return
        }

        if !intelligence.heroPoints.contains(where: { $0.id == selectedHeroPointID }) {
            selectedHeroPointID = intelligence.heroPoints.last(where: { $0.noteCount > 0 })?.id
                ?? intelligence.heroPoints.last?.id
        }
        if !intelligence.themes.contains(where: { $0.id == selectedThemeID }) {
            selectedThemeID = intelligence.themes.first?.id
        }
        if !intelligence.types.contains(where: { $0.type == selectedType }) {
            selectedType = intelligence.types.first?.type
        }
        if !intelligence.timing.contains(where: { $0.segment == selectedTimingSegment }) {
            selectedTimingSegment = intelligence.timing.first?.segment
        }
    }

    private func buildIntelligenceSnapshot(
        notes: [ReflectionNote],
        dateRange: [String],
        activitySummaries: [DailySummary]
    ) -> NotesIntelligenceSnapshot? {
        let analyzed = notes
            .sorted(by: reflectionNoteSort(lhs:rhs:))
            .map(Self.analyze(note:))
        guard analyzed.count >= 2 else {
            return nil
        }

        let activityByDate = Dictionary(uniqueKeysWithValues: activitySummaries.map { ($0.dateLocal, $0) })
        let heroPoints = buildHeroPoints(from: analyzed, dateRange: dateRange, activityByDate: activityByDate)
        guard !heroPoints.isEmpty else {
            return nil
        }

        let themes = buildThemeClusters(from: analyzed)
        let types = buildTypeProfiles(from: analyzed)
        let timing = buildTimingProfiles(from: analyzed)
        let behaviorMetrics = buildBehaviorMetrics(from: analyzed)
        let patternShifts = buildPatternShifts(from: analyzed)
        let crossDomainHook = buildCrossDomainHook(from: analyzed, activityByDate: activityByDate)
        let insights = buildInsights(
            heroPoints: heroPoints,
            themes: themes,
            types: types,
            timing: timing,
            patternShifts: patternShifts,
            crossDomainHook: crossDomainHook
        )

        return NotesIntelligenceSnapshot(
            heroTitle: buildHeroTitle(from: heroPoints),
            heroSubtitle: buildHeroSubtitle(from: heroPoints, noteCount: analyzed.count),
            heroDetail: buildHeroDetail(from: heroPoints),
            heroPoints: heroPoints,
            themes: themes,
            types: types,
            timing: timing,
            behaviorMetrics: behaviorMetrics,
            insights: insights,
            patternShifts: patternShifts,
            crossDomainHook: crossDomainHook
        )
    }

    private func buildHeroPoints(
        from notes: [NotesAnalyzedNote],
        dateRange: [String],
        activityByDate: [String: DailySummary]
    ) -> [NotesHeroPoint] {
        switch selectedPeriod {
        case .yearly:
            let groupedDates = Dictionary(grouping: dateRange, by: { OneDate.monthBucket(from: $0) })
            return (1...12).compactMap { month in
                guard let dates = groupedDates[month],
                      let start = dates.first,
                      let end = dates.last else {
                    return nil
                }
                let bucketNotes = notes.filter {
                    OneDate.monthBucket(from: $0.note.periodStart) == month &&
                    OneDate.year(from: $0.note.periodStart) == currentYear
                }
                return makeHeroPoint(
                    id: "month-\(month)",
                    label: OneDate.shortMonth(for: month),
                    detail: OneDate.fullMonth(for: month),
                    rangeStart: start,
                    rangeEnd: end,
                    notes: bucketNotes,
                    completionRate: dates.compactMap { activityByDate[$0]?.completionRate }.average
                )
            }
        default:
            let notesByDate = Dictionary(grouping: notes, by: { $0.note.periodStart })
            return dateRange.map { dateLocal in
                makeHeroPoint(
                    id: dateLocal,
                    label: selectedPeriod == .monthly ? OneDate.dayNumber(from: dateLocal) : OneDate.shortWeekday(from: dateLocal),
                    detail: OneDate.shortMonthDay(from: dateLocal),
                    rangeStart: dateLocal,
                    rangeEnd: dateLocal,
                    notes: notesByDate[dateLocal] ?? [],
                    completionRate: activityByDate[dateLocal]?.completionRate
                )
            }
        }
    }

    private func makeHeroPoint(
        id: String,
        label: String,
        detail: String,
        rangeStart: String,
        rangeEnd: String,
        notes: [NotesAnalyzedNote],
        completionRate: Double?
    ) -> NotesHeroPoint {
        let dominant = reflectionSentimentSummary(for: notes.map(\.note)).dominant
        return NotesHeroPoint(
            id: id,
            label: label,
            detail: detail,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            noteCount: notes.count,
            dominant: dominant,
            sentimentBalance: notes.map(\.sentimentScore).average ?? 0,
            volatility: notes.map(\.sentimentScore).standardDeviation,
            clarity: notes.map(\.clarity).average ?? 0,
            averageWords: Int((notes.map { Double($0.wordCount) }.average ?? 0).rounded()),
            dominantType: notes.groupedCounts(by: \.inferredType).max(by: { $0.value < $1.value })?.key,
            completionRate: completionRate
        )
    }

    private func buildThemeClusters(from notes: [NotesAnalyzedNote]) -> [NotesThemeCluster] {
        struct Candidate {
            var noteIDs: Set<String> = []
            var supportingKeywords: [String: Int] = [:]
        }

        var candidates: [String: Candidate] = [:]
        for analyzed in notes {
            let noteTerms = Array(Set(
                analyzed.note.tags.map(Self.cleanKeyword)
                + analyzed.phrases.prefix(3).map(Self.cleanKeyword)
                + analyzed.keywords.prefix(4).map(Self.cleanKeyword)
            )).filter { !$0.isEmpty }
            for term in noteTerms {
                candidates[term, default: Candidate()].noteIDs.insert(analyzed.note.id)
                for keyword in analyzed.keywords.prefix(5) {
                    candidates[term, default: Candidate()].supportingKeywords[keyword, default: 0] += 1
                }
            }
        }

        var selectedRoots: Set<String> = []
        var clusters: [NotesThemeCluster] = []
        for (term, candidate) in candidates
            .filter({ $0.value.noteIDs.count >= 2 })
            .sorted(by: { lhs, rhs in
                if lhs.value.noteIDs.count != rhs.value.noteIDs.count {
                    return lhs.value.noteIDs.count > rhs.value.noteIDs.count
                }
                return lhs.key < rhs.key
            }) {
            let root = Self.themeRoot(for: term)
            guard !selectedRoots.contains(root) else {
                continue
            }
            let clusterNotes = notes.filter { candidate.noteIDs.contains($0.note.id) }
            let dominant = reflectionSentimentSummary(for: clusterNotes.map(\.note)).dominant
            let recentNotes = clusterNotes.filter { $0.note.periodStart >= shiftedDate(from: selectedDateLocal, days: -7) }
            let dominantType = clusterNotes.groupedCounts(by: \.inferredType).max(by: { $0.value < $1.value })?.key
            let averageSentiment = clusterNotes.map(\.sentimentScore).average ?? 0
            let headline: String
            if recentNotes.count >= max(2, clusterNotes.count / 2) {
                headline = "More present in your recent notes."
            } else if dominantType == .reflection {
                headline = "Shows up most in reflective notes."
            } else if dominantType == .planning {
                headline = "Often appears when you are planning ahead."
            } else if averageSentiment < -0.25 {
                headline = "Carries a heavier emotional tone."
            } else {
                headline = "Keeps resurfacing across this range."
            }
            let keywords = candidate.supportingKeywords
                .sorted(by: { lhs, rhs in
                    if lhs.value != rhs.value {
                        return lhs.value > rhs.value
                    }
                    return lhs.key < rhs.key
                })
                .map(\.key)
                .filter { $0 != term }
            clusters.append(
                NotesThemeCluster(
                    id: term,
                    title: Self.humanizedTheme(term),
                    noteCount: clusterNotes.count,
                    supportingKeywords: Array(keywords.prefix(3)),
                    headline: headline,
                    detail: "\(clusterNotes.count) notes connect back to this theme.",
                    dominantSentiment: dominant
                )
            )
            selectedRoots.insert(root)
            if clusters.count == 4 {
                break
            }
        }
        return clusters
    }

    private func buildTypeProfiles(from notes: [NotesAnalyzedNote]) -> [NotesTypeProfile] {
        NotesInferredType.allCases.compactMap { type in
            let matches = notes.filter { $0.inferredType == type }
            guard !matches.isEmpty else {
                return nil
            }
            let dominant = reflectionSentimentSummary(for: matches.map(\.note)).dominant
            let share = Double(matches.count) / Double(notes.count)
            let headline: String
            switch type {
            case .quickCapture:
                headline = share >= 0.4 ? "You rely on fast captures to mark what matters." : "Quick captures appear when you want the signal, not the essay."
            case .reflection:
                headline = share >= 0.35 ? "Reflection is one of your default note modes." : "Reflection notes surface when you slow down enough to interpret the day."
            case .planning:
                headline = "Planning notes usually sit close to active work blocks."
            case .idea:
                headline = "Idea notes appear when you switch from logging to exploring."
            }
            return NotesTypeProfile(
                type: type,
                noteCount: matches.count,
                share: share,
                averageWords: Int((matches.map { Double($0.wordCount) }.average ?? 0).rounded()),
                dominantSentiment: dominant,
                headline: headline,
                detail: "Average length \(Int((matches.map { Double($0.wordCount) }.average ?? 0).rounded())) words."
            )
        }
        .sorted(by: { $0.noteCount > $1.noteCount })
    }

    private func buildTimingProfiles(from notes: [NotesAnalyzedNote]) -> [NotesTimingProfile] {
        let timestamped = notes.filter { $0.timeSegment != nil }
        guard !timestamped.isEmpty else {
            return []
        }
        return NotesTimeSegment.allCases.compactMap { segment in
            let matches = timestamped.filter { $0.timeSegment == segment }
            guard !matches.isEmpty else {
                return nil
            }
            let averageClarity = matches.map(\.clarity).average ?? 0
            let averageSentiment = matches.map(\.sentimentScore).average ?? 0
            let volatility = matches.map(\.sentimentScore).standardDeviation
            let headline: String
            if averageClarity >= 0.66 {
                headline = "This is one of your clearest writing windows."
            } else if volatility >= 0.45 {
                headline = "Emotion swings more here than elsewhere."
            } else if averageSentiment >= 0.25 {
                headline = "This window usually carries a lighter tone."
            } else {
                headline = "This window reads more practical than expansive."
            }
            return NotesTimingProfile(
                segment: segment,
                noteCount: matches.count,
                averageWords: Int((matches.map { Double($0.wordCount) }.average ?? 0).rounded()),
                averageClarity: averageClarity,
                averageSentiment: averageSentiment,
                volatility: volatility,
                headline: headline,
                detail: "\(matches.count) notes, average \(Int((matches.map { Double($0.wordCount) }.average ?? 0).rounded())) words."
            )
        }
        .sorted(by: { $0.noteCount > $1.noteCount })
    }

    private func buildBehaviorMetrics(from notes: [NotesAnalyzedNote]) -> [NotesBehaviorMetric] {
        let averageWords = Int((notes.map { Double($0.wordCount) }.average ?? 0).rounded())
        let shortShare = Double(notes.filter { $0.wordCount <= 24 }.count) / Double(notes.count)
        let longShare = Double(notes.filter { $0.wordCount >= 90 }.count) / Double(notes.count)
        let stability = max(0, 1 - min(1, (notes.map { Double($0.wordCount) }.standardDeviation / 70)))
        return [
            NotesBehaviorMetric(
                title: "Average Length",
                value: "\(averageWords) words",
                detail: averageWords >= 70 ? "You usually leave yourself room to unpack context." : "Your notes tend to stay concise and close to the signal."
            ),
            NotesBehaviorMetric(
                title: "Short Note Share",
                value: "\(Int((shortShare * 100).rounded()))%",
                detail: shortShare >= 0.45 ? "Short captures are a real part of how you think on the move." : "You more often stay with a note long enough to develop it."
            ),
            NotesBehaviorMetric(
                title: "Volume Stability",
                value: "\(Int((stability * 100).rounded()))%",
                detail: longShare >= 0.25 ? "Longer notes appear often enough to create depth." : "Most notes stay inside a fairly tight length band."
            ),
        ]
    }

    private func buildPatternShifts(from notes: [NotesAnalyzedNote]) -> [NotesPatternShift] {
        guard notes.count >= 4 else {
            return []
        }
        let chronological = notes.sorted { $0.note.periodStart < $1.note.periodStart }
        let splitIndex = max(1, chronological.count / 2)
        let early = Array(chronological.prefix(splitIndex))
        let late = Array(chronological.suffix(chronological.count - splitIndex))
        guard !late.isEmpty else {
            return []
        }

        var shifts: [NotesPatternShift] = []
        let sentimentDelta = (late.map(\.sentimentScore).average ?? 0) - (early.map(\.sentimentScore).average ?? 0)
        if abs(sentimentDelta) >= 0.25 {
            shifts.append(
                NotesPatternShift(
                    id: "sentiment-shift",
                    title: sentimentDelta > 0 ? "Emotional tone has lifted." : "Emotional tone has grown heavier.",
                    detail: sentimentDelta > 0
                        ? "Recent notes read steadier than the opening stretch."
                        : "The later part of this range carries more strain than the start."
                )
            )
        }

        let wordDelta = (late.map { Double($0.wordCount) }.average ?? 0) - (early.map { Double($0.wordCount) }.average ?? 0)
        if abs(wordDelta) >= 18 {
            shifts.append(
                NotesPatternShift(
                    id: "length-shift",
                    title: wordDelta > 0 ? "Notes have become longer." : "Notes have become tighter.",
                    detail: wordDelta > 0
                        ? "You are giving yourself more room to explain what is happening."
                        : "You are capturing the signal faster, with less unpacking."
                )
            )
        }

        let reflectionDelta = Self.share(of: .reflection, within: late) - Self.share(of: .reflection, within: early)
        if abs(reflectionDelta) >= 0.22 {
            shifts.append(
                NotesPatternShift(
                    id: "type-shift",
                    title: reflectionDelta > 0 ? "Reflection notes are taking more space." : "Reflection notes have thinned out.",
                    detail: reflectionDelta > 0
                        ? "Lately you are interpreting the day more often instead of only logging it."
                        : "The range is leaning more toward capture and execution than interpretation."
                )
            )
        }

        return Array(shifts.prefix(3))
    }

    private func buildCrossDomainHook(
        from notes: [NotesAnalyzedNote],
        activityByDate: [String: DailySummary]
    ) -> NotesCrossDomainHook? {
        struct DaySignal {
            let completionRate: Double
            let clarity: Double
            let volatility: Double
            let reflectionShare: Double
        }

        let grouped = Dictionary(grouping: notes, by: { $0.note.periodStart })
        let signals: [DaySignal] = grouped.compactMap { dateLocal, entries in
            guard let summary = activityByDate[dateLocal], !entries.isEmpty else {
                return nil
            }
            return DaySignal(
                completionRate: summary.completionRate,
                clarity: entries.map(\.clarity).average ?? 0,
                volatility: entries.map(\.sentimentScore).standardDeviation,
                reflectionShare: Double(entries.filter { $0.inferredType == .reflection }.count) / Double(entries.count)
            )
        }

        guard signals.count >= 4 else {
            return nil
        }
        let steady = signals.filter { $0.completionRate >= 0.7 }
        let low = signals.filter { $0.completionRate <= 0.4 }
        guard steady.count >= 2, low.count >= 2 else {
            return nil
        }

        let clarityDelta = (steady.map(\.clarity).average ?? 0) - (low.map(\.clarity).average ?? 0)
        if clarityDelta >= 0.14 {
            return NotesCrossDomainHook(
                id: "clarity-completion",
                title: "Clarity tends to follow steadier days.",
                detail: "Your note structure is cleaner after higher-completion days, which suggests execution rhythm helps your writing settle."
            )
        }

        let reflectionDelta = (low.map(\.reflectionShare).average ?? 0) - (steady.map(\.reflectionShare).average ?? 0)
        if reflectionDelta >= 0.2 {
            return NotesCrossDomainHook(
                id: "reflection-recovery",
                title: "Reflection notes show up more after lower-reliability days.",
                detail: "When completion drops, your writing tilts more interpretive than tactical."
            )
        }

        let volatilityDelta = (low.map(\.volatility).average ?? 0) - (steady.map(\.volatility).average ?? 0)
        if volatilityDelta >= 0.18 {
            return NotesCrossDomainHook(
                id: "volatility-completion",
                title: "Lower-completion days bring more emotional swing into your notes.",
                detail: "The language gets more variable when execution is less stable."
            )
        }

        return nil
    }

    private func buildInsights(
        heroPoints: [NotesHeroPoint],
        themes: [NotesThemeCluster],
        types: [NotesTypeProfile],
        timing: [NotesTimingProfile],
        patternShifts: [NotesPatternShift],
        crossDomainHook: NotesCrossDomainHook?
    ) -> [NotesInsightStatement] {
        var insights: [NotesInsightStatement] = []
        let meaningfulHeroPoints = heroPoints.filter { $0.noteCount > 0 }
        if meaningfulHeroPoints.count >= 3 {
            let early = Array(meaningfulHeroPoints.prefix(max(1, meaningfulHeroPoints.count / 2)))
            let late = Array(meaningfulHeroPoints.suffix(max(1, meaningfulHeroPoints.count / 2)))
            let balanceDelta = (late.map(\.sentimentBalance).average ?? 0) - (early.map(\.sentimentBalance).average ?? 0)
            if abs(balanceDelta) >= 0.22 {
                insights.append(
                    NotesInsightStatement(
                        id: "hero-balance",
                        lens: .emotion,
                        text: balanceDelta > 0
                            ? "Your emotional pattern has been settling as this range moves forward."
                            : "The later part of this range reads heavier than the start.",
                        confidence: min(1, 0.6 + abs(balanceDelta))
                    )
                )
            }
        }

        if timing.count >= 2,
           let clearest = timing.max(by: { $0.averageClarity < $1.averageClarity }),
           let muddiest = timing.min(by: { $0.averageClarity < $1.averageClarity }),
           clearest.averageClarity - muddiest.averageClarity >= 0.12 {
            insights.append(
                NotesInsightStatement(
                    id: "timing-clarity",
                    lens: .timing,
                    text: (clearest.segment == .early || clearest.segment == .morning)
                        ? "You tend to write more clearly earlier in the day."
                        : "Your clearest notes usually land in the \(clearest.segment.title.lowercased()).",
                    confidence: min(1, 0.62 + (clearest.averageClarity - muddiest.averageClarity))
                )
            )
        }

        if timing.count >= 2,
           let volatile = timing.max(by: { $0.volatility < $1.volatility }),
           let stable = timing.min(by: { $0.volatility < $1.volatility }),
           volatile.volatility - stable.volatility >= 0.15,
           volatile.averageWords <= stable.averageWords {
            insights.append(
                NotesInsightStatement(
                    id: "timing-volatility",
                    lens: .timing,
                    text: "Your \(volatile.segment.title.lowercased()) notes are shorter and more emotionally volatile.",
                    confidence: min(1, 0.58 + (volatile.volatility - stable.volatility))
                )
            )
        }

        if let planning = types.first(where: { $0.type == .planning }),
           planning.share >= 0.22,
           let dominantTiming = timing.max(by: { $0.noteCount < $1.noteCount }),
           dominantTiming.segment == .early || dominantTiming.segment == .morning {
            insights.append(
                NotesInsightStatement(
                    id: "planning-cluster",
                    lens: .types,
                    text: "Planning-style notes cluster around your earlier writing windows.",
                    confidence: min(1, 0.55 + planning.share)
                )
            )
        }

        if let topTheme = themes.first, topTheme.noteCount >= 3 {
            insights.append(
                NotesInsightStatement(
                    id: "theme-repeat",
                    lens: .themes,
                    text: "\(topTheme.title) keeps recurring in your notes.",
                    confidence: min(1, 0.54 + Double(topTheme.noteCount) / 10)
                )
            )
        }

        if let crossDomainHook {
            insights.append(
                NotesInsightStatement(
                    id: crossDomainHook.id,
                    lens: .behavior,
                    text: crossDomainHook.title,
                    confidence: 0.72
                )
            )
        }

        if let shift = patternShifts.first {
            insights.append(
                NotesInsightStatement(
                    id: "shift-\(shift.id)",
                    lens: .behavior,
                    text: shift.title,
                    confidence: 0.64
                )
            )
        }

        return Dictionary(grouping: insights, by: \.text)
            .compactMap { $0.value.max(by: { $0.confidence < $1.confidence }) }
            .sorted(by: { $0.confidence > $1.confidence })
            .prefix(4)
            .map { $0 }
    }

    private func buildHeroTitle(from points: [NotesHeroPoint]) -> String {
        let meaningful = points.filter { $0.noteCount > 0 }
        guard meaningful.count >= 2 else {
            return "Your notes are starting to build an emotional pattern."
        }
        let early = Array(meaningful.prefix(max(1, meaningful.count / 2)))
        let late = Array(meaningful.suffix(max(1, meaningful.count / 2)))
        let balanceDelta = (late.map(\.sentimentBalance).average ?? 0) - (early.map(\.sentimentBalance).average ?? 0)
        let lateVolatility = late.map(\.volatility).average ?? 0
        if balanceDelta >= 0.25 {
            return "Your emotional pattern has been lifting."
        }
        if balanceDelta <= -0.25 {
            return "Your emotional pattern has been carrying more weight lately."
        }
        if lateVolatility >= 0.42 {
            return "This range reads emotionally mixed rather than steady."
        }
        return "Your notes are holding a mostly steady tone."
    }

    private func buildHeroSubtitle(from points: [NotesHeroPoint], noteCount: Int) -> String {
        guard let first = points.first, let last = points.last else {
            return "\(noteCount) notes"
        }
        if first.rangeStart == last.rangeEnd {
            return "\(noteCount) notes"
        }
        return "\(OneDate.shortMonthDay(from: first.rangeStart)) - \(OneDate.shortMonthDay(from: last.rangeEnd)) · \(noteCount) notes"
    }

    private func buildHeroDetail(from points: [NotesHeroPoint]) -> String {
        guard let latest = points.last(where: { $0.noteCount > 0 }) else {
            return "Scrub across the curve to see where your writing steadied or drifted."
        }
        if latest.volatility >= 0.45 {
            return "Recent notes carry more emotional swing than the rest of this range."
        }
        if latest.clarity >= 0.68 {
            return "Recent notes are landing with stronger structure and more readable detail."
        }
        if let dominantType = latest.dominantType {
            return "Recent notes lean \(dominantType.title.lowercased()) more than any other type."
        }
        return "Scrub across the curve to see where your writing steadied or drifted."
    }

    private static func analyze(note: ReflectionNote) -> NotesAnalyzedNote {
        let orderedTokens = tokenize(content: note.content)
        let keywords = Array(Set(orderedTokens.map(cleanKeyword).filter { !$0.isEmpty && !stopWords.contains($0) })).sorted()
        let phrases = Array(Set(orderedTokens.adjacentPairs().compactMap { pair -> String? in
            let first = cleanKeyword(pair.0)
            let second = cleanKeyword(pair.1)
            guard first.count > 2, second.count > 2,
                  !stopWords.contains(first), !stopWords.contains(second) else {
                return nil
            }
            return "\(first) \(second)"
        })).sorted()
        let wordCount = orderedTokens.count
        return NotesAnalyzedNote(
            note: note,
            orderedTokens: orderedTokens,
            keywords: keywords,
            phrases: phrases,
            wordCount: wordCount,
            clarity: clarityScore(content: note.content, wordCount: wordCount),
            sentimentScore: sentimentValue(note.sentiment),
            inferredType: inferType(content: note.content, orderedTokens: orderedTokens, wordCount: wordCount),
            timeSegment: timeSegment(for: note.createdAt ?? note.updatedAt)
        )
    }

    private static func sentimentValue(_ sentiment: ReflectionSentiment) -> Double {
        switch sentiment {
        case .great:
            return 1
        case .focused:
            return 0.5
        case .okay:
            return 0.05
        case .tired:
            return -0.45
        case .stressed:
            return -1
        }
    }

    private static func clarityScore(content: String, wordCount: Int) -> Double {
        let sentenceCount = max(1, content.components(separatedBy: CharacterSet(charactersIn: ".!?\n")).filter {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.count)
        let lineCount = max(1, content.components(separatedBy: .newlines).count)
        let bulletCount = content.components(separatedBy: .newlines).filter {
            let trimmed = $0.trimmingCharacters(in: .whitespaces)
            return trimmed.hasPrefix("-") || trimmed.hasPrefix("*") || trimmed.hasPrefix("•")
        }.count
        let punctuationCount = content.filter { ".!?;:".contains($0) }.count
        let emphasisCount = content.filter { "!?".contains($0) }.count
        let lengthSignal = max(0, 1 - abs(Double(wordCount) - 42) / 42)
        let sentenceSignal = min(1, Double(sentenceCount) / max(1, Double(wordCount) / 18))
        let structureSignal = min(1, 0.35 + Double(punctuationCount) / max(1, Double(wordCount) / 6))
        let listSignal = min(1, Double(bulletCount + 1) / Double(lineCount + 1))
        let penalty = min(0.24, Double(max(0, emphasisCount - 2)) * 0.05)
        return max(0.12, min(1, 0.2 + (lengthSignal * 0.32) + (sentenceSignal * 0.22) + (structureSignal * 0.18) + (listSignal * 0.14) - penalty))
    }

    nonisolated private static func inferType(content: String, orderedTokens: [String], wordCount: Int) -> NotesInferredType {
        let lowered = content.lowercased()
        let bulletCount = lowered.components(separatedBy: .newlines).filter {
            let trimmed = $0.trimmingCharacters(in: .whitespaces)
            return trimmed.hasPrefix("-") || trimmed.hasPrefix("*") || trimmed.hasPrefix("•")
        }.count
        let questionCount = lowered.filter { $0 == "?" }.count
        let firstPersonMatches = orderedTokens.filter { ["i", "me", "my", "myself"].contains($0) }.count
        let reflectionMarkers = orderedTokens.filter { ["felt", "realized", "noticed", "learned", "processing", "remembered", "today", "yesterday"].contains($0) }.count
        let planningMarkers = orderedTokens.filter { ["plan", "next", "tomorrow", "need", "should", "schedule", "prepare", "goal", "follow", "ship"].contains($0) }.count
        let ideaMarkers = orderedTokens.filter { ["idea", "maybe", "could", "build", "prototype", "experiment", "concept", "explore", "imagine"].contains($0) }.count

        var scores: [NotesInferredType: Double] = [
            .quickCapture: wordCount <= 24 ? 2.6 : 0.5,
            .reflection: Double(reflectionMarkers * 2 + firstPersonMatches) + (wordCount >= 40 ? 1.2 : 0),
            .planning: Double(planningMarkers * 2) + Double(bulletCount) * 1.4 + (lowered.contains("need to") ? 1.2 : 0),
            .idea: Double(ideaMarkers * 2) + Double(questionCount) * 0.8 + (lowered.contains("what if") ? 1.4 : 0),
        ]

        if wordCount <= 18 && bulletCount == 0 {
            scores[.quickCapture, default: 0] += 1
        }
        if lowered.contains("check") || lowered.contains("tomorrow") {
            scores[.planning, default: 0] += 0.8
        }
        if lowered.contains("i think") || lowered.contains("what if") {
            scores[.idea, default: 0] += 0.8
        }

        return scores.max(by: { $0.value < $1.value })?.key ?? .quickCapture
    }

    private static func timeSegment(for date: Date?) -> NotesTimeSegment? {
        guard let date else {
            return nil
        }
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5..<8:
            return .early
        case 8..<12:
            return .morning
        case 12..<17:
            return .afternoon
        case 17..<22:
            return .evening
        default:
            return .late
        }
    }

    nonisolated private static func tokenize(content: String) -> [String] {
        content
            .lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    nonisolated private static func cleanKeyword(_ raw: String) -> String {
        var keyword = raw
            .lowercased()
            .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        for suffix in ["ing", "ed", "ly", "s"] where keyword.count > 4 && keyword.hasSuffix(suffix) {
            keyword.removeLast(suffix.count)
            break
        }
        return keyword
    }

    private static func themeRoot(for term: String) -> String {
        term
            .split(separator: " ")
            .map { cleanKeyword(String($0)) }
            .joined(separator: "-")
    }

    private static func humanizedTheme(_ term: String) -> String {
        term
            .split(separator: " ")
            .map { token in
                token.prefix(1).uppercased() + token.dropFirst()
            }
            .joined(separator: " ")
    }

    private static func share(of type: NotesInferredType, within notes: [NotesAnalyzedNote]) -> Double {
        guard !notes.isEmpty else {
            return 0
        }
        return Double(notes.filter { $0.inferredType == type }.count) / Double(notes.count)
    }

    nonisolated public static func derivedReflectionTags(
        content: String,
        sentiment: ReflectionSentiment,
        existing: [String]
    ) -> [String] {
        let orderedTokens = tokenize(content: content)
        var tags = Set(existing.map(cleanKeyword).filter { !$0.isEmpty })
        let inferredType = inferType(content: content, orderedTokens: orderedTokens, wordCount: orderedTokens.count)
        tags.insert(inferredType.rawValue.replacingOccurrences(of: "_", with: "-"))

        for token in orderedTokens.map(cleanKeyword).filter({ $0.count > 2 && !stopWords.contains($0) }).prefix(8) {
            tags.insert(token)
        }
        for pair in orderedTokens.adjacentPairs().prefix(6) {
            let first = cleanKeyword(pair.0)
            let second = cleanKeyword(pair.1)
            guard first.count > 2, second.count > 2,
                  !stopWords.contains(first), !stopWords.contains(second) else {
                continue
            }
            tags.insert("\(first)-\(second)")
        }

        switch sentiment {
        case .great:
            tags.insert("positive-momentum")
        case .focused:
            tags.insert("clear-focus")
        case .tired:
            tags.insert("low-energy")
        case .stressed:
            tags.insert("high-pressure")
        case .okay:
            break
        }

        return tags.sorted()
    }

    nonisolated private static let stopWords: Set<String> = [
        "a", "about", "after", "again", "all", "also", "am", "an", "and", "any", "are", "as", "at",
        "be", "because", "been", "before", "being", "but", "by", "can", "did", "do", "does", "down",
        "for", "from", "had", "has", "have", "how", "i", "if", "in", "into", "is", "it", "its",
        "just", "more", "my", "no", "not", "of", "on", "or", "out", "over", "really", "so", "some",
        "still", "that", "the", "their", "them", "then", "there", "these", "they", "this", "to",
        "today", "too", "up", "was", "we", "went", "were", "what", "when", "which", "while", "with",
        "would", "you", "your"
    ]

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }()

    private static let isoDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private extension Array where Element == Double {
    var average: Double? {
        guard !isEmpty else {
            return nil
        }
        return reduce(0, +) / Double(count)
    }

    var standardDeviation: Double {
        guard count > 1, let average else {
            return 0
        }
        let variance = reduce(0) { partial, value in
            partial + pow(value - average, 2)
        } / Double(count)
        return sqrt(variance)
    }
}

private extension Sequence {
    func groupedCounts<Key: Hashable>(by keyPath: KeyPath<Element, Key>) -> [Key: Int] {
        reduce(into: [Key: Int]()) { partial, element in
            partial[element[keyPath: keyPath], default: 0] += 1
        }
    }
}

private extension Array {
    func adjacentPairs() -> [(Element, Element)] {
        guard count > 1 else {
            return []
        }
        return zip(self, dropFirst()).map { ($0, $1) }
    }
}

public protocol NotificationPreferenceApplier: Sendable {
    func apply(preferences: UserPreferences) async -> NotificationScheduleStatus
    func status() async -> NotificationScheduleStatus?
}

public struct NoopNotificationPreferenceApplier: NotificationPreferenceApplier {
    public init() {}

    public func apply(preferences: UserPreferences) async -> NotificationScheduleStatus {
        NotificationScheduleStatus(
            permissionGranted: false,
            scheduledCount: 0,
            lastRefreshedAt: Date(),
            lastError: "Notification scheduling is unavailable."
        )
    }

    public func status() async -> NotificationScheduleStatus? {
        nil
    }
}

public actor LiveNotificationPreferenceApplier: NotificationPreferenceApplier {
    public static let preferenceKey = "one.notification.preferences"
    public static let statusKey = "one.notification.schedule.status"

    private let defaults: UserDefaults
    private let apiClient: APIClient
    private let notificationService: LocalNotificationService

    public init(
        apiClient: APIClient,
        notificationService: LocalNotificationService,
        defaults: UserDefaults = .standard
    ) {
        self.apiClient = apiClient
        self.notificationService = notificationService
        self.defaults = defaults
    }

    public func apply(preferences: UserPreferences) async -> NotificationScheduleStatus {
        if let data = try? JSONEncoder().encode(preferences) {
            defaults.set(data, forKey: Self.preferenceKey)
        } else {
            defaults.removeObject(forKey: Self.preferenceKey)
        }

        do {
            let habits = try await apiClient.fetchHabits()
            let todos = try await apiClient.fetchTodos()
            let result = await notificationService.refresh(
                habits: habits,
                todos: todos,
                preferences: preferences
            )
            if let data = try? JSONEncoder().encode(result) {
                defaults.set(data, forKey: Self.statusKey)
            }
            return result
        } catch {
            let fallback = NotificationScheduleStatus(
                permissionGranted: false,
                scheduledCount: 0,
                lastRefreshedAt: Date(),
                lastError: userFacingError(error)
            )
            if let data = try? JSONEncoder().encode(fallback) {
                defaults.set(data, forKey: Self.statusKey)
            }
            return fallback
        }
    }

    public func status() async -> NotificationScheduleStatus? {
        guard let raw = defaults.data(forKey: Self.statusKey) else {
            return nil
        }
        return try? JSONDecoder().decode(NotificationScheduleStatus.self, from: raw)
    }
}

@MainActor
public final class ProfileViewModel: ObservableObject, NotificationScheduleRefresher {
    @Published public private(set) var user: User?
    @Published public private(set) var preferences: UserPreferences?
    @Published public private(set) var notificationStatus: NotificationScheduleStatus?
    @Published public private(set) var errorMessage: String?

    private let repository: ProfileRepository
    private let applier: NotificationPreferenceApplier

    public init(repository: ProfileRepository, applier: NotificationPreferenceApplier = NoopNotificationPreferenceApplier()) {
        self.repository = repository
        self.applier = applier
    }

    public func load() async {
        do {
            async let loadedUser = repository.loadProfile()
            async let loadedPreferences = repository.loadPreferences()
            let nextUser = try await loadedUser
            let nextPreferences = try await loadedPreferences
            withAnimation(OneMotion.animation(.calmRefresh)) {
                user = nextUser
                preferences = nextPreferences
            }
            notificationStatus = await applier.status()
            errorMessage = nil
        } catch {
            errorMessage = userFacingError(error)
        }
    }

    public func refreshSchedules() async {
        guard let preferences else {
            return
        }
        let refreshedStatus = await applier.apply(preferences: preferences)
        withAnimation(OneMotion.animation(.calmRefresh)) {
            notificationStatus = refreshedStatus
        }
    }

    @discardableResult
    public func saveProfile(displayName: String) async -> Bool {
        do {
            let updatedUser = try await repository.updateProfile(
                UserProfileUpdateInput(
                    displayName: displayName,
                    timezone: TimeZone.autoupdatingCurrent.identifier
                )
            )
            withAnimation(OneMotion.animation(.stateChange)) {
                user = updatedUser
            }
            OneHaptics.shared.trigger(.saveSucceeded)
            OneSyncFeedbackCenter.shared.showSynced(
                title: "Name saved",
                message: "Your profile is updated on this device."
            )
            errorMessage = nil
            return true
        } catch {
            OneHaptics.shared.trigger(.saveFailed)
            errorMessage = userFacingError(error)
            return false
        }
    }

    @discardableResult
    public func savePreferences(input: UserPreferencesUpdateInput) async -> Bool {
        do {
            let updated = try await repository.updatePreferences(input)
            withAnimation(OneMotion.animation(.stateChange)) {
                preferences = updated
            }
            notificationStatus = await applier.apply(preferences: updated)
            OneHaptics.shared.trigger(.saveSucceeded)
            OneSyncFeedbackCenter.shared.showSynced(
                title: "Preferences saved",
                message: "Your latest settings are stored on this device."
            )
            errorMessage = nil
            return true
        } catch {
            OneHaptics.shared.trigger(.saveFailed)
            errorMessage = userFacingError(error)
            return false
        }
    }
}
