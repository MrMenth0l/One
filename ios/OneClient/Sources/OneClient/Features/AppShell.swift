#if canImport(SwiftUI)
import SwiftUI
import Combine
#if canImport(SwiftData)
import SwiftData
#endif

@MainActor
public final class OneAppContainer: ObservableObject {
    public let authViewModel: AuthViewModel
    public let tasksViewModel: TasksViewModel
    public let todayViewModel: TodayViewModel
    public let analyticsViewModel: AnalyticsViewModel
    public let profileViewModel: ProfileViewModel
    public let coachViewModel: CoachViewModel
    public let reflectionsViewModel: ReflectionsViewModel
    public let notesViewModel: NotesViewModel
    public let fatalStartupMessage: String?
    private var cancellables: Set<AnyCancellable> = []

    public init(
        authRepository: AuthRepository,
        tasksRepository: TasksRepository,
        todayRepository: TodayRepository,
        analyticsRepository: AnalyticsRepository,
        reflectionsRepository: ReflectionsRepository,
        profileRepository: ProfileRepository,
        coachRepository: CoachRepository,
        notificationApplier: NotificationPreferenceApplier = NoopNotificationPreferenceApplier(),
        fatalStartupMessage: String? = nil
    ) {
        let profileViewModel = ProfileViewModel(repository: profileRepository, applier: notificationApplier)
        let reflectionsViewModel = ReflectionsViewModel(repository: reflectionsRepository)
        let notesViewModel = NotesViewModel(repository: reflectionsRepository)
        self.authViewModel = AuthViewModel(repository: authRepository)
        self.tasksViewModel = TasksViewModel(repository: tasksRepository, scheduleRefresher: profileViewModel)
        self.todayViewModel = TodayViewModel(repository: todayRepository)
        self.analyticsViewModel = AnalyticsViewModel(
            repository: analyticsRepository,
            reflectionsRepository: reflectionsRepository
        )
        self.profileViewModel = profileViewModel
        self.coachViewModel = CoachViewModel(repository: coachRepository)
        self.reflectionsViewModel = reflectionsViewModel
        self.notesViewModel = notesViewModel
        self.fatalStartupMessage = fatalStartupMessage
        bindChildViewModels()
    }

    public static func live(environment: AppEnvironment = .current()) -> OneAppContainer {
        _ = environment
        let sessionStore: AuthSessionStore
        #if canImport(Security)
        sessionStore = KeychainAuthSessionStore()
        #else
        sessionStore = InMemoryAuthSessionStore()
        #endif

        let apiClient: APIClient
        let syncQueue: SyncQueue
        var fatalStartupMessage: String?

        #if canImport(SwiftData)
        do {
            let stack = try LocalPersistenceFactory.makeStored(sessionStore: sessionStore)
            apiClient = stack.apiClient
            syncQueue = stack.syncQueue
        } catch {
            fatalStartupMessage = "Local data store is unavailable. Restart the app and try again."
            apiClient = LocalModeUnavailableAPIClient(
                sessionStore: sessionStore,
                message: fatalStartupMessage ?? "Local data store is unavailable."
            )
            syncQueue = InMemorySyncQueue()
        }
        #else
        fatalStartupMessage = "Local data store is unavailable. Restart the app and try again."
        apiClient = LocalModeUnavailableAPIClient(
            sessionStore: sessionStore,
            message: fatalStartupMessage ?? "Local data store is unavailable."
        )
        syncQueue = InMemorySyncQueue()
        #endif

        let notificationService: LocalNotificationService
        #if canImport(UserNotifications) && os(iOS)
        notificationService = UserNotificationCenterService()
        #else
        notificationService = NoopLocalNotificationService()
        #endif

        let notificationApplier = LiveNotificationPreferenceApplier(
            apiClient: apiClient,
            notificationService: notificationService
        )

        return OneAppContainer(
            authRepository: DefaultAuthRepository(apiClient: apiClient),
            tasksRepository: DefaultTasksRepository(apiClient: apiClient, syncQueue: syncQueue),
            todayRepository: DefaultTodayRepository(apiClient: apiClient, syncQueue: syncQueue),
            analyticsRepository: DefaultAnalyticsRepository(apiClient: apiClient),
            reflectionsRepository: DefaultReflectionsRepository(apiClient: apiClient),
            profileRepository: DefaultProfileRepository(apiClient: apiClient),
            coachRepository: DefaultCoachRepository(apiClient: apiClient),
            notificationApplier: notificationApplier,
            fatalStartupMessage: fatalStartupMessage
        )
    }

    public func bootstrap(anchorDate: String) async {
        await authViewModel.bootstrap()
        guard authViewModel.user != nil else {
            return
        }
        await refreshAll(anchorDate: anchorDate)
    }

    public func refreshAll(anchorDate: String) async {
        await profileViewModel.load()
        await tasksViewModel.loadCategories()
        await tasksViewModel.loadTasks()
        await todayViewModel.load(date: anchorDate)
        await reflectionsViewModel.load(periodType: .daily)
        await coachViewModel.load()
        await refreshAnalytics(anchorDate: anchorDate)
        await profileViewModel.refreshSchedules()
    }

    public func refreshTasksContext(anchorDate: String) async {
        await tasksViewModel.loadTasks()
        await todayViewModel.load(date: anchorDate)
        await refreshAnalytics(anchorDate: anchorDate)
        await profileViewModel.refreshSchedules()
    }

    public func refreshAnalytics(anchorDate: String) async {
        let weekStart = profileViewModel.preferences?.weekStart ?? 0
        await analyticsViewModel.loadWeekly(anchorDate: anchorDate, weekStart: weekStart)
        if analyticsViewModel.selectedPeriod != .weekly {
            await analyticsViewModel.loadPeriod(
                anchorDate: anchorDate,
                periodType: analyticsViewModel.selectedPeriod,
                weekStart: weekStart
            )
        }
    }

    public func refreshDailyReflections() async {
        await reflectionsViewModel.load(periodType: .daily)
    }

    private func bindChildViewModels() {
        observe(authViewModel)
        observe(tasksViewModel)
        observe(todayViewModel)
        observe(analyticsViewModel)
        observe(profileViewModel)
        observe(coachViewModel)
        observe(reflectionsViewModel)
        observe(notesViewModel)
    }

    private func observe<Object: ObservableObject>(_ object: Object)
    where Object.ObjectWillChangePublisher == ObservableObjectPublisher {
        object.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
}

private actor LocalModeUnavailableAPIClient: APIClient {
    private let sessionStore: AuthSessionStore
    private let message: String

    init(
        sessionStore: AuthSessionStore,
        message: String = "Local data store is unavailable."
    ) {
        self.sessionStore = sessionStore
        self.message = message
    }

    func currentSession() async -> AuthSessionTokens? {
        await sessionStore.setRecoverySuppressed(true)
        await sessionStore.clear()
        return nil
    }

    func clearSession() async {
        await sessionStore.setRecoverySuppressed(true)
        await sessionStore.clear()
    }

    func login(email: String, password: String) async throws -> AuthSession {
        try await fail()
    }

    func signup(email: String, password: String, displayName: String, timezone: String) async throws -> AuthSession {
        try await fail()
    }

    func fetchMe() async throws -> User {
        try await fail()
    }

    func fetchCategories() async throws -> [Category] {
        try await fail()
    }

    func fetchHabits() async throws -> [Habit] {
        try await fail()
    }

    func fetchTodos() async throws -> [Todo] {
        try await fail()
    }

    func fetchCoachCards() async throws -> [CoachCard] {
        try await fail()
    }

    func createHabit(input: HabitCreateInput) async throws -> Habit {
        try await fail()
    }

    func createTodo(input: TodoCreateInput) async throws -> Todo {
        try await fail()
    }

    func fetchToday(date: String?) async throws -> TodayResponse {
        try await fail()
    }

    func putTodayOrder(dateLocal: String, items: [TodayOrderItem]) async throws -> TodayResponse {
        try await fail()
    }

    func updateCompletion(itemType: ItemType, itemId: String, dateLocal: String, state: CompletionState) async throws {
        let _: Void = try await fail()
    }

    func fetchDaily(startDate: String, endDate: String) async throws -> [DailySummary] {
        try await fail()
    }

    func fetchPeriod(anchorDate: String, periodType: PeriodType) async throws -> PeriodSummary {
        try await fail()
    }

    func fetchHabitStats(habitId: String, anchorDate: String?, windowDays: Int?) async throws -> HabitStats {
        try await fail()
    }

    func fetchReflections(periodType: PeriodType?) async throws -> [ReflectionNote] {
        try await fail()
    }

    func upsertReflection(input: ReflectionWriteInput) async throws -> ReflectionNote {
        try await fail()
    }

    func deleteReflection(id: String) async throws {
        let _: Void = try await fail()
    }

    func fetchPreferences() async throws -> UserPreferences {
        try await fail()
    }

    func patchPreferences(input: UserPreferencesUpdateInput) async throws -> UserPreferences {
        try await fail()
    }

    func patchUser(input: UserProfileUpdateInput) async throws -> User {
        try await fail()
    }

    func patchHabit(id: String, input: HabitUpdateInput, clientUpdatedAt: Date?) async throws -> Habit {
        try await fail()
    }

    func patchTodo(id: String, fields: [String : String], clientUpdatedAt: Date?) async throws -> Todo {
        try await fail()
    }

    func patchTodo(id: String, input: TodoUpdateInput, clientUpdatedAt: Date?) async throws -> Todo {
        try await fail()
    }

    func deleteHabit(id: String) async throws {
        let _: Void = try await fail()
    }

    func deleteTodo(id: String) async throws {
        let _: Void = try await fail()
    }

    private func fail<T>() async throws -> T {
        throw APIError.transport(message)
    }
}

public struct OneAppShell: View {
    @StateObject private var container: OneAppContainer
    @AppStorage("one.onboarding.completed") private var onboardingCompleted = false
    @State private var selectedTab: Tab = .today
    @State private var activeSheet: SheetRoute?
    @State private var didBootstrap = false
    @State private var isBootstrapping = true

    public init(container: OneAppContainer = OneAppContainer.live()) {
        _container = StateObject(wrappedValue: container)
    }

    private var currentAnchorDate: String {
        OneDate.isoDate()
    }

    public var body: some View {
        Group {
            if let fatalStartupMessage = container.fatalStartupMessage {
                BlockingStartupView(message: fatalStartupMessage)
            } else if isBootstrapping {
                SplashView()
            } else if !onboardingCompleted {
                OnboardingFlowView {
                    onboardingCompleted = true
                    selectedTab = .today
                }
            } else if container.authViewModel.user == nil {
                LocalProfileSetupView(viewModel: container.authViewModel)
            } else {
                MainTabsView(
                    selectedTab: $selectedTab,
                    activeSheet: $activeSheet,
                    container: container,
                    onSelectTab: { selectedTab = $0 },
                    onRefreshTasksContext: {
                        await container.refreshTasksContext(anchorDate: currentAnchorDate)
                    },
                    onRefreshAnalytics: {
                        await container.refreshAnalytics(anchorDate: currentAnchorDate)
                    },
                    onRefreshReflections: {
                        await container.refreshDailyReflections()
                    }
                )
            }
        }
        .preferredColorScheme(OneTheme.preferredColorScheme(from: container.profileViewModel.preferences?.theme))
        .tint(OneTheme.palette(for: OneTheme.preferredColorScheme(from: container.profileViewModel.preferences?.theme) ?? .light).accent)
        .sheet(item: $activeSheet) { route in
            switch route {
            case .addHabit:
                HabitFormSheet(categories: container.tasksViewModel.categories) { input in
                    if await container.tasksViewModel.createHabit(input: input) != nil {
                        await container.refreshTasksContext(anchorDate: currentAnchorDate)
                        activeSheet = nil
                    }
                } onCancel: {
                    activeSheet = nil
                }
            case .addTodo:
                TodoFormSheet(categories: container.tasksViewModel.categories) { input in
                    if await container.tasksViewModel.createTodo(input: input) != nil {
                        await container.refreshTasksContext(anchorDate: currentAnchorDate)
                        activeSheet = nil
                    }
                } onCancel: {
                    activeSheet = nil
                }
            case .notifications:
                NotificationPreferencesView(profileViewModel: container.profileViewModel) {
                    activeSheet = nil
                }
            case .coach:
                CoachSheetView(viewModel: container.coachViewModel) {
                    activeSheet = nil
                }
            case .habitCategory(let categoryId):
                HabitCategorySheetView(
                    categoryId: categoryId,
                    tasksViewModel: container.tasksViewModel,
                    anchorDate: currentAnchorDate,
                    onDismiss: {
                        activeSheet = nil
                    },
                    onSave: {
                        await container.refreshTasksContext(anchorDate: currentAnchorDate)
                    }
                )
            case .notes(let anchorDate, let periodType):
                NotesSheetView(
                    viewModel: container.notesViewModel,
                    initialAnchorDate: anchorDate,
                    initialPeriod: periodType,
                    weekStart: container.profileViewModel.preferences?.weekStart ?? 0,
                    onDismiss: {
                        activeSheet = nil
                    },
                    onRefreshAnalytics: {
                        await container.refreshAnalytics(anchorDate: currentAnchorDate)
                    },
                    onRefreshReflections: {
                        await container.refreshDailyReflections()
                    }
                )
            }
        }
        .task {
            guard !didBootstrap, container.fatalStartupMessage == nil else {
                return
            }
            didBootstrap = true
            await container.bootstrap(anchorDate: currentAnchorDate)
            isBootstrapping = false
        }
        .onChange(of: container.authViewModel.user?.id) { _, newUserID in
            guard !isBootstrapping else {
                return
            }
            Task {
                if newUserID != nil {
                    selectedTab = .today
                    await container.refreshAll(anchorDate: currentAnchorDate)
                } else {
                    selectedTab = .today
                    activeSheet = nil
                }
            }
        }
    }

    enum Tab: Hashable {
        case home
        case today
        case analytics
        case profile
    }

    enum SheetRoute: Identifiable {
        case addHabit
        case addTodo
        case notifications
        case coach
        case habitCategory(categoryId: String)
        case notes(anchorDate: String, periodType: PeriodType)

        var id: String {
            switch self {
            case .addHabit:
                return "addHabit"
            case .addTodo:
                return "addTodo"
            case .notifications:
                return "notifications"
            case .coach:
                return "coach"
            case .habitCategory(let categoryId):
                return "habit-category-\(categoryId)"
            case .notes(let anchorDate, let periodType):
                return "notes-\(periodType.rawValue)-\(anchorDate)"
            }
        }
    }
}

private struct MainTabsView: View {
    @Binding var selectedTab: OneAppShell.Tab
    @Binding var activeSheet: OneAppShell.SheetRoute?
    @ObservedObject var container: OneAppContainer
    let onSelectTab: (OneAppShell.Tab) -> Void
    let onRefreshTasksContext: () async -> Void
    let onRefreshAnalytics: () async -> Void
    let onRefreshReflections: () async -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var palette: OneTheme.Palette {
        OneTheme.palette(for: colorScheme)
    }

    private var currentDateLocal: String {
        OneDate.isoDate()
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeTabView(
                user: container.profileViewModel.user,
                tasksViewModel: container.tasksViewModel,
                todayViewModel: container.todayViewModel,
                analyticsViewModel: container.analyticsViewModel,
                coachViewModel: container.coachViewModel,
                currentDateLocal: currentDateLocal,
                onFocusToday: { onSelectTab(.today) },
                onOpenSheet: { activeSheet = $0 }
            )
            .tabItem { Label("Home", systemImage: "house") }
            .tag(OneAppShell.Tab.home)

            TodayTabView(
                todayViewModel: container.todayViewModel,
                tasksViewModel: container.tasksViewModel,
                reflectionsViewModel: container.reflectionsViewModel,
                currentDateLocal: currentDateLocal,
                onOpenSheet: { activeSheet = $0 },
                onRefreshTasksContext: onRefreshTasksContext,
                onRefreshAnalytics: onRefreshAnalytics,
                onRefreshReflections: onRefreshReflections
            )
            .tabItem { Label("Today", systemImage: "checklist") }
            .tag(OneAppShell.Tab.today)

            AnalyticsTabView(
                viewModel: container.analyticsViewModel,
                currentDateLocal: currentDateLocal,
                onSelectPeriod: { periodType in
                    await container.analyticsViewModel.loadPeriod(
                        anchorDate: currentDateLocal,
                        periodType: periodType,
                        weekStart: container.profileViewModel.preferences?.weekStart ?? 0
                    )
                },
                onOpenNotes: { dateLocal in
                    activeSheet = .notes(anchorDate: dateLocal, periodType: .daily)
                }
            )
            .tabItem { Label("Analytics", systemImage: "chart.bar.xaxis") }
            .tag(OneAppShell.Tab.analytics)

            ProfileTabView(
                authViewModel: container.authViewModel,
                profileViewModel: container.profileViewModel,
                coachViewModel: container.coachViewModel,
                onOpenSheet: { activeSheet = $0 }
            )
            .tabItem { Label("Profile", systemImage: "person") }
            .tag(OneAppShell.Tab.profile)
        }
        .tint(palette.accent)
    }
}

private struct SplashView: View {
    @Environment(\.colorScheme) private var colorScheme

    private var palette: OneTheme.Palette {
        OneTheme.palette(for: colorScheme)
    }

    var body: some View {
        ZStack {
            OneScreenBackground(palette: palette)
            VStack(spacing: 20) {
                OneMarkBadge(palette: palette)
                OneGlassCard(palette: palette, padding: 24) {
                    VStack(spacing: 10) {
                        Text("One")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(palette.text)
                        Text("Daily execution first")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(palette.subtext)
                        Text("Habits, priorities, and notes in one calm daily system.")
                            .font(.system(size: 13, weight: .medium))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(palette.subtext)
                    }
                }
                .frame(maxWidth: 320)
            }
            .padding(24)
        }
    }
}

private struct BlockingStartupView: View {
    let message: String
    @Environment(\.colorScheme) private var colorScheme

    private var palette: OneTheme.Palette {
        OneTheme.palette(for: colorScheme)
    }

    var body: some View {
        ZStack {
            OneScreenBackground(palette: palette)
            VStack(spacing: 20) {
                OneMarkBadge(palette: palette)
                OneGlassCard(palette: palette, padding: 24) {
                    VStack(spacing: 12) {
                        Text("Local data unavailable")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(palette.text)
                        Text(message)
                            .font(.system(size: 14, weight: .medium))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(palette.subtext)
                    }
                }
                .frame(maxWidth: 340)
            }
            .padding(24)
        }
    }
}

private struct OnboardingFlowView: View {
    let onComplete: () -> Void
    @State private var page = 0
    @Environment(\.colorScheme) private var colorScheme

    private struct PageContent {
        let title: String
        let body: String
        let chips: [String]
    }

    private let pages: [PageContent] = [
        PageContent(
            title: "Build momentum every day",
            body: "Keep habits, priorities, and notes together in one clear daily system.",
            chips: ["Habits", "Quick Notes"]
        ),
        PageContent(
            title: "Stay focused today",
            body: "See what matters now, clear it, and keep the day moving.",
            chips: ["Today", "Priorities"]
        ),
        PageContent(
            title: "Review the longer arc",
            body: "Track progress, mood, and consistency across the week, month, and year.",
            chips: ["Analytics", "History", "Coach"]
        ),
    ]

    private var palette: OneTheme.Palette {
        OneTheme.palette(for: colorScheme)
    }

    var body: some View {
        ZStack {
            OneScreenBackground(palette: palette)
            VStack(spacing: 20) {
                Spacer(minLength: 40)
                OneMarkBadge(palette: palette)
                OneGlassCard(palette: palette, padding: 22) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(pages[page].title)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(palette.text)
                        Text(pages[page].body)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(palette.subtext)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 8) {
                            ForEach(pages[page].chips, id: \.self) { chip in
                                OneChip(palette: palette, title: chip, kind: .strong)
                            }
                        }
                    }
                }
                .frame(maxWidth: 340)
                HStack(spacing: 8) {
                    ForEach(Array(pages.indices), id: \.self) { index in
                        Capsule(style: .continuous)
                            .fill(index == page ? palette.text : palette.border)
                            .frame(width: index == page ? 28 : 8, height: 8)
                    }
                }
                Spacer()
                VStack(spacing: 10) {
                    OneActionButton(
                        palette: palette,
                        title: page == pages.count - 1 ? "Get Started" : "Continue",
                        style: .primary
                    ) {
                        if page == pages.count - 1 {
                            onComplete()
                        } else {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                page += 1
                            }
                        }
                    }
                    if page > 0 {
                        OneActionButton(palette: palette, title: "Back", style: .secondary) {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                page -= 1
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
    }
}

private struct LocalProfileSetupView: View {
    @ObservedObject var viewModel: AuthViewModel
    @State private var displayName = ""
    @Environment(\.colorScheme) private var colorScheme

    private var palette: OneTheme.Palette {
        OneTheme.palette(for: colorScheme)
    }

    private var localProfileCandidate: User? {
        viewModel.localProfileCandidate
    }

    private var deviceTimezoneID: String {
        OneDate.deviceTimeZoneIdentifier
    }

    var body: some View {
        OneScrollScreen(palette: palette, bottomPadding: 36) {
            VStack(spacing: 18) {
                VStack(spacing: 14) {
                    OneMarkBadge(palette: palette)
                    Text(localProfileCandidate == nil ? "Set up One" : "Welcome back")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.text)
                    Text(localProfileCandidate == nil
                         ? "Set up your profile once and keep using One on this device."
                         : "Your profile and data are still on this device. Continue to pick up where you left off.")
                        .font(.system(size: 14, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(palette.subtext)
                }
                .padding(.top, 28)

                OneGlassCard(palette: palette) {
                    if let localProfileCandidate {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(localProfileCandidate.displayName)
                                .font(.system(size: 21, weight: .bold, design: .rounded))
                                .foregroundStyle(palette.text)
                            HStack(spacing: 8) {
                                OneChip(palette: palette, title: deviceTimezoneID, kind: .strong)
                                OneChip(palette: palette, title: "Data saved locally", kind: .neutral)
                            }
                            Text("Continue with this saved profile. One follows this device's time automatically.")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(palette.subtext)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } else {
                        OneField(title: "Display Name", text: $displayName, placeholder: "How should One address you?")
                        Text("Using device time automatically: \(deviceTimezoneID)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(palette.subtext)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if let message = viewModel.errorMessage {
                    InlineStatusCard(message: message, kind: .danger, palette: palette)
                }

                if let localProfileCandidate {
                    OneActionButton(
                        palette: palette,
                        title: "Continue as \(localProfileCandidate.displayName)",
                        style: .primary
                    ) {
                        Task {
                            await viewModel.resumeLocalProfile()
                        }
                    }
                    .disabled(viewModel.isLoading)
                } else {
                    OneActionButton(palette: palette, title: "Continue", style: .primary) {
                        Task {
                            await viewModel.createLocalProfile(
                                displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                        }
                    }
                    .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
                }
            }
        }
        .onAppear {
            guard let localProfileCandidate else {
                return
            }
            displayName = localProfileCandidate.displayName
        }
    }
}

private struct HomeTabView: View {
    let user: User?
    @ObservedObject var tasksViewModel: TasksViewModel
    @ObservedObject var todayViewModel: TodayViewModel
    @ObservedObject var analyticsViewModel: AnalyticsViewModel
    @ObservedObject var coachViewModel: CoachViewModel
    let currentDateLocal: String
    let onFocusToday: () -> Void
    let onOpenSheet: (OneAppShell.SheetRoute) -> Void

    @State private var isQuickActionsExpanded = false
    @Environment(\.colorScheme) private var colorScheme

    private var palette: OneTheme.Palette {
        OneTheme.palette(for: colorScheme)
    }

    private var urgentItem: TodayItem? {
        todayViewModel.items.first(where: { ($0.isPinned ?? false) && !$0.completed })
    }

    private var habitCategoryGroups: [HomeHabitCategoryGroup] {
        let sortedCategories = tasksViewModel.categories.sorted {
            if $0.sortOrder != $1.sortOrder {
                return $0.sortOrder < $1.sortOrder
            }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        let groupedHabits = Dictionary(grouping: tasksViewModel.habits.filter(\.isActive), by: \.categoryId)
        let orderedGroups = sortedCategories.compactMap { category -> HomeHabitCategoryGroup? in
            guard let habits = groupedHabits[category.id], !habits.isEmpty else {
                return nil
            }
            return HomeHabitCategoryGroup(
                categoryId: category.id,
                categoryName: category.name,
                categoryIcon: actionQueueCategoryIcon(name: category.name, storedIcon: category.icon),
                habits: habits.sorted {
                    $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }
            )
        }
        let knownCategoryIDs = Set(sortedCategories.map(\.id))
        let fallbackGroups = groupedHabits
            .filter { !knownCategoryIDs.contains($0.key) && !$0.value.isEmpty }
            .map { categoryId, habits in
                HomeHabitCategoryGroup(
                    categoryId: categoryId,
                    categoryName: "Other",
                    categoryIcon: "◻️",
                    habits: habits.sorted {
                        $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                    }
                )
            }
            .sorted {
                $0.categoryName.localizedCaseInsensitiveCompare($1.categoryName) == .orderedAscending
            }

        return orderedGroups + fallbackGroups
    }

    private var previewItems: [TodayItem] {
        Array(todayViewModel.items.prefix(3))
    }

    private var featuredCoachCard: CoachCard? {
        guard !coachViewModel.cards.isEmpty else {
            return nil
        }
        let seed = currentDateLocal.unicodeScalars.reduce(into: 0) { partial, scalar in
            partial += Int(scalar.value)
        }
        return coachViewModel.cards[seed % coachViewModel.cards.count]
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                OneScrollScreen(palette: palette) {
                    OneHeroHeader(
                        palette: palette,
                        title: "Home",
                        subtitle: "Your day at a glance."
                    ) {
                        OneAvatarBadge(
                            palette: palette,
                            initials: OneDate.initials(from: user?.displayName ?? "One")
                        )
                    }

                    OneGlassCard(palette: palette) {
                        HStack(alignment: .center, spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Today snapshot")
                                    .font(.system(size: 21, weight: .bold, design: .rounded))
                                    .foregroundStyle(palette.text)
                                Text("\(todayViewModel.completedCount) of \(todayViewModel.totalCount) items done")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(palette.subtext)
                                HStack(spacing: 8) {
                                    OneChip(palette: palette, title: "\(Int(todayViewModel.completionRatio * 100))% complete", kind: .strong)
                                    if urgentItem != nil {
                                        OneChip(palette: palette, title: "Urgent queued", kind: .danger)
                                    }
                                }
                            }
                            Spacer()
                            OneProgressCluster(
                                palette: palette,
                                progress: todayViewModel.completionRatio,
                                label: "\(Int(todayViewModel.completionRatio * 100))%"
                            )
                        }
                    }

                    OneSurfaceCard(palette: palette) {
                        OneSectionHeading(palette: palette, title: "Coach snippet", meta: "Secondary support")
                        if let card = featuredCoachCard {
                            Text(card.title)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(palette.text)
                            Text(card.body)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(palette.subtext)
                                .fixedSize(horizontal: false, vertical: true)
                            CoachVerseBlock(palette: palette, card: card)
                        } else {
                            Text("Coach guidance appears here.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(palette.subtext)
                        }
                        OneActionButton(palette: palette, title: "Coach", style: .secondary) {
                            onOpenSheet(.coach)
                        }
                    }

                    OneSurfaceCard(palette: palette) {
                        OneSectionHeading(palette: palette, title: "Weekly lane", meta: analyticsViewModel.weekly?.periodStart ?? "")
                        if analyticsViewModel.weeklyDailySummaries.isEmpty {
                            Text("A few completed days will populate this view.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(palette.subtext)
                        } else {
                            OneActivityLane(
                                palette: palette,
                                values: analyticsViewModel.weeklyDailySummaries.map(\.completionRate),
                                labels: analyticsViewModel.weeklyDailySummaries.map { OneDate.shortWeekday(from: $0.dateLocal) },
                                highlightIndex: analyticsViewModel.weeklyDailySummaries.lastIndex(where: { $0.dateLocal == currentDateLocal })
                            )
                            HStack(spacing: 10) {
                                SummaryMetricTile(palette: palette, title: "Completed", value: "\(analyticsViewModel.weekly?.completedItems ?? 0)")
                                SummaryMetricTile(palette: palette, title: "Consistency", value: "\(Int((analyticsViewModel.weekly?.consistencyScore ?? 0) * 100))%")
                                SummaryMetricTile(palette: palette, title: "Active Days", value: "\(analyticsViewModel.weekly?.activeDays ?? 0)")
                            }
                        }
                    }

                    OneSurfaceCard(palette: palette) {
                        OneSectionHeading(
                            palette: palette,
                            title: "Current habits",
                            meta: habitCategoryGroups.isEmpty ? "Nothing active yet" : "\(habitCategoryGroups.count) categories"
                        )
                        if habitCategoryGroups.isEmpty {
                            EmptyStateCard(
                                palette: palette,
                                title: "No active habits yet",
                                message: "Create a habit to see it here."
                            )
                        } else {
                            VStack(spacing: 10) {
                                ForEach(habitCategoryGroups) { group in
                                    Button {
                                        onOpenSheet(.habitCategory(categoryId: group.categoryId))
                                    } label: {
                                        HomeHabitCategoryGroupRow(
                                            palette: palette,
                                            group: group
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    if let urgentItem {
                        OneSurfaceCard(palette: palette) {
                            OneSectionHeading(palette: palette, title: "Pinned urgent item", meta: urgentItem.itemType == .todo ? "Todo" : "Habit")
                            HStack(alignment: .center, spacing: 12) {
                                Circle()
                                    .fill(palette.danger.opacity(0.16))
                                    .frame(width: 42, height: 42)
                                    .overlay(
                                        Image(systemName: "pin.fill")
                                            .foregroundStyle(palette.danger)
                                    )
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(urgentItem.title)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(palette.text)
                                    Text(urgentItem.subtitle ?? "Stays at the top of Today until it is done.")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(palette.subtext)
                                }
                                Spacer()
                                Button("Open Today") {
                                    onFocusToday()
                                }
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(palette.accent)
                            }
                        }
                    }

                    OneSurfaceCard(palette: palette) {
                        OneSectionHeading(palette: palette, title: "Today lane", meta: previewItems.isEmpty ? "No actions yet" : "Next up")
                        if previewItems.isEmpty {
                            EmptyStateCard(
                                palette: palette,
                                title: "Nothing scheduled yet",
                                message: "Today's habits and todos will appear here."
                            )
                        } else {
                            VStack(spacing: 10) {
                                ForEach(previewItems) { item in
                                    CompactTodayPreviewRow(palette: palette, item: item)
                                }
                            }
                        }
                    }

                    Color.clear
                        .frame(height: 92)
                }

                HomeQuickActionsFAB(
                    palette: palette,
                    isExpanded: $isQuickActionsExpanded,
                    onFocusToday: {
                        isQuickActionsExpanded = false
                        onFocusToday()
                    },
                    onAddHabit: {
                        isQuickActionsExpanded = false
                        onOpenSheet(.addHabit)
                    },
                    onAddTodo: {
                        isQuickActionsExpanded = false
                        onOpenSheet(.addTodo)
                    }
                )
                .padding(.trailing, 18)
                .padding(.bottom, 24)
            }
            .oneNavigationBarHidden()
        }
    }
}

private struct TodayTabView: View {
    @ObservedObject var todayViewModel: TodayViewModel
    @ObservedObject var tasksViewModel: TasksViewModel
    @ObservedObject var reflectionsViewModel: ReflectionsViewModel
    let currentDateLocal: String
    let onOpenSheet: (OneAppShell.SheetRoute) -> Void
    let onRefreshTasksContext: () async -> Void
    let onRefreshAnalytics: () async -> Void
    let onRefreshReflections: () async -> Void

    @State private var inlineReflection = ""
    @State private var selectedQuickNoteSentiment: ReflectionSentiment?
    @State private var isReordering = false
    @State private var isActionQueueExpanded = false
    @State private var isCompletedSectionExpanded = true
    @State private var pendingDeleteNote: ReflectionNote?
    @FocusState private var isQuickNoteEditorFocused: Bool
    #if os(iOS)
    @State private var editMode: EditMode = .inactive
    #endif
    @Environment(\.colorScheme) private var colorScheme

    private var palette: OneTheme.Palette {
        OneTheme.palette(for: colorScheme)
    }

    private var dateLocal: String {
        todayViewModel.dateLocal.isEmpty ? currentDateLocal : todayViewModel.dateLocal
    }

    private var dailyQuickNotes: [ReflectionNote] {
        reflectionsViewModel.notes.filter { $0.periodType == .daily && $0.periodStart == dateLocal }
    }

    private var dailyQuickNoteSummary: ReflectionSentimentVoteSummary {
        reflectionSentimentSummary(for: dailyQuickNotes)
    }

    private var activeItems: [TodayItem] {
        todayViewModel.items.filter { !$0.completed }
    }

    private var collapsedActionQueueLimit: Int {
        3
    }

    private var shouldCollapseActionQueue: Bool {
        !isReordering && activeItems.count > collapsedActionQueueLimit
    }

    private var visibleActiveItems: [TodayItem] {
        guard shouldCollapseActionQueue, !isActionQueueExpanded else {
            return activeItems
        }
        return Array(activeItems.prefix(collapsedActionQueueLimit))
    }

    private var hiddenActiveItemCount: Int {
        max(activeItems.count - visibleActiveItems.count, 0)
    }

    private var actionQueueMeta: String {
        if isReordering {
            return "Drag to persist order"
        }
        if hiddenActiveItemCount > 0 {
            return "\(hiddenActiveItemCount) more hidden"
        }
        return "Tap to complete"
    }

    private var completedItems: [TodayItem] {
        todayViewModel.items.filter(\.completed)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OneScreenBackground(palette: palette)
                List {
                    rowSurface {
                        OneHeroHeader(
                            palette: palette,
                            title: "Today",
                            subtitle: OneDate.longDate(from: dateLocal)
                        ) {
                            Button(isReordering ? "Done" : "Reorder") {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isReordering.toggle()
                                    if isReordering {
                                        isActionQueueExpanded = true
                                    }
                                    #if os(iOS)
                                    editMode = isReordering ? .active : .inactive
                                    #endif
                                }
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(palette.accent)
                        }
                    }

                    rowSurface {
                        OneGlassCard(palette: palette) {
                            HStack(alignment: .center, spacing: 14) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Daily execution")
                                        .font(.system(size: 21, weight: .bold, design: .rounded))
                                        .foregroundStyle(palette.text)
                                    Text("\(todayViewModel.completedCount) of \(todayViewModel.totalCount) actions complete")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(palette.subtext)
                                    HStack(spacing: 8) {
                                        OneChip(palette: palette, title: "\(todayViewModel.completedCount) done", kind: .success)
                                        OneChip(palette: palette, title: "\(max(todayViewModel.totalCount - todayViewModel.completedCount, 0)) left", kind: .neutral)
                                    }
                                }
                                Spacer()
                                OneProgressCluster(
                                    palette: palette,
                                    progress: todayViewModel.completionRatio,
                                    label: "\(Int(todayViewModel.completionRatio * 100))%"
                                )
                            }
                        }
                    }

                    rowSurface {
                        HStack {
                            OneSectionHeading(palette: palette, title: "Action queue", meta: actionQueueMeta)
                            Spacer()
                            if activeItems.count > collapsedActionQueueLimit && !isReordering {
                                Button(isActionQueueExpanded ? "Show less" : "Show all") {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isActionQueueExpanded.toggle()
                                    }
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(palette.accent)
                            }
                        }
                    }

                    if todayViewModel.items.isEmpty {
                        rowSurface {
                            EmptyStateCard(
                                palette: palette,
                                title: "Nothing for today",
                                message: "Add a habit or todo. Today is intentionally the execution surface once something exists."
                            )
                        }
                    } else {
                        ForEach(visibleActiveItems) { item in
                            rowSurface {
                                TodayItemCard(
                                    palette: palette,
                                    item: item,
                                    categoryName: categoryName(for: item.categoryId),
                                    categoryIcon: categoryIcon(for: item.categoryId),
                                    isReordering: isReordering,
                                    onToggle: {
                                        Task {
                                            await todayViewModel.toggle(item: item, dateLocal: dateLocal)
                                            await onRefreshAnalytics()
                                        }
                                    }
                                ) {
                                    if item.itemType == .habit {
                                        HabitDetailView(
                                            habitId: item.itemId,
                                            tasksViewModel: tasksViewModel,
                                            anchorDate: dateLocal,
                                            onSave: {
                                                await onRefreshTasksContext()
                                            }
                                        )
                                    } else {
                                        TodoDetailView(
                                            todoId: item.itemId,
                                            tasksViewModel: tasksViewModel,
                                            onSave: {
                                                await onRefreshTasksContext()
                                            }
                                        )
                                    }
                                }
                            }
                        }
                        .onMove { source, destination in
                            var reordered = activeItems
                            reordered.move(fromOffsets: source, toOffset: destination)
                            Task {
                                await todayViewModel.reorder(items: reordered, dateLocal: dateLocal)
                            }
                        }

                        if hiddenActiveItemCount > 0 && !isReordering {
                            rowSurface {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isActionQueueExpanded = true
                                    }
                                } label: {
                                    OneSurfaceCard(palette: palette) {
                                        HStack(spacing: 12) {
                                            Circle()
                                                .fill(palette.surfaceStrong)
                                                .frame(width: 34, height: 34)
                                                .overlay(
                                                    Image(systemName: "ellipsis.circle.fill")
                                                        .font(.system(size: 16, weight: .semibold))
                                                        .foregroundStyle(palette.accent)
                                                )
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Show \(hiddenActiveItemCount) more action\(hiddenActiveItemCount == 1 ? "" : "s")")
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundStyle(palette.text)
                                                Text("Open the full queue when you want the entire list.")
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundStyle(palette.subtext)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.down.circle.fill")
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundStyle(palette.accent)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if !completedItems.isEmpty {
                            rowSurface {
                                OneSurfaceCard(palette: palette) {
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            isCompletedSectionExpanded.toggle()
                                        }
                                    } label: {
                                        HStack(spacing: 12) {
                                            OneSectionHeading(
                                                palette: palette,
                                                title: "Completed Today",
                                                meta: "\(completedItems.count)"
                                            )
                                            Spacer()
                                            Image(systemName: isCompletedSectionExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundStyle(palette.accent)
                                        }
                                    }
                                    .buttonStyle(.plain)

                                    if isCompletedSectionExpanded {
                                        VStack(spacing: 10) {
                                            ForEach(completedItems) { item in
                                                TodayItemCard(
                                                    palette: palette,
                                                    item: item,
                                                    categoryName: categoryName(for: item.categoryId),
                                                    categoryIcon: categoryIcon(for: item.categoryId),
                                                    isReordering: false,
                                                    onToggle: {
                                                        Task {
                                                            await todayViewModel.toggle(item: item, dateLocal: dateLocal)
                                                            await onRefreshAnalytics()
                                                        }
                                                    }
                                                ) {
                                                    if item.itemType == .habit {
                                                        HabitDetailView(
                                                            habitId: item.itemId,
                                                            tasksViewModel: tasksViewModel,
                                                            anchorDate: dateLocal,
                                                            onSave: {
                                                                await onRefreshTasksContext()
                                                            }
                                                        )
                                                    } else {
                                                        TodoDetailView(
                                                            todoId: item.itemId,
                                                            tasksViewModel: tasksViewModel,
                                                            onSave: {
                                                                await onRefreshTasksContext()
                                                            }
                                                        )
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    rowSurface {
                        OneSurfaceCard(palette: palette) {
                            HStack(alignment: .top, spacing: 12) {
                                OneSectionHeading(
                                    palette: palette,
                                    title: "Quick Notes",
                                    meta: dailyQuickNoteSummary.dominant?.title ?? "Today"
                                )
                                Spacer()
                                Button("Open Notes") {
                                    onOpenSheet(.notes(anchorDate: dateLocal, periodType: .daily))
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(palette.accent)
                            }
                            OneTextEditorField(
                                title: "Capture what moved the day",
                                text: $inlineReflection,
                                placeholder: "What worked? What blocked you? What changed the day?",
                                isFocused: $isQuickNoteEditorFocused
                            )
                            SentimentPickerRow(
                                palette: palette,
                                selectedSentiment: $selectedQuickNoteSentiment
                            )
                            OneActionButton(palette: palette, title: "Save Quick Note", style: .primary) {
                                Task {
                                    guard let selectedQuickNoteSentiment else {
                                        return
                                    }
                                    if await reflectionsViewModel.upsert(
                                        input: ReflectionWriteInput(
                                            periodType: .daily,
                                            periodStart: dateLocal,
                                            periodEnd: dateLocal,
                                            content: inlineReflection,
                                            sentiment: selectedQuickNoteSentiment
                                        )
                                    ) != nil {
                                        inlineReflection = ""
                                        self.selectedQuickNoteSentiment = nil
                                        isQuickNoteEditorFocused = false
                                        await onRefreshReflections()
                                        await onRefreshAnalytics()
                                    }
                                }
                            }
                            .disabled(
                                inlineReflection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                selectedQuickNoteSentiment == nil
                            )

                            if dailyQuickNotes.isEmpty {
                                Text("Saved notes for today appear here.")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(palette.subtext)
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(dailyQuickNotes) { note in
                                        QuickNoteRow(
                                            palette: palette,
                                            note: note,
                                            onDelete: {
                                                pendingDeleteNote = note
                                            }
                                        )
                                    }
                                }
                            }
                        }
                    }

                    if let message = tasksViewModel.errorMessage ?? todayViewModel.errorMessage {
                        rowSurface {
                            InlineStatusCard(message: message, kind: .danger, palette: palette)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .oneListRowSpacing(10)
                #if os(iOS)
                .oneListEditing(editMode: $editMode)
                #endif
            }
            .oneNavigationBarHidden()
            .confirmationDialog(
                "Delete this quick note?",
                isPresented: Binding(
                    get: { pendingDeleteNote != nil },
                    set: { isPresented in
                        if !isPresented {
                            pendingDeleteNote = nil
                        }
                    }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete Note", role: .destructive) {
                    guard let note = pendingDeleteNote else {
                        return
                    }
                    Task {
                        if await reflectionsViewModel.delete(id: note.id) {
                            pendingDeleteNote = nil
                            await onRefreshAnalytics()
                        }
                    }
                }
                Button("Cancel", role: .cancel) {
                    pendingDeleteNote = nil
                }
            } message: {
                Text("This removes the note and its sentiment from your history.")
            }
            .safeAreaInset(edge: .bottom) {
                if !isQuickNoteEditorFocused {
                    OneGlassCard(palette: palette, padding: 10) {
                        HStack(spacing: 10) {
                            OneActionButton(palette: palette, title: "Add Habit", style: .secondary) {
                                onOpenSheet(.addHabit)
                            }
                            OneActionButton(palette: palette, title: "Add Todo", style: .primary) {
                                onOpenSheet(.addTodo)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .background(Color.clear)
                }
            }
            #if os(iOS)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isQuickNoteEditorFocused = false
                    }
                }
            }
            #endif
        }
    }

    private func categoryName(for categoryId: String) -> String {
        tasksViewModel.categories.first(where: { $0.id == categoryId })?.name ?? "Category"
    }

    private func categoryIcon(for categoryId: String) -> String {
        let category = tasksViewModel.categories.first(where: { $0.id == categoryId })
        return actionQueueCategoryIcon(name: category?.name ?? "Category", storedIcon: category?.icon)
    }

    @ViewBuilder
    private func rowSurface<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

private struct AnalyticsTabView: View {
    @ObservedObject var viewModel: AnalyticsViewModel
    let currentDateLocal: String
    let onSelectPeriod: (PeriodType) async -> Void
    let onOpenNotes: (String) -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var palette: OneTheme.Palette {
        OneTheme.palette(for: colorScheme)
    }

    private let periodOptions: [PeriodType] = [.weekly, .monthly, .yearly]

    var body: some View {
        NavigationStack {
            OneScrollScreen(palette: palette) {
                OneHeroHeader(
                    palette: palette,
                    title: "Analytics",
                    subtitle: "Progress, mood, and daily history."
                ) {
                    HStack(spacing: 10) {
                        OneChip(palette: palette, title: periodTitle(viewModel.selectedPeriod), kind: .strong)
                        Menu {
                            ForEach(AnalyticsActivityFilter.allCases, id: \.self) { filter in
                                Button(filter.title) {
                                    viewModel.selectActivityFilter(filter)
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(palette.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }

                OneGlassCard(palette: palette) {
                    OneSegmentedControl(
                        palette: palette,
                        options: periodOptions,
                        selection: viewModel.selectedPeriod,
                        title: { periodTitle($0) }
                    ) { selection in
                        Task {
                            await onSelectPeriod(selection)
                        }
                    }
                }

                if let summary = viewModel.summary ?? viewModel.weekly {
                    OneGlassCard(palette: palette) {
                        OneSectionHeading(
                            palette: palette,
                            title: periodTitle(summary.periodType) + " summary",
                            meta: viewModel.selectedActivityFilter.title
                        )
                        HStack(spacing: 10) {
                            SummaryMetricTile(palette: palette, title: "Completed", value: "\(summary.completedItems)")
                            SummaryMetricTile(palette: palette, title: "Expected", value: "\(summary.expectedItems)")
                            SummaryMetricTile(palette: palette, title: "Rate", value: "\(Int(summary.completionRate * 100))%")
                        }
                        HStack(spacing: 10) {
                            SummaryMetricTile(palette: palette, title: "Consistency", value: "\(Int(summary.consistencyScore * 100))%")
                            SummaryMetricTile(palette: palette, title: "Active Days", value: "\(summary.activeDays)")
                            SummaryMetricTile(palette: palette, title: "Window", value: summary.periodEnd)
                        }
                    }
                }

                OneSurfaceCard(palette: palette) {
                    OneSectionHeading(
                        palette: palette,
                        title: "Completion lane",
                        meta: viewModel.selectedPeriod == .monthly
                            ? (viewModel.selectedMonthWeekDetailLabel ?? periodTitle(viewModel.selectedPeriod))
                            : periodTitle(viewModel.selectedPeriod)
                    )
                    if viewModel.chartSeries.values.isEmpty {
                        Text("Complete a few tasks to populate this view.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(palette.subtext)
                    } else {
                        OneActivityLane(
                            palette: palette,
                            values: viewModel.chartSeries.values,
                            labels: viewModel.chartSeries.labels,
                            highlightIndex: chartHighlightIndex,
                            onSelectIndex: viewModel.selectedPeriod == .monthly ? { index in
                                viewModel.selectMonthWeek(index + 1)
                            } : nil
                        )
                    }
                }

                OneSurfaceCard(palette: palette) {
                    OneSectionHeading(
                        palette: palette,
                        title: "Contribution history",
                        meta: contributionMeta
                    )
                    if viewModel.dailySummaries.isEmpty {
                        Text("Your history will appear here.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(palette.subtext)
                    } else {
                        if viewModel.selectedPeriod == .yearly {
                            AnalyticsYearContributionView(
                                palette: palette,
                                sections: viewModel.contributionSections,
                                onSelectDate: onOpenNotes
                            )
                        } else {
                            AnalyticsContributionGrid(
                                palette: palette,
                                summaries: viewModel.dailySummaries,
                                onSelectDate: onOpenNotes
                            )
                        }
                    }
                }

                if let sentimentOverview = viewModel.sentimentOverview {
                    OneSurfaceCard(palette: palette) {
                        OneSectionHeading(palette: palette, title: "Sentiment", meta: sentimentOverview.dominant?.title ?? "No dominant mood")
                        AnalyticsSentimentOverviewView(
                            palette: palette,
                            periodType: viewModel.selectedPeriod,
                            overview: sentimentOverview,
                            highlightedDates: viewModel.selectedPeriod == .monthly ? Set(viewModel.dailySummaries.map(\.dateLocal)) : [],
                            onOpenDate: onOpenNotes
                        )
                    }
                }

                if let message = viewModel.errorMessage {
                    InlineStatusCard(message: message, kind: .danger, palette: palette)
                }
            }
            .oneNavigationBarHidden()
        }
    }

    private var chartHighlightIndex: Int? {
        switch viewModel.selectedPeriod {
        case .weekly:
            return viewModel.dailySummaries.lastIndex(where: { $0.dateLocal == currentDateLocal })
        case .monthly:
            guard let selectedMonthWeek = viewModel.selectedMonthWeek else {
                return nil
            }
            return max(0, selectedMonthWeek - 1)
        case .yearly:
            return viewModel.chartSeries.labels.indices.last
        case .daily:
            return nil
        }
    }

    private var contributionMeta: String {
        switch viewModel.selectedPeriod {
        case .weekly:
            return "Full selected week"
        case .monthly:
            return viewModel.selectedMonthWeekDetailLabel ?? "Selected week"
        case .yearly:
            return "Full year"
        case .daily:
            return "Selected day"
        }
    }

    private func periodTitle(_ period: PeriodType) -> String {
        switch period {
        case .weekly:
            return "Week"
        case .monthly:
            return "Month"
        case .yearly:
            return "Year"
        case .daily:
            return "Day"
        }
    }
}

private struct NotesSheetView: View {
    @ObservedObject var viewModel: NotesViewModel
    let initialAnchorDate: String
    let initialPeriod: PeriodType
    let weekStart: Int
    let onDismiss: () -> Void
    let onRefreshAnalytics: () async -> Void
    let onRefreshReflections: () async -> Void

    @State private var pendingDeleteNote: ReflectionNote?
    @Environment(\.colorScheme) private var colorScheme

    private let periodOptions: [PeriodType] = [.daily, .weekly, .monthly, .yearly]

    private var palette: OneTheme.Palette {
        OneTheme.palette(for: colorScheme)
    }

    var body: some View {
        NavigationStack {
            OneScrollScreen(palette: palette) {
                OneHeroHeader(
                    palette: palette,
                    title: "Notes",
                    subtitle: viewModel.currentRangeTitle
                ) {
                    Button("Done") {
                        onDismiss()
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.accent)
                }

                OneGlassCard(palette: palette) {
                    OneSegmentedControl(
                        palette: palette,
                        options: periodOptions,
                        selection: viewModel.selectedPeriod,
                        title: { notesPeriodTitle($0) }
                    ) { period in
                        viewModel.selectPeriod(period)
                    }
                }

                OneSurfaceCard(palette: palette) {
                    HStack(spacing: 14) {
                        Button {
                            viewModel.moveSelection(by: -1)
                        } label: {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(palette.accent)
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.currentRangeTitle)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(palette.text)
                            Text(viewModel.selectedDayTitle)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(palette.subtext)
                        }

                        Spacer()

                        Button {
                            viewModel.moveSelection(by: 1)
                        } label: {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(palette.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let summary = viewModel.sentimentSummary {
                    OneSurfaceCard(palette: palette) {
                        OneSectionHeading(
                            palette: palette,
                            title: "Period summary",
                            meta: summary.dominant.map { "\($0.emoji) \($0.title)" } ?? "No clear mood"
                        )
                        HStack(spacing: 10) {
                            SummaryMetricTile(palette: palette, title: "Notes", value: "\(summary.noteCount)")
                            SummaryMetricTile(palette: palette, title: "Active Days", value: "\(summary.activeDays)")
                            SummaryMetricTile(
                                palette: palette,
                                title: "Mood",
                                value: summary.dominant?.emoji ?? "·"
                            )
                        }
                        if !summary.distribution.isEmpty {
                            FlowLayout(spacing: 8) {
                                ForEach(summary.distribution) { item in
                                    OneChip(
                                        palette: palette,
                                        title: "\(item.sentiment.emoji) \(item.count)",
                                        kind: item.sentiment.chipKind
                                    )
                                }
                            }
                        }
                    }
                }

                OneSurfaceCard(palette: palette) {
                    switch viewModel.selectedPeriod {
                    case .daily:
                        NotesFocusedDayCard(
                            palette: palette,
                            option: viewModel.dayOptions.first,
                            selectedDateLocal: viewModel.selectedDateLocal
                        ) { dateLocal in
                            viewModel.selectDay(dateLocal)
                        }
                    case .weekly:
                        NotesDayStrip(
                            palette: palette,
                            options: viewModel.dayOptions,
                            selectedDateLocal: viewModel.selectedDateLocal
                        ) { dateLocal in
                            viewModel.selectDay(dateLocal)
                        }
                    case .monthly:
                        NotesCalendarGridView(
                            palette: palette,
                            options: viewModel.dayOptions,
                            leadingPlaceholders: viewModel.leadingPlaceholders,
                            selectedDateLocal: viewModel.selectedDateLocal
                        ) { dateLocal in
                            viewModel.selectDay(dateLocal)
                        }
                    case .yearly:
                        VStack(alignment: .leading, spacing: 16) {
                            NotesMonthPickerView(
                                palette: palette,
                                options: viewModel.monthOptions,
                                selectedMonth: viewModel.selectedYearMonth
                            ) { month in
                                viewModel.selectMonth(month)
                            }
                            NotesCalendarGridView(
                                palette: palette,
                                options: viewModel.dayOptions,
                                leadingPlaceholders: viewModel.leadingPlaceholders,
                                selectedDateLocal: viewModel.selectedDateLocal
                            ) { dateLocal in
                                viewModel.selectDay(dateLocal)
                            }
                        }
                    }
                }

                OneSurfaceCard(palette: palette) {
                    OneSectionHeading(
                        palette: palette,
                        title: "Selected day",
                        meta: viewModel.selectedDayTitle
                    )

                    if viewModel.selectedDayNotes.isEmpty {
                        EmptyStateCard(
                            palette: palette,
                            title: "No notes for this day",
                            message: "Choose another day or capture a note from Today."
                        )
                    } else {
                        VStack(spacing: 10) {
                            ForEach(viewModel.selectedDayNotes) { note in
                                QuickNoteRow(
                                    palette: palette,
                                    note: note,
                                    onDelete: {
                                        pendingDeleteNote = note
                                    }
                                )
                            }
                        }
                    }
                }

                if let message = viewModel.errorMessage {
                    InlineStatusCard(message: message, kind: .danger, palette: palette)
                }
            }
            .oneNavigationBarHidden()
            .task(id: "\(initialAnchorDate)-\(initialPeriod.rawValue)-\(weekStart)") {
                await viewModel.load(
                    anchorDate: initialAnchorDate,
                    periodType: initialPeriod,
                    weekStart: weekStart,
                    forceReload: true
                )
            }
            .confirmationDialog(
                "Delete this note?",
                isPresented: Binding(
                    get: { pendingDeleteNote != nil },
                    set: { isPresented in
                        if !isPresented {
                            pendingDeleteNote = nil
                        }
                    }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete Note", role: .destructive) {
                    guard let note = pendingDeleteNote else {
                        return
                    }
                    Task {
                        if await viewModel.delete(id: note.id) {
                            pendingDeleteNote = nil
                            await onRefreshReflections()
                            await onRefreshAnalytics()
                        }
                    }
                }
                Button("Cancel", role: .cancel) {
                    pendingDeleteNote = nil
                }
            } message: {
                Text("This removes the note and its sentiment from your history.")
            }
        }
    }

    private func notesPeriodTitle(_ period: PeriodType) -> String {
        switch period {
        case .daily:
            return "Day"
        case .weekly:
            return "Week"
        case .monthly:
            return "Month"
        case .yearly:
            return "Year"
        }
    }
}

private struct NotesFocusedDayCard: View {
    let palette: OneTheme.Palette
    let option: NotesDayOption?
    let selectedDateLocal: String
    let onSelect: (String) -> Void

    var body: some View {
        if let option {
            Button {
                onSelect(option.dateLocal)
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(option.weekdayLabel.uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(palette.subtext)
                        Text("\(option.dayNumber)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(palette.text)
                    }
                    Spacer()
                    Text(option.sentiment?.emoji ?? "·")
                        .font(.system(size: 28))
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: OneTheme.radiusMedium, style: .continuous)
                        .fill(option.dateLocal == selectedDateLocal ? palette.accentSoft : palette.surfaceMuted)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: OneTheme.radiusMedium, style: .continuous)
                        .stroke(option.dateLocal == selectedDateLocal ? palette.accent : palette.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }
}

private struct NotesDayStrip: View {
    let palette: OneTheme.Palette
    let options: [NotesDayOption]
    let selectedDateLocal: String
    let onSelect: (String) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options) { option in
                Button {
                    onSelect(option.dateLocal)
                } label: {
                    VStack(spacing: 6) {
                        Text(option.weekdayLabel.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(option.dateLocal == selectedDateLocal ? palette.text : palette.subtext)
                        Text("\(option.dayNumber)")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(palette.text)
                        Text(option.sentiment?.emoji ?? "·")
                            .font(.system(size: 16))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: OneTheme.radiusMedium, style: .continuous)
                            .fill(option.dateLocal == selectedDateLocal ? palette.accentSoft : palette.surfaceMuted)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: OneTheme.radiusMedium, style: .continuous)
                            .stroke(option.dateLocal == selectedDateLocal ? palette.accent : palette.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct NotesMonthPickerView: View {
    let palette: OneTheme.Palette
    let options: [NotesMonthOption]
    let selectedMonth: Int
    let onSelect: (Int) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(options) { option in
                Button {
                    onSelect(option.month)
                } label: {
                    VStack(spacing: 4) {
                        Text(option.label)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(palette.text)
                        Text(option.dominant?.emoji ?? "·")
                            .font(.system(size: 16))
                        Text("\(option.noteCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(palette.subtext)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: OneTheme.radiusMedium, style: .continuous)
                            .fill(option.month == selectedMonth ? palette.accentSoft : palette.surfaceMuted)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: OneTheme.radiusMedium, style: .continuous)
                            .stroke(option.month == selectedMonth ? palette.accent : palette.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct NotesCalendarGridView: View {
    let palette: OneTheme.Palette
    let options: [NotesDayOption]
    let leadingPlaceholders: Int
    let selectedDateLocal: String
    let onSelect: (String) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(palette.subtext)
                    .frame(maxWidth: .infinity)
            }

            ForEach(0..<leadingPlaceholders, id: \.self) { _ in
                Color.clear
                    .frame(height: 48)
            }

            ForEach(options) { option in
                Button {
                    onSelect(option.dateLocal)
                } label: {
                    VStack(spacing: 4) {
                        Text("\(option.dayNumber)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(palette.text)
                        Text(option.sentiment?.emoji ?? (option.hasNotes ? "•" : " "))
                            .font(.system(size: 13))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(option.dateLocal == selectedDateLocal ? palette.accentSoft : palette.surfaceMuted)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(option.dateLocal == selectedDateLocal ? palette.accent : palette.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct ProfileTabView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @ObservedObject var profileViewModel: ProfileViewModel
    @ObservedObject var coachViewModel: CoachViewModel
    let onOpenSheet: (OneAppShell.SheetRoute) -> Void

    @State private var displayName = ""
    @State private var selectedTheme: Theme = .system
    @Environment(\.colorScheme) private var colorScheme

    private var palette: OneTheme.Palette {
        OneTheme.palette(for: colorScheme)
    }

    private var deviceTimezoneID: String {
        OneDate.deviceTimeZoneIdentifier
    }

    var body: some View {
        NavigationStack {
            OneScrollScreen(palette: palette) {
                OneHeroHeader(
                    palette: palette,
                    title: "Profile",
                    subtitle: "Profile, appearance, and notifications."
                ) {
                    OneAvatarBadge(
                        palette: palette,
                        initials: OneDate.initials(from: profileViewModel.user?.displayName ?? "One")
                    )
                }

                OneGlassCard(palette: palette) {
                    OneField(title: "Display Name", text: $displayName, placeholder: "Your name")
                    Text("Using device time: \(deviceTimezoneID)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(palette.subtext)
                        .fixedSize(horizontal: false, vertical: true)
                    OneActionButton(palette: palette, title: "Save Profile", style: .primary) {
                        Task {
                            await profileViewModel.saveProfile(displayName: displayName)
                        }
                    }
                }

                OneSurfaceCard(palette: palette) {
                    OneSectionHeading(palette: palette, title: "Appearance", meta: "Theme")
                    OneSegmentedControl(
                        palette: palette,
                        options: [Theme.system, .light, .dark],
                        selection: selectedTheme,
                        title: { theme in
                            switch theme {
                            case .system: return "System"
                            case .light: return "Light"
                            case .dark: return "Dark"
                            }
                        }
                    ) { theme in
                        selectedTheme = theme
                    }
                    OneActionButton(palette: palette, title: "Apply Theme", style: .secondary) {
                        Task {
                            await profileViewModel.savePreferences(
                                input: UserPreferencesUpdateInput(theme: selectedTheme)
                            )
                        }
                    }
                }

                OneSurfaceCard(palette: palette) {
                    OneSectionHeading(palette: palette, title: "Settings", meta: "Shortcuts")
                    Button {
                        onOpenSheet(.notifications)
                    } label: {
                        OneSettingsRow(
                            palette: palette,
                            icon: "bell.badge",
                            title: "Notification Preferences",
                            meta: notificationMeta,
                            tail: nil
                        )
                    }
                    .buttonStyle(.plain)

                    Divider().overlay(palette.border)

                    Button {
                        onOpenSheet(.coach)
                    } label: {
                        OneSettingsRow(
                            palette: palette,
                            icon: "sparkles",
                            title: "Coach",
                            meta: "Verse guidance and daily perspective",
                            tail: coachViewModel.cards.first?.verseRef
                        )
                    }
                    .buttonStyle(.plain)
                }

                OneSurfaceCard(palette: palette) {
                    Button(role: .destructive) {
                        Task {
                            await authViewModel.logout()
                        }
                    } label: {
                        HStack {
                            Text("Sign Out")
                                .font(.system(size: 15, weight: .semibold))
                            Spacer()
                            Image(systemName: "arrow.right.square")
                        }
                        .foregroundStyle(palette.danger)
                    }
                    .buttonStyle(.plain)
                    Text("Signing out closes this session but keeps your data on this device.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(palette.subtext)
                }

                if let message = profileViewModel.errorMessage {
                    InlineStatusCard(message: message, kind: .danger, palette: palette)
                }
            }
            .oneNavigationBarHidden()
            .onAppear {
                hydrateFromLoadedData()
            }
            .onChange(of: profileViewModel.user?.id) { _, _ in
                hydrateFromLoadedData()
            }
            .onChange(of: profileViewModel.preferences?.theme) { _, _ in
                hydrateFromLoadedData()
            }
        }
    }

    private func hydrateFromLoadedData() {
        if let user = profileViewModel.user {
            displayName = user.displayName
        }
        if let preferences = profileViewModel.preferences {
            selectedTheme = preferences.theme
        }
    }

    private var notificationMeta: String {
        guard let status = profileViewModel.notificationStatus else {
            return "Schedule reminders, quiet hours, and prompts"
        }
        let permission = status.permissionGranted ? "granted" : "off"
        return "\(status.scheduledCount) scheduled · permission \(permission)"
    }

}

private struct HabitFormSheet: View {
    let categories: [Category]
    let onSave: (HabitCreateInput) async -> Void
    let onCancel: () -> Void

    @State private var title = ""
    @State private var selectedCategoryID = ""
    @State private var notes = ""
    @State private var recurrence = HabitRecurrenceRule()
    @State private var priorityWeight = 50.0
    @State private var preferredTime = ""
    @Environment(\.colorScheme) private var colorScheme

    private var palette: OneTheme.Palette {
        OneTheme.palette(for: colorScheme)
    }

    var body: some View {
        NavigationStack {
            OneScrollScreen(palette: palette, bottomPadding: 148) {
                OneHeroHeader(
                    palette: palette,
                    title: "New Habit",
                    subtitle: "Create a habit for the rhythm you want."
                ) {
                    OneChip(palette: palette, title: "Habit", kind: .strong)
                }

                OneGlassCard(palette: palette) {
                    OneField(title: "Title", text: $title, placeholder: "Morning workout")
                    PickerCard(
                        palette: palette,
                        title: "Category",
                        selection: $selectedCategoryID,
                        options: categories.map { ($0.id, $0.name) }
                    )
                    RecurrenceBuilderCard(palette: palette, recurrence: $recurrence)
                    OneTextEditorField(title: "Notes", text: $notes, placeholder: "Optional context")
                    SliderCard(palette: palette, title: "Priority Weight", value: $priorityWeight, range: 0...100)
                    OneField(title: "Preferred Time", text: $preferredTime, placeholder: "06:30")
                }
            }
            .safeAreaInset(edge: .bottom) {
                OneGlassCard(palette: palette, padding: 10) {
                    VStack(spacing: 10) {
                        OneActionButton(palette: palette, title: "Save Habit", style: .primary) {
                            Task {
                                await onSave(
                                    HabitCreateInput(
                                        categoryId: selectedCategoryID,
                                        title: title,
                                        notes: notes,
                                        recurrenceRule: recurrence.rawValue,
                                        priorityWeight: Int(priorityWeight),
                                        preferredTime: preferredTime.isEmpty ? nil : preferredTime
                                    )
                                )
                            }
                        }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedCategoryID.isEmpty)

                        OneActionButton(palette: palette, title: "Cancel", style: .secondary) {
                            onCancel()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .oneNavigationBarHidden()
            .onAppear {
                if selectedCategoryID.isEmpty {
                    selectedCategoryID = categories.first?.id ?? ""
                }
            }
        }
    }
}

private struct TodoFormSheet: View {
    let categories: [Category]
    let onSave: (TodoCreateInput) async -> Void
    let onCancel: () -> Void

    @State private var title = ""
    @State private var notes = ""
    @State private var selectedCategoryID = ""
    @State private var priority = 50.0
    @State private var isPinned = false
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @Environment(\.colorScheme) private var colorScheme

    private var palette: OneTheme.Palette {
        OneTheme.palette(for: colorScheme)
    }

    var body: some View {
        NavigationStack {
            OneScrollScreen(palette: palette, bottomPadding: 148) {
                OneHeroHeader(
                    palette: palette,
                    title: "New Todo",
                    subtitle: "Capture one-off work that matters."
                ) {
                    OneChip(palette: palette, title: "Todo", kind: .strong)
                }

                OneGlassCard(palette: palette) {
                    OneField(title: "Title", text: $title, placeholder: "Submit project draft")
                    PickerCard(
                        palette: palette,
                        title: "Category",
                        selection: $selectedCategoryID,
                        options: categories.map { ($0.id, $0.name) }
                    )
                    OneTextEditorField(title: "Notes", text: $notes, placeholder: "Optional context")
                    SliderCard(palette: palette, title: "Priority", value: $priority, range: 0...100)
                    ToggleCard(palette: palette, title: "Pin as urgent", subtitle: "Places the todo above habits in Today.", isOn: $isPinned)
                    ToggleCard(palette: palette, title: "Set due date", subtitle: "Makes urgency visible in Today.", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePickerCard(palette: palette, title: "Due date", selection: $dueDate)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                OneGlassCard(palette: palette, padding: 10) {
                    VStack(spacing: 10) {
                        OneActionButton(palette: palette, title: "Save Todo", style: .primary) {
                            Task {
                                await onSave(
                                    TodoCreateInput(
                                        categoryId: selectedCategoryID,
                                        title: title,
                                        notes: notes,
                                        dueAt: hasDueDate ? dueDate : nil,
                                        priority: Int(priority),
                                        isPinned: isPinned
                                    )
                                )
                            }
                        }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedCategoryID.isEmpty)

                        OneActionButton(palette: palette, title: "Cancel", style: .secondary) {
                            onCancel()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .oneNavigationBarHidden()
            .onAppear {
                if selectedCategoryID.isEmpty {
                    selectedCategoryID = categories.first?.id ?? ""
                }
            }
        }
    }
}

private struct HabitDetailView: View {
    let habitId: String
    @ObservedObject var tasksViewModel: TasksViewModel
    let anchorDate: String
    let onSave: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var notes = ""
    @State private var recurrenceRule = HabitRecurrenceRule()
    @State private var preferredTime = ""
    @State private var priorityWeight = 50.0
    @State private var isActive = true
    @State private var stats: HabitStats?
    @Environment(\.colorScheme) private var colorScheme

    private var palette: OneTheme.Palette {
        OneTheme.palette(for: colorScheme)
    }

    private var habit: Habit? {
        tasksViewModel.habits.first(where: { $0.id == habitId })
    }

    var body: some View {
        OneScrollScreen(palette: palette, bottomPadding: 158) {
            OneHeroHeader(
                palette: palette,
                title: "Habit Detail",
                subtitle: "Update the habit and review recent consistency."
            ) {
                OneChip(palette: palette, title: isActive ? "Active" : "Paused", kind: isActive ? .success : .neutral)
            }

            OneGlassCard(palette: palette) {
                OneField(title: "Title", text: $title, placeholder: "Habit name")
                OneTextEditorField(title: "Notes", text: $notes, placeholder: "Optional context")
                RecurrenceBuilderCard(palette: palette, recurrence: $recurrenceRule)
                OneField(title: "Preferred Time", text: $preferredTime, placeholder: "06:30")
                SliderCard(palette: palette, title: "Priority Weight", value: $priorityWeight, range: 0...100)
                ToggleCard(palette: palette, title: "Active", subtitle: "Paused habits stay out of Today.", isOn: $isActive)
            }

            if let stats {
                OneSurfaceCard(palette: palette) {
                    OneSectionHeading(palette: palette, title: "30-day metrics", meta: stats.anchorDate)
                    HStack(spacing: 10) {
                        SummaryMetricTile(palette: palette, title: "Current Streak", value: "\(stats.streakCurrent)")
                        SummaryMetricTile(palette: palette, title: "Completed", value: "\(stats.completedWindow)")
                        SummaryMetricTile(palette: palette, title: "Expected", value: "\(stats.expectedWindow)")
                    }
                    HStack(spacing: 10) {
                        SummaryMetricTile(palette: palette, title: "Rate", value: "\(Int(stats.completionRateWindow * 100))%")
                        SummaryMetricTile(palette: palette, title: "Last Done", value: stats.lastCompletedDate ?? "-")
                    }
                }
            }
        }
        .oneInlineNavigationBarTitle()
        .safeAreaInset(edge: .bottom) {
            OneGlassCard(palette: palette, padding: 10) {
                VStack(spacing: 10) {
                    OneActionButton(palette: palette, title: "Save Changes", style: .primary) {
                        Task {
                            _ = await tasksViewModel.updateHabit(
                                id: habitId,
                                input: HabitUpdateInput(
                                    title: title,
                                    notes: notes,
                                    recurrenceRule: recurrenceRule.rawValue,
                                    priorityWeight: Int(priorityWeight),
                                    preferredTime: preferredTime.isEmpty ? nil : preferredTime,
                                    isActive: isActive
                                )
                            )
                            await onSave()
                            dismiss()
                        }
                    }
                    OneActionButton(palette: palette, title: "Delete Habit", style: .secondary) {
                        Task {
                            if await tasksViewModel.deleteHabit(id: habitId) {
                                await onSave()
                                dismiss()
                            }
                        }
                    }
                    .tint(palette.danger)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .task {
            if tasksViewModel.habits.isEmpty {
                await tasksViewModel.loadTasks()
            }
            hydrateFromHabit()
            stats = await tasksViewModel.loadHabitStats(habitId: habitId, anchorDate: anchorDate, windowDays: 30)
        }
    }

    private func hydrateFromHabit() {
        guard let habit else {
            return
        }
        title = habit.title
        notes = habit.notes
        recurrenceRule = HabitRecurrenceRule(rawValue: habit.recurrenceRule)
        preferredTime = habit.preferredTime ?? ""
        priorityWeight = Double(habit.priorityWeight)
        isActive = habit.isActive
    }
}

private struct TodoDetailView: View {
    let todoId: String
    @ObservedObject var tasksViewModel: TasksViewModel
    let onSave: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var notes = ""
    @State private var priority = 50.0
    @State private var isPinned = false
    @State private var status: TodoStatus = .open
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @Environment(\.colorScheme) private var colorScheme

    private var palette: OneTheme.Palette {
        OneTheme.palette(for: colorScheme)
    }

    private var todo: Todo? {
        tasksViewModel.todos.first(where: { $0.id == todoId })
    }

    var body: some View {
        OneScrollScreen(palette: palette, bottomPadding: 158) {
            OneHeroHeader(
                palette: palette,
                title: "Todo Detail",
                subtitle: "Update the task and keep its urgency clear."
            ) {
                OneChip(
                    palette: palette,
                    title: isPinned ? "Pinned" : "Standard",
                    kind: isPinned ? .danger : .neutral
                )
            }

            OneGlassCard(palette: palette) {
                OneField(title: "Title", text: $title, placeholder: "Todo title")
                OneTextEditorField(title: "Notes", text: $notes, placeholder: "Optional context")
                SliderCard(palette: palette, title: "Priority", value: $priority, range: 0...100)
                ToggleCard(palette: palette, title: "Pin as urgent", subtitle: "Moves this above habits in Today.", isOn: $isPinned)
                StatusPickerCard(palette: palette, selection: $status)
                ToggleCard(palette: palette, title: "Due date", subtitle: hasDueDate ? OneDate.dateTimeString(from: dueDate) : "No due date", isOn: $hasDueDate)
                if hasDueDate {
                    DatePickerCard(palette: palette, title: "Due at", selection: $dueDate)
                }
            }
        }
        .oneInlineNavigationBarTitle()
        .safeAreaInset(edge: .bottom) {
            OneGlassCard(palette: palette, padding: 10) {
                VStack(spacing: 10) {
                    OneActionButton(palette: palette, title: "Save Changes", style: .primary) {
                        Task {
                            _ = await tasksViewModel.updateTodo(
                                id: todoId,
                                input: TodoUpdateInput(
                                    title: title,
                                    notes: notes,
                                    dueAt: hasDueDate ? dueDate : nil,
                                    priority: Int(priority),
                                    isPinned: isPinned,
                                    status: status
                                )
                            )
                            await onSave()
                            dismiss()
                        }
                    }
                    OneActionButton(palette: palette, title: "Delete Todo", style: .secondary) {
                        Task {
                            if await tasksViewModel.deleteTodo(id: todoId) {
                                await onSave()
                                dismiss()
                            }
                        }
                    }
                    .tint(palette.danger)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .task {
            if tasksViewModel.todos.isEmpty {
                await tasksViewModel.loadTasks()
            }
            hydrateFromTodo()
        }
    }

    private func hydrateFromTodo() {
        guard let todo else {
            return
        }
        title = todo.title
        notes = todo.notes
        priority = Double(todo.priority)
        isPinned = todo.isPinned
        status = todo.status
        hasDueDate = todo.dueAt != nil
        if let dueAt = todo.dueAt {
            dueDate = dueAt
        }
    }
}

private struct NotificationPreferencesView: View {
    @ObservedObject var profileViewModel: ProfileViewModel
    let onClose: () -> Void

    @State private var habitReminders = true
    @State private var todoReminders = true
    @State private var reflectionPrompts = true
    @State private var weeklySummary = true
    @State private var quietHoursStart = "22:00:00"
    @State private var quietHoursEnd = "07:00:00"
    @State private var coachEnabled = true
    @Environment(\.colorScheme) private var colorScheme

    private var palette: OneTheme.Palette {
        OneTheme.palette(for: colorScheme)
    }

    var body: some View {
        NavigationStack {
            OneScrollScreen(palette: palette, bottomPadding: 148) {
                OneHeroHeader(
                    palette: palette,
                    title: "Notifications",
                    subtitle: "Local reminders only. Quiet hours and module flags stay on-device."
                ) {
                    OneChip(
                        palette: palette,
                        title: profileViewModel.notificationStatus?.permissionGranted == true ? "Enabled" : "Needs permission",
                        kind: profileViewModel.notificationStatus?.permissionGranted == true ? .success : .danger
                    )
                }

                OneGlassCard(palette: palette) {
                    ToggleCard(palette: palette, title: "Habit reminders", subtitle: "Use preferred habit times.", isOn: $habitReminders)
                    ToggleCard(palette: palette, title: "Todo reminders", subtitle: "Use due dates when available.", isOn: $todoReminders)
                    ToggleCard(palette: palette, title: "Reflection prompts", subtitle: "Nudge at the end of the day.", isOn: $reflectionPrompts)
                    ToggleCard(palette: palette, title: "Weekly summary", subtitle: "Prompt a weekly review.", isOn: $weeklySummary)
                    ToggleCard(palette: palette, title: "Coach enabled", subtitle: "Allow coach prompts in reminder scheduling.", isOn: $coachEnabled)
                    OneField(title: "Quiet Start", text: $quietHoursStart, placeholder: "22:00:00")
                    OneField(title: "Quiet End", text: $quietHoursEnd, placeholder: "07:00:00")
                }

                if let status = profileViewModel.notificationStatus {
                    OneSurfaceCard(palette: palette) {
                        OneSectionHeading(palette: palette, title: "Schedule health", meta: status.permissionGranted ? "Permission granted" : "Permission not granted")
                        HStack(spacing: 10) {
                            SummaryMetricTile(palette: palette, title: "Scheduled", value: "\(status.scheduledCount)")
                            SummaryMetricTile(palette: palette, title: "Permission", value: status.permissionGranted ? "On" : "Off")
                        }
                        if let lastRefreshedAt = status.lastRefreshedAt {
                            Text("Last refreshed: \(lastRefreshedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(palette.subtext)
                        }
                        if let error = status.lastError, !error.isEmpty {
                            InlineStatusCard(message: error, kind: .danger, palette: palette)
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                OneGlassCard(palette: palette, padding: 10) {
                    VStack(spacing: 10) {
                        OneActionButton(palette: palette, title: "Save Preferences", style: .primary) {
                            Task {
                                await profileViewModel.savePreferences(
                                    input: UserPreferencesUpdateInput(
                                        quietHoursStart: quietHoursStart,
                                        quietHoursEnd: quietHoursEnd,
                                        notificationFlags: [
                                            "habit_reminders": habitReminders,
                                            "todo_reminders": todoReminders,
                                            "reflection_prompts": reflectionPrompts,
                                            "weekly_summary": weeklySummary,
                                        ],
                                        coachEnabled: coachEnabled
                                    )
                                )
                            }
                        }
                        OneActionButton(palette: palette, title: "Done", style: .secondary) {
                            onClose()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .oneNavigationBarHidden()
            .task {
                if profileViewModel.preferences == nil {
                    await profileViewModel.load()
                }
                hydrateFromLoadedData()
                await profileViewModel.refreshSchedules()
            }
        }
    }

    private func hydrateFromLoadedData() {
        guard let preferences = profileViewModel.preferences else {
            return
        }
        habitReminders = preferences.notificationFlags["habit_reminders"] ?? true
        todoReminders = preferences.notificationFlags["todo_reminders"] ?? true
        reflectionPrompts = preferences.notificationFlags["reflection_prompts"] ?? true
        weeklySummary = preferences.notificationFlags["weekly_summary"] ?? true
        quietHoursStart = preferences.quietHoursStart ?? quietHoursStart
        quietHoursEnd = preferences.quietHoursEnd ?? quietHoursEnd
        coachEnabled = preferences.coachEnabled
    }
}

private struct CoachSheetView: View {
    @ObservedObject var viewModel: CoachViewModel
    let onClose: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var palette: OneTheme.Palette {
        OneTheme.palette(for: colorScheme)
    }

    var body: some View {
        NavigationStack {
            OneScrollScreen(palette: palette, bottomPadding: 110) {
                OneHeroHeader(
                    palette: palette,
                    title: "Coach",
                    subtitle: "Supportive content that stays accessible but never blocks execution."
                ) {
                    OneChip(palette: palette, title: "Secondary", kind: .neutral)
                }

                if viewModel.cards.isEmpty {
                    EmptyStateCard(
                        palette: palette,
                        title: "No coach cards available",
                        message: "Bundled coach content will appear here when active."
                    )
                } else {
                    ForEach(viewModel.cards) { card in
                        OneGlassCard(palette: palette) {
                            Text(card.title)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(palette.text)
                            Text(card.body)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(palette.subtext)
                                .fixedSize(horizontal: false, vertical: true)
                            CoachVerseBlock(palette: palette, card: card)
                            if !card.tags.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(card.tags, id: \.self) { tag in
                                            OneChip(palette: palette, title: tag, kind: .neutral)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                if let message = viewModel.errorMessage {
                    InlineStatusCard(message: message, kind: .danger, palette: palette)
                }
            }
            .safeAreaInset(edge: .bottom) {
                OneGlassCard(palette: palette, padding: 10) {
                    OneActionButton(palette: palette, title: "Done", style: .primary) {
                        onClose()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .oneNavigationBarHidden()
            .task {
                if viewModel.cards.isEmpty {
                    await viewModel.load()
                }
            }
        }
    }
}

private struct TodayItemCard<Destination: View>: View {
    let palette: OneTheme.Palette
    let item: TodayItem
    let categoryName: String
    let categoryIcon: String
    let isReordering: Bool
    let onToggle: () -> Void
    @ViewBuilder let destination: Destination

    private var supportingLine: String? {
        if let dueAt = item.dueAt {
            return "Due \(OneDate.dateTimeString(from: dueAt))"
        }
        if let preferredTime = item.preferredTime, !preferredTime.isEmpty {
            return "Around \(preferredTime)"
        }
        return item.subtitle?.hasPrefix("Habit ·") == true ? nil : item.subtitle
    }

    var body: some View {
        OneSurfaceCard(palette: palette) {
            HStack(alignment: .top, spacing: 12) {
                Button(action: onToggle) {
                    Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(item.completed ? palette.success : palette.subtext)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(item.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(item.completed ? palette.subtext : palette.text)
                            .strikethrough(item.completed, color: palette.subtext)
                        if item.completed {
                            OneChip(palette: palette, title: "Done", kind: .success)
                        }
                    }
                    if let supportingLine, !supportingLine.isEmpty {
                        Text(supportingLine)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(palette.subtext)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    HStack(spacing: 8) {
                        EmojiBadge(symbol: item.itemType == .habit ? "🔁" : "☑️", palette: palette)
                        EmojiBadge(symbol: categoryIcon, palette: palette, accessibilityLabel: categoryName)
                        if item.isPinned == true {
                            SymbolBadge(systemName: "pin.fill", tint: palette.danger, palette: palette)
                        }
                        if let priority = item.priority {
                            PriorityBadge(priority: priority, palette: palette)
                        }
                    }
                }

                Spacer(minLength: 8)

                VStack(spacing: 10) {
                    if isReordering {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(palette.subtext)
                            .padding(.top, 4)
                    }
                    NavigationLink {
                        destination
                    } label: {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(palette.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct EmojiBadge: View {
    let symbol: String
    let palette: OneTheme.Palette
    var accessibilityLabel: String? = nil

    var body: some View {
        Text(symbol)
            .font(.system(size: 15))
            .frame(width: 30, height: 30)
            .background(
                RoundedRectangle(cornerRadius: OneTheme.radiusSmall, style: .continuous)
                    .fill(palette.surfaceMuted)
            )
            .overlay(
                RoundedRectangle(cornerRadius: OneTheme.radiusSmall, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            )
            .accessibilityLabel(accessibilityLabel ?? symbol)
    }
}

private struct SymbolBadge: View {
    let systemName: String
    let tint: Color
    let palette: OneTheme.Palette

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 30, height: 30)
            .background(
                RoundedRectangle(cornerRadius: OneTheme.radiusSmall, style: .continuous)
                    .fill(palette.surfaceMuted)
            )
            .overlay(
                RoundedRectangle(cornerRadius: OneTheme.radiusSmall, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            )
    }
}

private struct PriorityBadge: View {
    let priority: Int
    let palette: OneTheme.Palette

    var body: some View {
        Circle()
            .fill(priorityIndicatorColor(for: priority))
            .frame(width: 24, height: 24)
            .overlay(
                Circle()
                    .stroke(palette.surface, lineWidth: 2)
            )
            .overlay(
                Circle()
                    .stroke(priorityIndicatorColor(for: priority).opacity(0.35), lineWidth: 6)
            )
            .accessibilityLabel("Priority \(priority)")
    }
}

private struct QuickNoteRow: View {
    let palette: OneTheme.Palette
    let note: ReflectionNote
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(note.createdAt.map { OneDate.timeString(from: $0) } ?? note.periodStart)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.subtext)
                Spacer()
                OneChip(
                    palette: palette,
                    title: "\(note.sentiment.emoji) \(note.sentiment.title)",
                    kind: note.sentiment.chipKind
                )
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.danger)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: OneTheme.radiusSmall, style: .continuous)
                                .fill(palette.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: OneTheme.radiusSmall, style: .continuous)
                                .stroke(palette.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            Text(note.content)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(palette.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: OneTheme.radiusMedium, style: .continuous)
                .fill(palette.surfaceMuted)
        )
        .overlay(
            RoundedRectangle(cornerRadius: OneTheme.radiusMedium, style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        )
    }
}

private struct SentimentPickerRow: View {
    let palette: OneTheme.Palette
    @Binding var selectedSentiment: ReflectionSentiment?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sentiment")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.subtext)
            FlowLayout(spacing: 8) {
                ForEach(ReflectionSentiment.allCases, id: \.self) { sentiment in
                    Button {
                        selectedSentiment = sentiment
                    } label: {
                        Text(sentiment.emoji)
                            .font(.system(size: 26))
                            .frame(width: 56, height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: OneTheme.radiusSmall, style: .continuous)
                                .fill(selectedSentiment == sentiment ? palette.accent.opacity(0.18) : palette.surfaceMuted)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: OneTheme.radiusSmall, style: .continuous)
                                .stroke(selectedSentiment == sentiment ? palette.accent : palette.border, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(sentiment.title)
                }
            }
        }
    }
}

private struct CompactTodayPreviewRow: View {
    let palette: OneTheme.Palette
    let item: TodayItem

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(item.completed ? palette.success.opacity(0.2) : palette.surfaceStrong)
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: item.completed ? "checkmark" : (item.itemType == .habit ? "repeat" : "checklist"))
                        .foregroundStyle(item.completed ? palette.success : palette.symbol)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.text)
                Text(item.subtitle ?? (item.itemType == .habit ? "Scheduled habit" : "Todo"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.subtext)
            }
            Spacer()
            if item.isPinned == true {
                Image(systemName: "pin.fill")
                    .foregroundStyle(palette.danger)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: OneTheme.radiusMedium, style: .continuous)
                .fill(palette.surfaceMuted)
        )
    }
}

private struct HomeHabitCategoryGroup: Identifiable {
    let categoryId: String
    let categoryName: String
    let categoryIcon: String
    let habits: [Habit]

    var id: String { categoryId }
}

private struct HomeHabitCategoryGroupRow: View {
    let palette: OneTheme.Palette
    let group: HomeHabitCategoryGroup

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(palette.surfaceStrong)
                .frame(width: 36, height: 36)
                .overlay(
                    Text(group.categoryIcon)
                        .font(.system(size: 18))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(group.categoryName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.text)
                Text("\(group.habits.count) active habit\(group.habits.count == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.subtext)
            }

            Spacer()

            Image(systemName: "chevron.right.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(palette.accent)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: OneTheme.radiusMedium, style: .continuous)
                .fill(palette.surfaceMuted)
        )
    }
}

private struct HabitCategorySheetView: View {
    let categoryId: String
    @ObservedObject var tasksViewModel: TasksViewModel
    let anchorDate: String
    let onDismiss: () -> Void
    let onSave: () async -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var palette: OneTheme.Palette {
        OneTheme.palette(for: colorScheme)
    }

    private var category: Category? {
        tasksViewModel.categories.first(where: { $0.id == categoryId })
    }

    private var categoryName: String {
        category?.name ?? "Category"
    }

    private var categoryIcon: String {
        actionQueueCategoryIcon(name: category?.name ?? "Category", storedIcon: category?.icon)
    }

    private var activeHabits: [Habit] {
        tasksViewModel.habits
            .filter { $0.isActive && $0.categoryId == categoryId }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            OneScrollScreen(palette: palette) {
                OneHeroHeader(
                    palette: palette,
                    title: categoryName,
                    subtitle: "\(activeHabits.count) active habit\(activeHabits.count == 1 ? "" : "s")"
                ) {
                    Button("Done") {
                        onDismiss()
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.accent)
                }

                OneSurfaceCard(palette: palette) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(palette.surfaceStrong)
                            .frame(width: 42, height: 42)
                            .overlay(
                                Text(categoryIcon)
                                    .font(.system(size: 20))
                            )
                        VStack(alignment: .leading, spacing: 4) {
                            Text(categoryName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(palette.text)
                            Text("Browse and edit the habits in this category.")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(palette.subtext)
                        }
                    }
                }

                OneSurfaceCard(palette: palette) {
                    OneSectionHeading(
                        palette: palette,
                        title: "Habits",
                        meta: activeHabits.isEmpty ? "Nothing active" : "\(activeHabits.count)"
                    )

                    if activeHabits.isEmpty {
                        EmptyStateCard(
                            palette: palette,
                            title: "No active habits here",
                            message: "Activate or add a habit in this category to see it here."
                        )
                    } else {
                        VStack(spacing: 10) {
                            ForEach(activeHabits) { habit in
                                NavigationLink {
                                    HabitDetailView(
                                        habitId: habit.id,
                                        tasksViewModel: tasksViewModel,
                                        anchorDate: anchorDate,
                                        onSave: {
                                            await onSave()
                                        }
                                    )
                                } label: {
                                    ActiveHabitHomeRow(
                                        palette: palette,
                                        habit: habit,
                                        categoryName: categoryName,
                                        categoryIcon: categoryIcon
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .oneNavigationBarHidden()
        }
    }
}

private struct ActiveHabitHomeRow: View {
    let palette: OneTheme.Palette
    let habit: Habit
    let categoryName: String
    let categoryIcon: String

    private var recurrenceSummary: String {
        HabitRecurrenceRule(rawValue: habit.recurrenceRule).summary
    }

    private var supportingLine: String {
        if let preferredTime = habit.preferredTime, !preferredTime.isEmpty {
            return "\(categoryName) • Around \(preferredTime)"
        }
        return categoryName
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(palette.surfaceStrong)
                .frame(width: 34, height: 34)
                .overlay(
                    Text("🔁")
                        .font(.system(size: 16))
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(habit.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.text)
                Text(recurrenceSummary)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.accent)
                Text(supportingLine)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.subtext)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            VStack(spacing: 8) {
                EmojiBadge(symbol: categoryIcon, palette: palette, accessibilityLabel: categoryName)
                PriorityBadge(priority: habit.priorityWeight, palette: palette)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: OneTheme.radiusMedium, style: .continuous)
                .fill(palette.surfaceMuted)
        )
    }
}

private extension ReflectionSentiment {
    var title: String {
        switch self {
        case .great:
            return "Great"
        case .focused:
            return "Focused"
        case .okay:
            return "Okay"
        case .tired:
            return "Tired"
        case .stressed:
            return "Stressed"
        }
    }

    var emoji: String {
        switch self {
        case .great:
            return "😄"
        case .focused:
            return "🎯"
        case .okay:
            return "🙂"
        case .tired:
            return "😴"
        case .stressed:
            return "😣"
        }
    }

    var chipKind: OneChip.Kind {
        switch self {
        case .great:
            return .success
        case .focused:
            return .strong
        case .okay:
            return .neutral
        case .tired:
            return .neutral
        case .stressed:
            return .danger
        }
    }
}

private struct SummaryMetricTile: View {
    let palette: OneTheme.Palette
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(palette.subtext)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(palette.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: OneTheme.radiusMedium, style: .continuous)
                .fill(palette.surfaceMuted)
        )
        .overlay(
            RoundedRectangle(cornerRadius: OneTheme.radiusMedium, style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        )
    }
}

private struct QuickActionTile: View {
    let palette: OneTheme.Palette
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Circle()
                    .fill(palette.accentSoft)
                    .frame(width: 42, height: 42)
                    .overlay(
                        Image(systemName: icon)
                            .foregroundStyle(palette.accent)
                    )
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.text)
                    .multilineTextAlignment(.leading)
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(palette.subtext)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: OneTheme.radiusMedium, style: .continuous)
                    .fill(palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: OneTheme.radiusMedium, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct HomeQuickActionsFAB: View {
    let palette: OneTheme.Palette
    @Binding var isExpanded: Bool
    let onFocusToday: () -> Void
    let onAddHabit: () -> Void
    let onAddTodo: () -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            if isExpanded {
                FloatingQuickActionButton(
                    palette: palette,
                    icon: "bolt.fill",
                    title: "Focus Today",
                    action: onFocusToday
                )
                FloatingQuickActionButton(
                    palette: palette,
                    icon: "repeat",
                    title: "Add Habit",
                    action: onAddHabit
                )
                FloatingQuickActionButton(
                    palette: palette,
                    icon: "checklist",
                    title: "Add Todo",
                    action: onAddTodo
                )
            }

            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                    isExpanded.toggle()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(palette.accent)
                        .frame(width: 58, height: 58)
                    Image(systemName: isExpanded ? "xmark" : "plus")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.white)
                }
                .shadow(color: palette.shadowColor.opacity(0.24), radius: 16, y: 8)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct FloatingQuickActionButton: View {
    let palette: OneTheme.Palette
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.text)
                Circle()
                    .fill(palette.surfaceStrong)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(palette.accent)
                    )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(palette.surface)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct CoachVerseBlock: View {
    let palette: OneTheme.Palette
    let card: CoachCard

    private var resolvedVerse: String? {
        BibleVerseResolver.shared.resolveText(for: card.verseRef, fallback: card.verseText)
    }

    var body: some View {
        if let verse = resolvedVerse,
           let verseRef = card.verseRef,
           !verseRef.isEmpty {
            Text("\(verseRef) \(verse)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.text)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: OneTheme.radiusMedium, style: .continuous)
                        .fill(palette.accentSoft)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: OneTheme.radiusMedium, style: .continuous)
                        .stroke(palette.border, lineWidth: 1)
                )
        } else if let verse = card.verseText,
                  !verse.isEmpty {
            Text(verse)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct EmptyStateCard: View {
    let palette: OneTheme.Palette
    let title: String
    let message: String

    var body: some View {
        OneSurfaceCard(palette: palette) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(palette.text)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(palette.subtext)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct InlineStatusCard: View {
    enum Kind {
        case neutral
        case danger
    }

    let message: String
    let kind: Kind
    let palette: OneTheme.Palette

    var body: some View {
        OneSurfaceCard(palette: palette) {
            HStack(spacing: 10) {
                Image(systemName: kind == .danger ? "exclamationmark.triangle.fill" : "info.circle.fill")
                    .foregroundStyle(kind == .danger ? palette.danger : palette.accent)
                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(kind == .danger ? palette.danger : palette.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct OneField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    @Environment(\.colorScheme) private var colorScheme

    private var palette: OneTheme.Palette {
        OneTheme.palette(for: colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.subtext)
            TextField(placeholder, text: $text)
                .onePlainTextInputBehavior()
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: OneTheme.radiusMedium, style: .continuous)
                        .fill(palette.surfaceMuted)
                )
                .foregroundStyle(palette.text)
        }
    }
}

private struct OneTextEditorField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    var isFocused: FocusState<Bool>.Binding? = nil
    @Environment(\.colorScheme) private var colorScheme

    private var palette: OneTheme.Palette {
        OneTheme.palette(for: colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.subtext)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: OneTheme.radiusMedium, style: .continuous)
                    .fill(palette.surfaceMuted)
                if let isFocused {
                    TextEditor(text: $text)
                        .focused(isFocused)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 92)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .foregroundStyle(palette.text)
                } else {
                    TextEditor(text: $text)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 92)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .foregroundStyle(palette.text)
                }
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(placeholder)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(palette.subtext.opacity(0.85))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }
        }
    }
}

private struct PickerCard: View {
    let palette: OneTheme.Palette
    let title: String
    @Binding var selection: String
    let options: [(id: String, name: String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.subtext)
            Picker(title, selection: $selection) {
                ForEach(options, id: \.id) { option in
                    Text(option.name).tag(option.id)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: OneTheme.radiusMedium, style: .continuous)
                    .fill(palette.surfaceMuted)
            )
        }
    }
}

private struct SliderCard: View {
    let palette: OneTheme.Palette
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.subtext)
                Spacer()
                Text("\(Int(value))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.text)
            }
            Slider(value: $value, in: range, step: 1)
                .tint(palette.accent)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: OneTheme.radiusMedium, style: .continuous)
                .fill(palette.surfaceMuted)
        )
    }
}

private struct ToggleCard: View {
    let palette: OneTheme.Palette
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.text)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.subtext)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(palette.accent)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: OneTheme.radiusMedium, style: .continuous)
                .fill(palette.surfaceMuted)
        )
    }
}

private struct DatePickerCard: View {
    let palette: OneTheme.Palette
    let title: String
    @Binding var selection: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.subtext)
            DatePicker("", selection: $selection)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: OneTheme.radiusMedium, style: .continuous)
                .fill(palette.surfaceMuted)
        )
    }
}

private struct StatusPickerCard: View {
    let palette: OneTheme.Palette
    @Binding var selection: TodoStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Status")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.subtext)
            Picker("Status", selection: $selection) {
                Text("Open").tag(TodoStatus.open)
                Text("Completed").tag(TodoStatus.completed)
                Text("Canceled").tag(TodoStatus.canceled)
            }
            .pickerStyle(.segmented)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: OneTheme.radiusMedium, style: .continuous)
                .fill(palette.surfaceMuted)
        )
    }
}

private struct RecurrenceBuilderCard: View {
    let palette: OneTheme.Palette
    @Binding var recurrence: HabitRecurrenceRule
    @State private var yearlyDraftDate = Date()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Schedule")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.subtext)

            OneSegmentedControl(
                palette: palette,
                options: HabitRecurrenceFrequency.allCases,
                selection: recurrence.frequency,
                title: { $0.title }
            ) { selection in
                var updated = recurrence
                updated.frequency = selection
                switch selection {
                case .daily:
                    break
                case .weekly where updated.weekdays.isEmpty:
                    updated.weekdays = [.monday]
                case .monthly where updated.monthDays.isEmpty:
                    updated.monthDays = [1]
                case .yearly where updated.yearlyDates.isEmpty:
                    updated.yearlyDates = [HabitRecurrenceYearlyDate(month: 1, day: 1)]
                default:
                    break
                }
                recurrence = updated
            }

            switch recurrence.frequency {
            case .daily:
                Text("Daily habits materialize every day.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.subtext)
            case .weekly:
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(HabitRecurrenceWeekday.allCases, id: \.self) { weekday in
                        RecurrenceChoiceChip(
                            palette: palette,
                            title: weekday.shortTitle,
                            isSelected: recurrence.weekdays.contains(weekday)
                        ) {
                            var updated = recurrence
                            if updated.weekdays.contains(weekday) {
                                updated.weekdays.removeAll { $0 == weekday }
                            } else {
                                updated.weekdays.append(weekday)
                            }
                            recurrence = HabitRecurrenceRule(
                                frequency: updated.frequency,
                                weekdays: updated.weekdays,
                                monthDays: updated.monthDays,
                                yearlyDates: updated.yearlyDates
                            )
                        }
                    }
                }
            case .monthly:
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(1...31, id: \.self) { day in
                        RecurrenceChoiceChip(
                            palette: palette,
                            title: "\(day)",
                            isSelected: recurrence.monthDays.contains(day)
                        ) {
                            var updated = recurrence
                            if updated.monthDays.contains(day) {
                                updated.monthDays.removeAll { $0 == day }
                            } else {
                                updated.monthDays.append(day)
                            }
                            recurrence = HabitRecurrenceRule(
                                frequency: updated.frequency,
                                weekdays: updated.weekdays,
                                monthDays: updated.monthDays,
                                yearlyDates: updated.yearlyDates
                            )
                        }
                    }
                }
            case .yearly:
                VStack(alignment: .leading, spacing: 10) {
                    if recurrence.yearlyDates.isEmpty {
                        Text("Add one or more month-day dates.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(palette.subtext)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(recurrence.yearlyDates, id: \.self) { date in
                                    RemovableChoiceChip(palette: palette, title: date.title) {
                                        var updated = recurrence
                                        updated.yearlyDates.removeAll { $0 == date }
                                        recurrence = HabitRecurrenceRule(
                                            frequency: updated.frequency,
                                            weekdays: updated.weekdays,
                                            monthDays: updated.monthDays,
                                            yearlyDates: updated.yearlyDates
                                        )
                                    }
                                }
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        DatePicker("", selection: $yearlyDraftDate, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.compact)

                        Button("Add date") {
                            let components = Calendar(identifier: .gregorian).dateComponents([.month, .day], from: yearlyDraftDate)
                            guard let month = components.month, let day = components.day else {
                                return
                            }
                            var updated = recurrence
                            updated.yearlyDates.append(HabitRecurrenceYearlyDate(month: month, day: day))
                            recurrence = HabitRecurrenceRule(
                                frequency: updated.frequency,
                                weekdays: updated.weekdays,
                                monthDays: updated.monthDays,
                                yearlyDates: updated.yearlyDates
                            )
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.accent)
                    }
                }
            }

            Text(recurrence.summary)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: OneTheme.radiusMedium, style: .continuous)
                        .fill(palette.surfaceMuted)
                )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: OneTheme.radiusMedium, style: .continuous)
                .fill(palette.surfaceMuted)
        )
    }
}

private struct RecurrenceChoiceChip: View {
    let palette: OneTheme.Palette
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isSelected ? palette.text : palette.subtext)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: OneTheme.radiusSmall, style: .continuous)
                        .fill(isSelected ? palette.surface : palette.glass)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: OneTheme.radiusSmall, style: .continuous)
                        .stroke(isSelected ? palette.accent : palette.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct RemovableChoiceChip: View {
    let palette: OneTheme.Palette
    let title: String
    let onRemove: () -> Void

    var body: some View {
        Button(action: onRemove) {
            HStack(spacing: 6) {
                Text(title)
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(palette.text)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: OneTheme.radiusSmall, style: .continuous)
                    .fill(palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: OneTheme.radiusSmall, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct AnalyticsYearContributionView: View {
    let palette: OneTheme.Palette
    let sections: [AnalyticsContributionMonthSection]
    let onSelectDate: (String) -> Void

    var body: some View {
        VStack(spacing: 12) {
            ForEach(sections) { section in
                AnalyticsMonthContributionSection(
                    palette: palette,
                    section: section,
                    onSelectDate: onSelectDate
                )
            }
        }
    }
}

private struct AnalyticsMonthContributionSection: View {
    let palette: OneTheme.Palette
    let section: AnalyticsContributionMonthSection
    let onSelectDate: (String) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(section.label)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.text)
                Spacer()
                Text("\(section.completedItems)/\(section.expectedItems)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.subtext)
            }

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(palette.subtext)
                        .frame(maxWidth: .infinity)
                }

                ForEach(0..<section.leadingPlaceholders, id: \.self) { _ in
                    Color.clear
                        .frame(height: 22)
                }

                ForEach(section.days) { day in
                    Button {
                        onSelectDate(day.dateLocal)
                    } label: {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(contributionFill(for: day.completionRate, palette: palette))
                            .frame(height: 22)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(palette.border.opacity(0.55), lineWidth: 0.5)
                            )
                            .overlay {
                                Text("\(day.dayNumber)")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(palette.text.opacity(day.hasSummary ? 0.78 : 0.45))
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: OneTheme.radiusMedium, style: .continuous)
                .fill(palette.surfaceMuted)
        )
        .overlay(
            RoundedRectangle(cornerRadius: OneTheme.radiusMedium, style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        )
    }
}

private struct AnalyticsContributionGrid: View {
    let palette: OneTheme.Palette
    let summaries: [DailySummary]
    let onSelectDate: (String) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(summaries, id: \.dateLocal) { summary in
                Button {
                    onSelectDate(summary.dateLocal)
                } label: {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(contributionFill(for: summary.completionRate, palette: palette))
                        .frame(height: 18)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(palette.border.opacity(0.55), lineWidth: 0.5)
                        )
                        .overlay(alignment: .bottomTrailing) {
                            Text(OneDate.dayNumber(from: summary.dateLocal))
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(palette.text.opacity(0.75))
                                .padding(2)
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct AnalyticsSentimentOverviewView: View {
    let palette: OneTheme.Palette
    let periodType: PeriodType
    let overview: AnalyticsSentimentOverview
    let highlightedDates: Set<String>
    let onOpenDate: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !overview.distribution.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(overview.distribution) { item in
                        OneChip(
                            palette: palette,
                            title: "\(item.sentiment.emoji) \(item.sentiment.title) \(item.count)",
                            kind: item.sentiment.chipKind
                        )
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Trend")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.subtext)
                switch periodType {
                case .monthly:
                    let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(overview.trend) { point in
                            sentimentPoint(point)
                        }
                    }
                default:
                    HStack(alignment: .top, spacing: 8) {
                        ForEach(overview.trend) { point in
                            sentimentPoint(point)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func sentimentPoint(_ point: AnalyticsSentimentTrendPoint) -> some View {
        let content = VStack(spacing: 6) {
            Text(point.sentiment?.emoji ?? "·")
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(point.sentiment == nil ? palette.surfaceMuted : palette.accentSoft)
                )
                .overlay(
                    Circle()
                        .stroke(
                            highlightedDates.contains(point.dateLocal ?? "") ? palette.accent : Color.clear,
                            lineWidth: 1.5
                        )
                )
            Text(point.label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(palette.subtext)
        }
        .frame(maxWidth: .infinity)

        if let dateLocal = point.dateLocal {
            Button {
                onOpenDate(dateLocal)
            } label: {
                content
            }
            .buttonStyle(.plain)
        } else {
            content
        }
    }
}

private struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content

    init(spacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        WrappingFlowLayout(spacing: spacing) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct WrappingFlowLayout: Layout {
    let spacing: CGFloat

    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let width = max(proposal.width ?? 320, 1)
        let frames = wrappedFrames(for: subviews, maxWidth: width)
        let contentWidth = frames.reduce(0) { max($0, $1.maxX) }
        let contentHeight = frames.reduce(0) { max($0, $1.maxY) }
        return CGSize(width: proposal.width ?? contentWidth, height: contentHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let frames = wrappedFrames(for: subviews, maxWidth: max(bounds.width, 1))
        for (index, frame) in frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(width: frame.width, height: frame.height)
            )
        }
    }

    private func wrappedFrames(for subviews: Subviews, maxWidth: CGFloat) -> [CGRect] {
        var frames: [CGRect] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        let availableWidth = max(maxWidth, 1)

        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: availableWidth, height: nil))
            if currentX > 0, currentX + size.width > availableWidth {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            let frame = CGRect(origin: CGPoint(x: currentX, y: currentY), size: size)
            frames.append(frame)
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        return frames
    }
}

private func actionQueueCategoryIcon(name: String, storedIcon: String?) -> String {
    if let storedIcon, !storedIcon.isEmpty, storedIcon != "circle" {
        return storedIcon
    }

    switch name {
    case "Gym":
        return "🏋️"
    case "School":
        return "🎓"
    case "Personal Projects":
        return "💡"
    case "Wellbeing":
        return "🌿"
    case "Life Admin":
        return "🧾"
    default:
        return "◻️"
    }
}

private func priorityIndicatorColor(for priority: Int) -> Color {
    let normalized = min(max(Double(priority) / 100, 0), 1)
    let amber = (red: 0.93, green: 0.69, blue: 0.29)
    let coral = (red: 0.93, green: 0.42, blue: 0.33)
    return Color(
        red: amber.red + ((coral.red - amber.red) * normalized),
        green: amber.green + ((coral.green - amber.green) * normalized),
        blue: amber.blue + ((coral.blue - amber.blue) * normalized)
    )
}

private func contributionFill(for rate: Double, palette: OneTheme.Palette) -> Color {
    if rate >= 0.8 {
        return palette.success.opacity(0.9)
    } else if rate >= 0.5 {
        return palette.accent.opacity(0.8)
    } else if rate > 0 {
        return palette.warning.opacity(0.8)
    } else {
        return palette.surfaceStrong
    }
}

enum OneDate {
    private static let canonicalTimeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    static var deviceTimeZone: TimeZone { .autoupdatingCurrent }
    static var deviceTimeZoneIdentifier: String { deviceTimeZone.identifier }
    private static let canonicalCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = canonicalTimeZone
        return calendar
    }()

    private static let isoFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = canonicalCalendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = canonicalTimeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let longFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = canonicalCalendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = canonicalTimeZone
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()

    private static let shortWeekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = canonicalCalendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = canonicalTimeZone
        formatter.dateFormat = "EEE"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    private static let shortMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = canonicalCalendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = canonicalTimeZone
        formatter.dateFormat = "MMM"
        return formatter
    }()

    private static let fullMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = canonicalCalendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = canonicalTimeZone
        formatter.dateFormat = "MMMM"
        return formatter
    }()

    private static let shortMonthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = canonicalCalendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = canonicalTimeZone
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    static func isoDate(_ date: Date = Date()) -> String {
        isoDate(date, timezoneID: deviceTimeZoneIdentifier)
    }

    static func isoDate(_ date: Date = Date(), timezoneID: String?) -> String {
        _ = timezoneID
        let timeZone = deviceTimeZone
        var calendar = canonicalCalendar
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let localized = canonicalCalendar.date(from: components) else {
            return isoFormatter.string(from: date)
        }
        return isoFormatter.string(from: localized)
    }

    static func longDate(from isoDateString: String) -> String {
        guard let date = isoFormatter.date(from: isoDateString) else {
            return isoDateString
        }
        return longFormatter.string(from: date)
    }

    static func shortWeekday(from isoDateString: String) -> String {
        guard let date = isoFormatter.date(from: isoDateString) else {
            return ""
        }
        return shortWeekdayFormatter.string(from: date)
    }

    static func initials(from name: String) -> String {
        let words = name.split(separator: " ")
        let initials = words.prefix(2).compactMap { $0.first }.map(String.init).joined()
        return initials.isEmpty ? "1" : initials.uppercased()
    }

    static func timeString(from date: Date) -> String {
        timeFormatter.string(from: date)
    }

    static func dateTimeString(from date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    static func dayNumber(from isoDateString: String) -> String {
        guard let date = isoFormatter.date(from: isoDateString) else {
            return ""
        }
        return String(canonicalCalendar.component(.day, from: date))
    }

    static func weekBucket(from isoDateString: String) -> Int {
        guard let date = isoFormatter.date(from: isoDateString) else {
            return 1
        }
        return canonicalCalendar.component(.weekOfMonth, from: date)
    }

    static func monthBucket(from isoDateString: String) -> Int {
        guard let date = isoFormatter.date(from: isoDateString) else {
            return 1
        }
        return canonicalCalendar.component(.month, from: date)
    }

    static func shortMonth(for month: Int) -> String {
        guard let date = canonicalCalendar.date(from: DateComponents(year: 2026, month: month, day: 1)) else {
            return ""
        }
        return shortMonthFormatter.string(from: date)
    }

    static func fullMonth(for month: Int) -> String {
        guard let date = canonicalCalendar.date(from: DateComponents(year: 2026, month: month, day: 1)) else {
            return ""
        }
        return fullMonthFormatter.string(from: date)
    }

    static func shortMonthDay(from isoDateString: String) -> String {
        guard let date = isoFormatter.date(from: isoDateString) else {
            return isoDateString
        }
        return shortMonthDayFormatter.string(from: date)
    }

    static func year(from isoDateString: String) -> Int? {
        guard let date = isoFormatter.date(from: isoDateString) else {
            return nil
        }
        return canonicalCalendar.component(.year, from: date)
    }

    static func calendarDate(for isoDateString: String) -> Date? {
        isoFormatter.date(from: isoDateString)
    }

    static func canonicalWeekdayIndex(for date: Date) -> Int {
        canonicalCalendar.component(.weekday, from: date) - 1
    }

    static func numberOfDays(inMonth month: Int, year: Int) -> Int {
        guard let date = canonicalCalendar.date(from: DateComponents(year: year, month: month, day: 1)) else {
            return 30
        }
        return canonicalCalendar.range(of: .day, in: .month, for: date)?.count ?? 30
    }
}

private extension View {
    @ViewBuilder
    func oneNavigationBarHidden() -> some View {
        #if os(iOS)
        self.toolbar(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }

    @ViewBuilder
    func oneInlineNavigationBarTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    @ViewBuilder
    func oneListRowSpacing(_ spacing: CGFloat) -> some View {
        #if os(iOS)
        self.listRowSpacing(spacing)
        #else
        self
        #endif
    }

    @ViewBuilder
    func onePlainTextInputBehavior() -> some View {
        #if os(iOS)
        self
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        #else
        self
        #endif
    }

    #if os(iOS)
    @ViewBuilder
    func oneListEditing(editMode: Binding<EditMode>) -> some View {
        self.environment(\.editMode, editMode)
    }
    #endif
}

#if os(iOS)
private extension EditMode {
    var isEditing: Bool {
        self == .active
    }
}
#endif
#endif
