#if canImport(SwiftUI)
import SwiftUI
import Combine
#if canImport(SwiftData)
import SwiftData
#endif
#if os(iOS)
import UIKit
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
    let syncFeedbackCenter: OneSyncFeedbackCenter
    let quickActionCenter: OneQuickActionCenter
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
        self.syncFeedbackCenter = OneSyncFeedbackCenter.shared
        self.quickActionCenter = OneQuickActionCenter()
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
        observe(syncFeedbackCenter)
        observe(quickActionCenter)
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
                    if let created = await container.tasksViewModel.createHabit(input: input) {
                        selectedTab = .today
                        await container.refreshTasksContext(anchorDate: currentAnchorDate)
                        container.todayViewModel.highlight(itemType: .habit, itemId: created.id)
                        activeSheet = nil
                    }
                } onCancel: {
                    activeSheet = nil
                }
            case .addTodo:
                TodoFormSheet(categories: container.tasksViewModel.categories) { input in
                    if let created = await container.tasksViewModel.createTodo(input: input) {
                        selectedTab = .today
                        await container.refreshTasksContext(anchorDate: currentAnchorDate)
                        container.todayViewModel.highlight(itemType: .todo, itemId: created.id)
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
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
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
                        currentDateLocal: currentDateLocal,
                        onOpenSheet: { activeSheet = $0 },
                        onRefreshTasksContext: onRefreshTasksContext,
                        onRefreshAnalytics: onRefreshAnalytics
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
                    .tabItem { Label("Settings", systemImage: "gearshape") }
                    .tag(OneAppShell.Tab.profile)
                }

                VStack(alignment: .trailing, spacing: OneDockLayout.overlayStackSpacing) {
                    if let feedback = container.syncFeedbackCenter.feedback {
                        OneSyncFeedbackPill(palette: palette, feedback: feedback)
                            .frame(maxWidth: 320)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, OneDockLayout.horizontalInset)
                .padding(
                    .bottom,
                    OneDockLayout.overlayBottomInset(
                        safeAreaBottom: proxy.safeAreaInsets.bottom,
                        isExpanded: false
                    )
                )
            }
        }
        .tint(palette.accent)
        .animation(OneMotion.animation(.stateChange), value: container.syncFeedbackCenter.feedback?.id)
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
            VStack(spacing: 18) {
                OneMarkBadge(palette: palette)
                Text("One")
                    .font(OneType.largeTitle)
                    .foregroundStyle(palette.text)
                Text("Daily execution first")
                    .font(OneType.body)
                    .foregroundStyle(palette.subtext)
                ProgressView()
                    .tint(palette.accent)
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
                Text("Local data unavailable")
                    .font(OneType.largeTitle)
                    .foregroundStyle(palette.text)
                Text(message)
                    .font(OneType.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(palette.subtext)
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
        let symbol: String
        let title: String
        let body: String
        let detail: String
    }

    private let pages: [PageContent] = [
        PageContent(
            symbol: "checklist",
            title: "One keeps your day clear.",
            body: "Track habits, tasks, progress, and notes in one calm daily system.",
            detail: "Today is for doing. Home and Analytics help you review without getting in the way."
        ),
        PageContent(
            symbol: "iphone",
            title: "Your profile can stay on this iPhone.",
            body: "Start with a local profile and keep your data on this device, or sign in when you want an account.",
            detail: "You can change settings, reminders, and appearance later."
        ),
    ]

    private var palette: OneTheme.Palette {
        OneTheme.palette(for: colorScheme)
    }

    var body: some View {
        ZStack {
            OneScreenBackground(palette: palette)
            VStack(spacing: OneSpacing.lg) {
                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, content in
                        VStack(alignment: .leading, spacing: OneSpacing.lg) {
                            Spacer(minLength: 48)
                            OneMarkBadge(palette: palette)
                            Image(systemName: content.symbol)
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundStyle(palette.highlight)
                            Text(content.title)
                                .font(OneType.largeTitle)
                                .foregroundStyle(palette.text)
                            Text(content.body)
                                .font(OneType.body)
                                .foregroundStyle(palette.text)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(content.detail)
                                .font(OneType.secondary)
                                .foregroundStyle(palette.subtext)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                        }
                        .padding(.horizontal, OneSpacing.lg)
                        .tag(index)
                    }
                }
                #if os(iOS)
                .tabViewStyle(.page(indexDisplayMode: .always))
                #else
                .tabViewStyle(.automatic)
                #endif

                VStack(spacing: OneSpacing.sm) {
                    OneActionButton(
                        palette: palette,
                        title: page == pages.count - 1 ? "Start using One" : "Continue",
                        style: .primary
                    ) {
                        if page == pages.count - 1 {
                            onComplete()
                        } else {
                            withAnimation(OneMotion.animation(.stateChange)) {
                                page += 1
                            }
                        }
                    }
                    if page > 0 {
                        OneActionButton(palette: palette, title: "Back", style: .secondary) {
                            withAnimation(OneMotion.animation(.dismiss)) {
                                page -= 1
                            }
                        }
                    }
                }
                .padding(.horizontal, OneSpacing.lg)
                .padding(.bottom, 28)
            }
        }
    }
}

private struct LocalProfileSetupView: View {
    private enum AccessMode {
        case local
        case signIn
        case createAccount
    }

    @ObservedObject var viewModel: AuthViewModel
    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var accessMode: AccessMode?
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

    private var title: String {
        switch accessMode {
        case .local?:
            return localProfileCandidate == nil ? "Use this iPhone" : "Welcome back"
        case .signIn?:
            return "Sign in"
        case .createAccount?:
            return "Create account"
        case nil:
            return "Welcome to One"
        }
    }

    private var subtitle: String {
        switch accessMode {
        case .local?:
            return localProfileCandidate == nil
                ? "Start with a local profile and keep using One on this device."
                : "Your profile and data are still on this iPhone."
        case .signIn?:
            return "Use your account to sync your data across future devices."
        case .createAccount?:
            return "Create an account when you want more than local device storage."
        case nil:
            return "Choose the simplest way to begin."
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if accessMode == nil {
                    Section {
                        Button("Use this iPhone") {
                            accessMode = .local
                        }
                        Button("Use account") {
                            accessMode = .signIn
                        }
                    } footer: {
                        Text("Start locally if you want to keep your data on this device, or use an account for future portability.")
                    }
                } else {
                    switch accessMode {
                    case .local?:
                        if let localProfileCandidate {
                            Section {
                                Text(localProfileCandidate.displayName)
                                LabeledContent("Time zone", value: deviceTimezoneID)
                                Button("Continue as \(localProfileCandidate.displayName)") {
                                    Task {
                                        await viewModel.resumeLocalProfile()
                                    }
                                }
                                .disabled(viewModel.isLoading)
                            } header: {
                                Text("This iPhone")
                            } footer: {
                                Text("Continue with the profile already saved on this iPhone.")
                            }
                        } else {
                            Section {
                                TextField("Your name", text: $displayName)
                                LabeledContent("Time zone", value: deviceTimezoneID)
                                Button("Continue on this iPhone") {
                                    Task {
                                        await viewModel.createLocalProfile(
                                            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                                        )
                                    }
                                }
                                .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
                            } header: {
                                Text("This iPhone")
                            } footer: {
                                Text("This profile stays on this iPhone.")
                            }
                        }
                    case .signIn?:
                        Section {
                            TextField("name@example.com", text: $email)
                            SecureField("Password", text: $password)
                            Button("Sign in") {
                                Task {
                                    await viewModel.login(
                                        email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                                        password: password
                                    )
                                }
                            }
                            .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty || viewModel.isLoading)
                        } header: {
                            Text("Account")
                        } footer: {
                            Text("Use your account to keep data available on future devices.")
                        }
                    case .createAccount?:
                        Section {
                            TextField("Your name", text: $displayName)
                            TextField("name@example.com", text: $email)
                            SecureField("Create a password", text: $password)
                            LabeledContent("Time zone", value: deviceTimezoneID)
                            Button("Create account") {
                                Task {
                                    await viewModel.signup(
                                        email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                                        password: password,
                                        displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                                        timezone: deviceTimezoneID
                                    )
                                }
                            }
                            .disabled(
                                displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                password.isEmpty ||
                                viewModel.isLoading
                            )
                        } header: {
                            Text("Create account")
                        }
                    case nil:
                        EmptyView()
                    }
                }

                if let message = viewModel.errorMessage {
                    Section {
                        InlineStatusCard(message: message, kind: .danger, palette: palette)
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(OneScreenBackground(palette: palette))
            .navigationTitle(title)
            .oneNavigationBarDisplayMode(.large)
            .toolbar {
                if accessMode != nil {
                    ToolbarItem(placement: .oneNavigationLeading) {
                        Button("Back") {
                            accessMode = nil
                            password = ""
                        }
                    }
                }
                if accessMode == .signIn {
                    ToolbarItem(placement: .oneNavigationTrailing) {
                        Button("Create account") {
                            accessMode = .createAccount
                        }
                    }
                }
                if accessMode == .createAccount {
                    ToolbarItem(placement: .oneNavigationTrailing) {
                        Button("Sign in") {
                            accessMode = .signIn
                        }
                    }
                }
            }
        }
        .onAppear {
            hydrateFromProfileCandidate()
        }
        .onChange(of: localProfileCandidate?.id) { _, _ in
            hydrateFromProfileCandidate()
        }
    }

    private func hydrateFromProfileCandidate() {
        if let localProfileCandidate {
            displayName = localProfileCandidate.displayName
            if accessMode == nil {
                accessMode = .local
            }
        }
        if localProfileCandidate == nil && accessMode == .local {
            email = ""
            password = ""
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

    @Environment(\.colorScheme) private var colorScheme

    private var palette: OneTheme.Palette {
        OneTheme.palette(for: colorScheme)
    }

    private var urgentItem: TodayItem? {
        todayViewModel.items.first(where: { ($0.isPinned ?? false) && !$0.completed })
    }

    private var nextItem: TodayItem? {
        urgentItem ?? todayViewModel.items.first(where: { !$0.completed })
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

    private var momentumLine: String {
        if todayViewModel.totalCount == 0 {
            return "Nothing is planned yet."
        }
        if todayViewModel.completionRatio == 1 {
            return "You finished what you planned today."
        }
        if todayViewModel.completedCount == 0 {
            return "A clear start matters more than a busy one."
        }
        return "Progress is already moving."
    }

    var body: some View {
        NavigationStack {
            OneScrollScreen(
                palette: palette,
                bottomPadding: OneDockLayout.tabScreenBottomPadding
            ) {
                OneGlassCard(palette: palette, padding: OneSpacing.lg) {
                    HStack(alignment: .top, spacing: OneSpacing.md) {
                        VStack(alignment: .leading, spacing: OneSpacing.sm) {
                            Text("Today")
                                .font(OneType.label)
                                .foregroundStyle(palette.subtext)
                            Text(nextItem?.title ?? "A calm briefing for the day")
                                .font(OneType.title)
                                .foregroundStyle(palette.text)
                            Text("\(todayViewModel.completedCount) completed of \(todayViewModel.totalCount) planned")
                                .font(OneType.secondary)
                                .foregroundStyle(palette.subtext)
                            Text(momentumLine)
                                .font(OneType.body)
                                .foregroundStyle(palette.text)
                                .fixedSize(horizontal: false, vertical: true)
                            if let nextItem {
                                HStack(spacing: 8) {
                                    Text(nextItem.priorityTier.title)
                                        .font(OneType.caption.weight(.semibold))
                                        .foregroundStyle(nextItem.priorityTier == .urgent ? palette.danger : palette.highlight)
                                    Text(nextItem.itemType == .habit ? "Habit" : "Task")
                                        .font(OneType.caption)
                                        .foregroundStyle(palette.subtext)
                                }
                            } else {
                                Text("Open Today to start adding habits or tasks.")
                                    .font(OneType.caption)
                                    .foregroundStyle(palette.subtext)
                            }
                            OneActionButton(palette: palette, title: "Open Today", style: .primary) {
                                OneHaptics.shared.trigger(.selectionChanged)
                                onFocusToday()
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 12) {
                            OneProgressCluster(
                                palette: palette,
                                progress: todayViewModel.completionRatio,
                                label: "\(Int(todayViewModel.completionRatio * 100))%"
                            )
                            if todayViewModel.completionRatio == 1 {
                                Label("Closed", systemImage: "checkmark.circle.fill")
                                    .font(OneType.caption.weight(.semibold))
                                    .foregroundStyle(palette.highlight)
                            } else if let nextItem {
                                Text(nextItem.priorityTier == .urgent ? "Needs attention" : "In motion")
                                    .font(OneType.caption.weight(.semibold))
                                    .foregroundStyle(nextItem.priorityTier == .urgent ? palette.danger : palette.highlight)
                            }
                        }
                    }
                }

                OneSurfaceCard(palette: palette) {
                    OneSectionHeading(palette: palette, title: "This week", meta: analyticsViewModel.weekly?.periodStart ?? "")
                    if analyticsViewModel.weeklyDailySummaries.isEmpty {
                        Text("Complete a few habits or tasks to build a weekly summary.")
                            .font(OneType.secondary)
                            .foregroundStyle(palette.subtext)
                    } else {
                        OneActivityLane(
                            palette: palette,
                            values: analyticsViewModel.weeklyDailySummaries.map(\.completionRate),
                            labels: analyticsViewModel.weeklyDailySummaries.map { OneDate.shortWeekday(from: $0.dateLocal) },
                            highlightIndex: analyticsViewModel.weeklyDailySummaries.lastIndex(where: { $0.dateLocal == currentDateLocal })
                        )
                        HStack(spacing: OneSpacing.sm) {
                            SummaryMetricTile(palette: palette, title: "Completed", value: "\(analyticsViewModel.weekly?.completedItems ?? 0)")
                            SummaryMetricTile(palette: palette, title: "Consistency", value: "\(Int((analyticsViewModel.weekly?.consistencyScore ?? 0) * 100))%")
                            SummaryMetricTile(palette: palette, title: "Active Days", value: "\(analyticsViewModel.weekly?.activeDays ?? 0)")
                        }
                    }
                }

                OneSurfaceCard(palette: palette) {
                    OneSectionHeading(palette: palette, title: "Continue", meta: nil)
                    Button {
                        OneHaptics.shared.trigger(.sheetPresented)
                        onOpenSheet(.notes(anchorDate: currentDateLocal, periodType: .daily))
                    } label: {
                        OneSettingsRow(
                            palette: palette,
                            icon: "note.text",
                            title: "Notes",
                            meta: "Review reflections away from Today.",
                            tail: nil
                        )
                    }
                    .onePressable(scale: 0.992)

                    Divider().overlay(palette.border)

                    Button {
                        OneHaptics.shared.trigger(.sheetPresented)
                        onOpenSheet(.coach)
                    } label: {
                        OneSettingsRow(
                            palette: palette,
                            icon: "sparkles",
                            title: "Coach",
                            meta: featuredCoachCard?.title ?? "Daily guidance that stays secondary.",
                            tail: nil
                        )
                    }
                    .onePressable(scale: 0.992)
                }
            }
            .navigationTitle("Home")
            .oneNavigationBarDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .oneNavigationTrailing) {
                    Menu {
                        Button("Add task") {
                            OneHaptics.shared.trigger(.sheetPresented)
                            onOpenSheet(.addTodo)
                        }
                        Button("Add habit") {
                            OneHaptics.shared.trigger(.sheetPresented)
                            onOpenSheet(.addHabit)
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

private struct TodayTabView: View {
    @ObservedObject var todayViewModel: TodayViewModel
    @ObservedObject var tasksViewModel: TasksViewModel
    let currentDateLocal: String
    let onOpenSheet: (OneAppShell.SheetRoute) -> Void
    let onRefreshTasksContext: () async -> Void
    let onRefreshAnalytics: () async -> Void

    @State private var isReordering = false
    @State private var isUpNextExpanded = false
    @State private var isCompletedSectionExpanded = false
    @State private var visibleMilestoneCount = 0
    @State private var showsCompletionPayoff = false
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

    private var activeItems: [TodayItem] {
        todayViewModel.items.filter { !$0.completed }
    }

    private var needsAttentionItems: [TodayItem] {
        activeItems.filter(isNeedsAttention)
    }

    private var upNextItems: [TodayItem] {
        activeItems.filter { !isNeedsAttention($0) }
    }

    private var collapsedUpNextLimit: Int {
        needsAttentionItems.isEmpty ? 4 : 3
    }

    private var visibleUpNextItems: [TodayItem] {
        guard upNextItems.count > collapsedUpNextLimit, !isUpNextExpanded, !isReordering else {
            return upNextItems
        }
        return Array(upNextItems.prefix(collapsedUpNextLimit))
    }

    private var hiddenUpNextCount: Int {
        max(upNextItems.count - visibleUpNextItems.count, 0)
    }

    private var completedItems: [TodayItem] {
        todayViewModel.items.filter(\.completed)
    }

    private var focusTitle: String {
        if todayViewModel.totalCount == 0 {
            return "A clear day starts here"
        }
        if todayViewModel.completionRatio == 1 {
            return "Today is complete"
        }
        if let first = needsAttentionItems.first ?? activeItems.first {
            return "Start with \(first.title)"
        }
        return "Keep going"
    }

    private var focusMessage: String {
        if todayViewModel.totalCount == 0 {
            return "Add a habit or task to shape today."
        }
        if todayViewModel.completionRatio == 1 {
            return "Everything planned for today is done. Let the rest stay quiet."
        }
        if !needsAttentionItems.isEmpty {
            return "Time-sensitive and high-focus work stays in view first."
        }
        return "Keep the next small step moving."
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OneScreenBackground(palette: palette)
                List {
                    rowSurface {
                        OneGlassCard(palette: palette) {
                            HStack(alignment: .top, spacing: OneSpacing.md) {
                                VStack(alignment: .leading, spacing: OneSpacing.xs) {
                                    Text(OneDate.longDate(from: dateLocal))
                                        .font(OneType.label)
                                        .foregroundStyle(palette.subtext)
                                    Text(focusTitle)
                                        .font(OneType.title)
                                        .foregroundStyle(palette.text)
                                    Text("\(activeItems.count) remaining of \(todayViewModel.totalCount)")
                                        .font(OneType.secondary)
                                        .foregroundStyle(palette.subtext)
                                    Text(focusMessage)
                                        .font(OneType.body)
                                        .foregroundStyle(palette.text)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 10) {
                                    OneProgressCluster(
                                        palette: palette,
                                        progress: todayViewModel.completionRatio,
                                        label: "\(Int(todayViewModel.completionRatio * 100))%"
                                    )
                                    if todayViewModel.completionRatio == 1 {
                                        Label("Done", systemImage: "checkmark.circle.fill")
                                            .font(OneType.caption.weight(.semibold))
                                            .foregroundStyle(palette.highlight)
                                    } else if !needsAttentionItems.isEmpty {
                                        Label("Needs attention", systemImage: "exclamationmark.circle.fill")
                                            .font(OneType.caption.weight(.semibold))
                                            .foregroundStyle(palette.highlight)
                                    }
                                }
                            }
                        }
                    }

                    if showsCompletionPayoff {
                        rowSurface {
                            OneSurfaceCard(palette: palette) {
                                Label("Day complete", systemImage: "checkmark.seal.fill")
                                    .font(OneType.sectionTitle)
                                    .foregroundStyle(palette.highlight)
                                Text("You finished what you planned today. That progress is ready for review when you return.")
                                    .font(OneType.secondary)
                                    .foregroundStyle(palette.subtext)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    if isReordering {
                        rowSurface {
                            OneSectionHeading(palette: palette, title: "Reorder", meta: "Drag to save order")
                        }

                        ForEach(activeItems) { item in
                            rowSurface {
                                TodayItemCard(
                                    palette: palette,
                                    item: item,
                                    categoryName: categoryName(for: item.categoryId),
                                    categoryIcon: categoryIcon(for: item.categoryId),
                                    isReordering: true,
                                    isHighlighted: item.id == todayViewModel.highlightedItemID,
                                    onToggle: {
                                        Task {
                                            await todayViewModel.toggle(item: item, dateLocal: dateLocal)
                                            await onRefreshAnalytics()
                                        }
                                    }
                                ) {
                                    destination(for: item)
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
                    } else if todayViewModel.items.isEmpty {
                        rowSurface {
                            EmptyStateCard(
                                palette: palette,
                                title: "Nothing is planned for today",
                                message: "Add a habit or task to build your day."
                            )
                        }
                    } else {
                        if !needsAttentionItems.isEmpty {
                            rowSurface {
                                OneSectionHeading(palette: palette, title: "Needs attention", meta: "\(needsAttentionItems.count)")
                            }

                            ForEach(needsAttentionItems) { item in
                                rowSurface {
                                    TodayItemCard(
                                        palette: palette,
                                        item: item,
                                        categoryName: categoryName(for: item.categoryId),
                                        categoryIcon: categoryIcon(for: item.categoryId),
                                        isReordering: false,
                                        isHighlighted: item.id == todayViewModel.highlightedItemID,
                                        onToggle: {
                                            Task {
                                                await todayViewModel.toggle(item: item, dateLocal: dateLocal)
                                                await onRefreshAnalytics()
                                            }
                                        }
                                    ) {
                                        destination(for: item)
                                    }
                                }
                            }
                        }

                        if !upNextItems.isEmpty {
                            rowSurface {
                                HStack {
                                    OneSectionHeading(
                                        palette: palette,
                                        title: "Up next",
                                        meta: hiddenUpNextCount > 0 ? "\(hiddenUpNextCount) hidden" : "\(upNextItems.count)"
                                    )
                                    Spacer()
                                    if hiddenUpNextCount > 0 {
                                        Button(isUpNextExpanded ? "Show less" : "Show all") {
                                            OneHaptics.shared.trigger(.selectionChanged)
                                            withAnimation(OneMotion.animation(.expand)) {
                                                isUpNextExpanded.toggle()
                                            }
                                        }
                                        .font(OneType.label)
                                        .foregroundStyle(palette.accent)
                                    }
                                }
                            }

                            ForEach(visibleUpNextItems) { item in
                                rowSurface {
                                    TodayItemCard(
                                        palette: palette,
                                        item: item,
                                        categoryName: categoryName(for: item.categoryId),
                                        categoryIcon: categoryIcon(for: item.categoryId),
                                        isReordering: false,
                                        isHighlighted: item.id == todayViewModel.highlightedItemID,
                                        onToggle: {
                                            Task {
                                                await todayViewModel.toggle(item: item, dateLocal: dateLocal)
                                                await onRefreshAnalytics()
                                            }
                                        }
                                    ) {
                                        destination(for: item)
                                    }
                                }
                            }
                        }
                    }

                    if !completedItems.isEmpty {
                        rowSurface {
                            OneSurfaceCard(palette: palette) {
                                Button {
                                    OneHaptics.shared.trigger(.selectionChanged)
                                    withAnimation(OneMotion.animation(.expand)) {
                                        isCompletedSectionExpanded.toggle()
                                    }
                                } label: {
                                    HStack(spacing: OneSpacing.sm) {
                                        OneSectionHeading(
                                            palette: palette,
                                            title: "Completed",
                                            meta: "\(completedItems.count)"
                                        )
                                        Spacer()
                                        Image(systemName: isCompletedSectionExpanded ? "chevron.up" : "chevron.down")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(palette.subtext)
                                    }
                                }
                                .onePressable(scale: 0.994)

                                if isCompletedSectionExpanded {
                                    VStack(spacing: OneSpacing.sm) {
                                        ForEach(completedItems) { item in
                                            TodayItemCard(
                                                palette: palette,
                                                item: item,
                                                categoryName: categoryName(for: item.categoryId),
                                                categoryIcon: categoryIcon(for: item.categoryId),
                                                isReordering: false,
                                                isHighlighted: item.id == todayViewModel.highlightedItemID,
                                                onToggle: {
                                                    Task {
                                                        await todayViewModel.toggle(item: item, dateLocal: dateLocal)
                                                        await onRefreshAnalytics()
                                                    }
                                                }
                                            ) {
                                                destination(for: item)
                                            }
                                        }
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

                    rowSurface {
                        Color.clear
                            .frame(height: OneDockLayout.listBottomSpacerHeight)
                    }
                }
            }
        }
        .navigationTitle("Today")
        .oneNavigationBarDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .oneNavigationLeading) {
                Button("Notes") {
                    OneHaptics.shared.trigger(.sheetPresented)
                    onOpenSheet(.notes(anchorDate: dateLocal, periodType: .daily))
                }
            }
            ToolbarItemGroup(placement: .oneNavigationTrailing) {
                Button(isReordering ? "Done" : "Reorder") {
                    OneHaptics.shared.trigger(isReordering ? .reorderDrop : .reorderPickup)
                    withAnimation(OneMotion.animation(.expand)) {
                        isReordering.toggle()
                        isUpNextExpanded = isReordering
                        #if os(iOS)
                        editMode = isReordering ? .active : .inactive
                        #endif
                    }
                }

                Menu {
                    Button("Add task") {
                        OneHaptics.shared.trigger(.sheetPresented)
                        onOpenSheet(.addTodo)
                    }
                    Button("Add habit") {
                        OneHaptics.shared.trigger(.sheetPresented)
                        onOpenSheet(.addHabit)
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 8)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .redacted(reason: todayViewModel.isLoading ? .placeholder : [])
        .oneListRowSpacing(10)
        .onChange(of: todayViewModel.milestoneCount) { _, newValue in
            guard newValue > visibleMilestoneCount else {
                return
            }
            visibleMilestoneCount = newValue
            showsCompletionPayoff = true
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2.6))
                withAnimation(OneMotion.animation(.dismiss)) {
                    showsCompletionPayoff = false
                }
            }
        }
        #if os(iOS)
        .oneListEditing(editMode: $editMode)
        #endif
    }

    private func isNeedsAttention(_ item: TodayItem) -> Bool {
        item.priorityTier == .urgent || item.priorityTier == .high || isOverdue(item)
    }

    private func isOverdue(_ item: TodayItem) -> Bool {
        guard let dueAt = item.dueAt else {
            return false
        }
        return dueAt < Date()
    }

    @ViewBuilder
    private func destination(for item: TodayItem) -> some View {
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

    private var primarySummary: PeriodSummary? {
        viewModel.summary ?? viewModel.weekly
    }

    private var headlineInsight: String {
        guard let summary = primarySummary else {
            return "Your progress will appear here once you complete habits or tasks."
        }
        if summary.completionRate >= 0.8 {
            return "You are keeping strong momentum this \(periodTitle(summary.periodType).lowercased())."
        }
        if summary.activeDays == 0 {
            return "No activity is recorded for this \(periodTitle(summary.periodType).lowercased()) yet."
        }
        return "You completed \(summary.completedItems) of \(summary.expectedItems) planned items."
    }

    var body: some View {
        NavigationStack {
            OneScrollScreen(
                palette: palette,
                bottomPadding: OneDockLayout.tabScreenBottomPadding
            ) {
                OneSurfaceCard(palette: palette) {
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

                if let summary = primarySummary {
                    OneGlassCard(palette: palette) {
                        Text(periodTitle(summary.periodType) + " insight")
                            .font(OneType.label)
                            .foregroundStyle(palette.subtext)
                        Text(headlineInsight)
                            .font(OneType.title)
                            .foregroundStyle(palette.text)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 10) {
                            SummaryMetricTile(palette: palette, title: "Completed", value: "\(summary.completedItems)")
                            SummaryMetricTile(palette: palette, title: "Planned", value: "\(summary.expectedItems)")
                            SummaryMetricTile(palette: palette, title: "Completion rate", value: "\(Int(summary.completionRate * 100))%")
                        }
                        HStack(spacing: 10) {
                            SummaryMetricTile(palette: palette, title: "Consistency", value: "\(Int(summary.consistencyScore * 100))%")
                            SummaryMetricTile(palette: palette, title: "Active Days", value: "\(summary.activeDays)")
                            SummaryMetricTile(palette: palette, title: "Range", value: summary.periodEnd)
                        }
                    }
                    .redacted(reason: viewModel.isTransitioning ? .placeholder : [])
                }

                OneSurfaceCard(palette: palette) {
                    OneSectionHeading(
                        palette: palette,
                        title: "Progress",
                        meta: viewModel.selectedPeriod == .monthly
                            ? (viewModel.selectedMonthWeekDetailLabel ?? periodTitle(viewModel.selectedPeriod))
                            : periodTitle(viewModel.selectedPeriod)
                    )
                    if viewModel.chartSeries.values.isEmpty {
                        Text("Complete a few habits or tasks to build this view.")
                            .font(OneType.secondary)
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
                .redacted(reason: viewModel.isTransitioning ? .placeholder : [])

                OneSurfaceCard(palette: palette) {
                    OneSectionHeading(
                        palette: palette,
                        title: "History",
                        meta: contributionMeta
                    )
                    if viewModel.dailySummaries.isEmpty {
                        Text("Your history will appear here.")
                            .font(OneType.secondary)
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
                .redacted(reason: viewModel.isTransitioning ? .placeholder : [])

                if let sentimentOverview = viewModel.sentimentOverview {
                    OneSurfaceCard(palette: palette) {
                        OneSectionHeading(palette: palette, title: "Notes mood", meta: sentimentOverview.dominant?.title ?? "No dominant pattern")
                        AnalyticsSentimentOverviewView(
                            palette: palette,
                            periodType: viewModel.selectedPeriod,
                            overview: sentimentOverview,
                            highlightedDates: viewModel.selectedPeriod == .monthly ? Set(viewModel.dailySummaries.map(\.dateLocal)) : [],
                            onOpenDate: onOpenNotes
                        )
                    }
                    .redacted(reason: viewModel.isTransitioning ? .placeholder : [])
                }

                if let message = viewModel.errorMessage {
                    InlineStatusCard(message: message, kind: .danger, palette: palette)
                }
            }
            .navigationTitle("Analytics")
            .oneNavigationBarDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .oneNavigationTrailing) {
                    Menu {
                        ForEach(AnalyticsActivityFilter.allCases, id: \.self) { filter in
                            Button(filter.title) {
                                viewModel.selectActivityFilter(filter)
                            }
                        }
                    } label: {
                        Label(viewModel.selectedActivityFilter.title, systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
            }
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
            OneScrollScreen(
                palette: palette,
                bottomPadding: 36
            ) {
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
                .oneEntranceReveal(index: 1)

                if let summary = viewModel.sentimentSummary {
                    OneSurfaceCard(palette: palette) {
                        OneSectionHeading(
                            palette: palette,
                            title: "Period summary",
                            meta: summary.dominant?.title ?? "No clear pattern"
                        )
                        HStack(spacing: 10) {
                            SummaryMetricTile(palette: palette, title: "Notes", value: "\(summary.noteCount)")
                            SummaryMetricTile(palette: palette, title: "Active Days", value: "\(summary.activeDays)")
                            SummaryMetricTile(
                                palette: palette,
                                title: "Dominant",
                                value: summary.dominant?.title ?? "-"
                            )
                        }
                        if !summary.distribution.isEmpty {
                            FlowLayout(spacing: 8) {
                                ForEach(summary.distribution) { item in
                                    OneChip(
                                        palette: palette,
                                        title: "\(item.sentiment.title) \(item.count)",
                                        kind: item.sentiment.chipKind
                                    )
                                }
                            }
                        }
                    }
                    .oneEntranceReveal(index: 2)
                }

                OneSurfaceCard(palette: palette) {
                    OneSectionHeading(
                        palette: palette,
                        title: "Entries",
                        meta: viewModel.selectedDayTitle
                    )

                    if viewModel.selectedDayNotes.isEmpty {
                        EmptyStateCard(
                            palette: palette,
                            title: "No notes for this date",
                            message: "Choose another day or save a note to start building history."
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
                .oneEntranceReveal(index: 3)

                OneSurfaceCard(palette: palette) {
                    OneSectionHeading(
                        palette: palette,
                        title: "Browse dates",
                        meta: notesPeriodTitle(viewModel.selectedPeriod)
                    )
                    HStack(spacing: 14) {
                        Button {
                            OneHaptics.shared.trigger(.selectionChanged)
                            viewModel.moveSelection(by: -1)
                        } label: {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(palette.accent)
                        }
                        .onePressable(scale: 0.94)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.currentRangeTitle)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(palette.text)
                            Text(viewModel.selectedDayTitle)
                                .font(OneType.secondary)
                                .foregroundStyle(palette.subtext)
                        }

                        Spacer()

                        Button {
                            OneHaptics.shared.trigger(.selectionChanged)
                            viewModel.moveSelection(by: 1)
                        } label: {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(palette.accent)
                        }
                        .onePressable(scale: 0.94)
                    }
                }
                .oneEntranceReveal(index: 4)

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
                .oneEntranceReveal(index: 5)

                if let message = viewModel.errorMessage {
                    InlineStatusCard(message: message, kind: .danger, palette: palette)
                        .oneEntranceReveal(index: 6)
                }
            }
            .navigationTitle("Notes")
            .oneNavigationBarDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .oneNavigationTrailing) {
                    Button("Done") {
                        OneHaptics.shared.trigger(.sheetDismissed)
                        onDismiss()
                    }
                }
            }
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
                    OneHaptics.shared.trigger(.destructiveConfirmed)
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
                OneHaptics.shared.trigger(.selectionChanged)
                onSelect(option.dateLocal)
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(option.weekdayLabel.uppercased())
                            .font(OneType.caption)
                            .foregroundStyle(palette.subtext)
                        Text("\(option.dayNumber)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(palette.text)
                    }
                    Spacer()
                    Image(systemName: option.sentiment?.symbolName ?? (option.hasNotes ? "circle.fill" : "circle"))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(option.sentiment?.tint(in: palette) ?? palette.subtext)
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
            .onePressable(scale: 0.985)
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
                    OneHaptics.shared.trigger(.selectionChanged)
                    onSelect(option.dateLocal)
                } label: {
                    VStack(spacing: 6) {
                        Text(option.weekdayLabel.uppercased())
                            .font(OneType.caption)
                            .foregroundStyle(option.dateLocal == selectedDateLocal ? palette.text : palette.subtext)
                        Text("\(option.dayNumber)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(palette.text)
                        Circle()
                            .fill(option.sentiment?.tint(in: palette) ?? (option.hasNotes ? palette.subtext : Color.clear))
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .stroke(option.hasNotes ? Color.clear : palette.border, lineWidth: 1)
                            )
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
                .onePressable(scale: 0.97)
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
                    OneHaptics.shared.trigger(.selectionChanged)
                    onSelect(option.month)
                } label: {
                    VStack(spacing: 4) {
                        Text(option.label)
                            .font(OneType.label)
                            .foregroundStyle(palette.text)
                        Text(option.dominant?.title ?? "No notes")
                            .font(OneType.caption)
                            .foregroundStyle(option.dominant?.tint(in: palette) ?? palette.subtext)
                        Text("\(option.noteCount)")
                            .font(OneType.caption)
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
                .onePressable(scale: 0.97)
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
                    OneHaptics.shared.trigger(.selectionChanged)
                    onSelect(option.dateLocal)
                } label: {
                    VStack(spacing: 4) {
                        Text("\(option.dayNumber)")
                            .font(OneType.label)
                            .foregroundStyle(palette.text)
                        Circle()
                            .fill(option.sentiment?.tint(in: palette) ?? (option.hasNotes ? palette.subtext : Color.clear))
                            .frame(width: 7, height: 7)
                            .overlay(
                                Circle()
                                    .stroke(option.hasNotes ? Color.clear : palette.border.opacity(0.5), lineWidth: 1)
                            )
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
                .onePressable(scale: 0.96)
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
            List {
                Section("Account") {
                    TextField("Your name", text: $displayName)
                    LabeledContent("Time zone", value: deviceTimezoneID)
                    Button("Save name") {
                        Task {
                            await profileViewModel.saveProfile(displayName: displayName)
                        }
                    }
                }

                Section("Appearance") {
                    Picker("Theme", selection: $selectedTheme) {
                        Text("System").tag(Theme.system)
                        Text("Light").tag(Theme.light)
                        Text("Dark").tag(Theme.dark)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedTheme) { _, theme in
                        OneHaptics.shared.trigger(.selectionChanged)
                        Task {
                            await profileViewModel.savePreferences(
                                input: UserPreferencesUpdateInput(theme: theme)
                            )
                        }
                    }
                }

                Section("Notifications") {
                    Button {
                        OneHaptics.shared.trigger(.sheetPresented)
                        onOpenSheet(.notifications)
                    } label: {
                        LabeledContent("Open notifications", value: notificationMeta)
                    }
                }

                Section("Coach") {
                    Button {
                        OneHaptics.shared.trigger(.sheetPresented)
                        onOpenSheet(.coach)
                    } label: {
                        LabeledContent("Open coach", value: coachViewModel.cards.first?.title ?? "Daily guidance that stays secondary.")
                    }
                }

                Section("About") {
                    Text("ONE is built for calm daily execution on iPhone. Data stays on this device unless you choose an account.")
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        OneHaptics.shared.trigger(.destructiveConfirmed)
                        Task {
                            await authViewModel.logout()
                        }
                    }
                } footer: {
                    Text("Signing out ends the current session on this device.")
                }

                if let message = profileViewModel.errorMessage {
                    Section {
                        InlineStatusCard(message: message, kind: .danger, palette: palette)
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(OneScreenBackground(palette: palette))
            .navigationTitle("Settings")
            .oneNavigationBarDisplayMode(.large)
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

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var selectedCategoryID = ""
    @State private var notes = ""
    @State private var recurrence = HabitRecurrenceRule()
    @State private var selectedPriorityTier: PriorityTier = .standard
    @State private var usesPreferredTime = false
    @State private var preferredTimeSelection = Date()
    @State private var showsAdvanced = false
    @Environment(\.colorScheme) private var colorScheme

    private var palette: OneTheme.Palette {
        OneTheme.palette(for: colorScheme)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Habit") {
                    TextField("Morning workout", text: $title)
                    Picker("Category", selection: $selectedCategoryID) {
                        ForEach(categories, id: \.id) { category in
                            Text(category.name).tag(category.id)
                        }
                    }
                }

                Section("Schedule") {
                    RecurrenceBuilderCard(palette: palette, recurrence: $recurrence)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

                    Toggle("Preferred time", isOn: $usesPreferredTime)
                    if usesPreferredTime {
                        DatePicker("Time", selection: $preferredTimeSelection, displayedComponents: [.hourAndMinute])
                    }
                }

                Section {
                    PriorityTierSelector(
                        palette: palette,
                        title: "Focus level",
                        subtitle: "High and urgent habits stay more visible in Today.",
                        selection: selectedPriorityTier
                    ) { tier in
                        selectedPriorityTier = tier
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }

                Section {
                    Button(showsAdvanced ? "Hide more options" : "More options") {
                        withAnimation(OneMotion.animation(.expand)) {
                            showsAdvanced.toggle()
                        }
                    }
                }

                if showsAdvanced {
                    Section("Notes") {
                        OneTextEditorField(title: "Notes", text: $notes, placeholder: "Optional context")
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(OneScreenBackground(palette: palette))
            .navigationTitle("Add Habit")
            .oneNavigationBarDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .oneNavigationLeading) {
                    Button("Cancel") {
                        OneHaptics.shared.trigger(.sheetDismissed)
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .oneNavigationTrailing) {
                    Button("Add") {
                        Task {
                            await onSave(
                                HabitCreateInput(
                                    categoryId: selectedCategoryID,
                                    title: title,
                                    notes: notes,
                                    recurrenceRule: recurrence.rawValue,
                                    priorityWeight: selectedPriorityTier.representativeValue,
                                    preferredTime: usesPreferredTime ? OneTimeValueFormatter.string(from: preferredTimeSelection) : nil
                                )
                            )
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedCategoryID.isEmpty)
                    .fontWeight(.semibold)
                }
            }
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

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var notes = ""
    @State private var selectedCategoryID = ""
    @State private var selectedPriorityTier: PriorityTier = .standard
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var showsAdvanced = false
    @Environment(\.colorScheme) private var colorScheme

    private var palette: OneTheme.Palette {
        OneTheme.palette(for: colorScheme)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Submit project draft", text: $title)
                    Picker("Category", selection: $selectedCategoryID) {
                        ForEach(categories, id: \.id) { category in
                            Text(category.name).tag(category.id)
                        }
                    }
                }

                Section("Timing") {
                    Toggle("Due date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Due date", selection: $dueDate)
                    }
                }

                Section {
                    PriorityTierSelector(
                        palette: palette,
                        title: "Focus level",
                        subtitle: "Urgent tasks stay at the top of Today.",
                        selection: selectedPriorityTier
                    ) { tier in
                        selectedPriorityTier = tier
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }

                Section {
                    Button(showsAdvanced ? "Hide more options" : "More options") {
                        withAnimation(OneMotion.animation(.expand)) {
                            showsAdvanced.toggle()
                        }
                    }
                }

                if showsAdvanced {
                    Section("Notes") {
                        OneTextEditorField(title: "Notes", text: $notes, placeholder: "Optional context")
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(OneScreenBackground(palette: palette))
            .navigationTitle("Add Task")
            .oneNavigationBarDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .oneNavigationLeading) {
                    Button("Cancel") {
                        OneHaptics.shared.trigger(.sheetDismissed)
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .oneNavigationTrailing) {
                    Button("Add") {
                        Task {
                            await onSave(
                                TodoCreateInput(
                                    categoryId: selectedCategoryID,
                                    title: title,
                                    notes: notes,
                                    dueAt: hasDueDate ? dueDate : nil,
                                    priority: selectedPriorityTier.representativeValue,
                                    isPinned: selectedPriorityTier == .urgent
                                )
                            )
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedCategoryID.isEmpty)
                    .fontWeight(.semibold)
                }
            }
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
    @State private var selectedCategoryID = ""
    @State private var notes = ""
    @State private var recurrenceRule = HabitRecurrenceRule()
    @State private var selectedPriorityTier: PriorityTier = .standard
    @State private var isActive = true
    @State private var stats: HabitStats?
    @State private var pendingDelete = false
    @State private var usesPreferredTime = false
    @State private var preferredTimeSelection = Date()
    @State private var showsAdvanced = false
    @Environment(\.colorScheme) private var colorScheme

    private var palette: OneTheme.Palette {
        OneTheme.palette(for: colorScheme)
    }

    private var habit: Habit? {
        tasksViewModel.habits.first(where: { $0.id == habitId })
    }

    var body: some View {
        Form {
            Section("Overview") {
                LabeledContent("Schedule", value: recurrenceRule.summary)
                LabeledContent("Status", value: isActive ? "Active" : "Paused")
                LabeledContent("Focus level", value: selectedPriorityTier.title)
                if let stats {
                    LabeledContent("Current streak", value: "\(stats.streakCurrent)")
                    LabeledContent("Completed", value: "\(stats.completedWindow)")
                    LabeledContent("Completion", value: "\(Int(stats.completionRateWindow * 100))%")
                }
                if usesPreferredTime {
                    LabeledContent("Preferred time", value: OneDate.timeString(from: preferredTimeSelection))
                }
            }

            Section("Details") {
                TextField("Habit name", text: $title)
                Picker("Category", selection: $selectedCategoryID) {
                    ForEach(tasksViewModel.categories, id: \.id) { category in
                        Text(category.name).tag(category.id)
                    }
                }
                Toggle("Active", isOn: $isActive)
                Toggle("Preferred time", isOn: $usesPreferredTime)
                if usesPreferredTime {
                    DatePicker("Time", selection: $preferredTimeSelection, displayedComponents: [.hourAndMinute])
                }
            }

            Section("Schedule builder") {
                RecurrenceBuilderCard(palette: palette, recurrence: $recurrenceRule)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            }

            Section {
                PriorityTierSelector(
                    palette: palette,
                    title: "Focus level",
                    subtitle: "Paused habits stay out of Today. Higher focus levels stay visible when active.",
                    selection: selectedPriorityTier
                ) { tier in
                    selectedPriorityTier = tier
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            }

            Section {
                Button(showsAdvanced ? "Hide more options" : "More options") {
                    withAnimation(OneMotion.animation(.expand)) {
                        showsAdvanced.toggle()
                    }
                }
            }

            if showsAdvanced {
                Section("Notes") {
                    OneTextEditorField(title: "Notes", text: $notes, placeholder: "Optional context")
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }
            }

            Section {
                Button("Delete habit", role: .destructive) {
                    pendingDelete = true
                }
            } footer: {
                Text("Deleting this habit removes it from future schedules.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(OneScreenBackground(palette: palette))
        .navigationTitle(habit?.title ?? "Habit")
        .oneNavigationBarDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .oneNavigationTrailing) {
                Button("Save") {
                    Task {
                        guard await tasksViewModel.updateHabit(
                            id: habitId,
                            input: HabitUpdateInput(
                                categoryId: selectedCategoryID,
                                title: title,
                                notes: notes,
                                recurrenceRule: recurrenceRule.rawValue,
                                priorityWeight: selectedPriorityTier.representativeValue,
                                preferredTime: usesPreferredTime ? OneTimeValueFormatter.string(from: preferredTimeSelection) : nil,
                                isActive: isActive
                            )
                        ) != nil else {
                            return
                        }
                        await onSave()
                        dismiss()
                    }
                }
                .fontWeight(.semibold)
            }
        }
        .task {
            if tasksViewModel.habits.isEmpty {
                await tasksViewModel.loadTasks()
            }
            hydrateFromHabit()
            stats = await tasksViewModel.loadHabitStats(habitId: habitId, anchorDate: anchorDate, windowDays: 30)
        }
        .confirmationDialog("Delete this habit?", isPresented: $pendingDelete, titleVisibility: .visible) {
            Button("Delete habit", role: .destructive) {
                OneHaptics.shared.trigger(.destructiveConfirmed)
                Task {
                    if await tasksViewModel.deleteHabit(id: habitId) {
                        await onSave()
                        dismiss()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the habit from future schedules.")
        }
    }

    private func hydrateFromHabit() {
        guard let habit else {
            return
        }
        title = habit.title
        selectedCategoryID = habit.categoryId
        notes = habit.notes
        recurrenceRule = HabitRecurrenceRule(rawValue: habit.recurrenceRule)
        selectedPriorityTier = habit.priorityTier
        isActive = habit.isActive
        usesPreferredTime = habit.preferredTime != nil
        if let preferredTime = OneTimeValueFormatter.date(from: habit.preferredTime) {
            preferredTimeSelection = preferredTime
        }
    }
}

private struct TodoDetailView: View {
    let todoId: String
    @ObservedObject var tasksViewModel: TasksViewModel
    let onSave: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var selectedCategoryID = ""
    @State private var notes = ""
    @State private var selectedPriorityTier: PriorityTier = .standard
    @State private var status: TodoStatus = .open
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var pendingDelete = false
    @State private var showsAdvanced = false
    @Environment(\.colorScheme) private var colorScheme

    private var palette: OneTheme.Palette {
        OneTheme.palette(for: colorScheme)
    }

    private var todo: Todo? {
        tasksViewModel.todos.first(where: { $0.id == todoId })
    }

    var body: some View {
        Form {
            Section("Overview") {
                LabeledContent("Status", value: statusTitle)
                LabeledContent("Focus level", value: selectedPriorityTier.title)
                LabeledContent("Due", value: hasDueDate ? OneDate.dateTimeString(from: dueDate) : "No due date")
            }

            Section("Details") {
                TextField("Task title", text: $title)
                Picker("Category", selection: $selectedCategoryID) {
                    ForEach(tasksViewModel.categories, id: \.id) { category in
                        Text(category.name).tag(category.id)
                    }
                }
                Picker("Status", selection: $status) {
                    Text("Open").tag(TodoStatus.open)
                    Text("Completed").tag(TodoStatus.completed)
                    Text("Canceled").tag(TodoStatus.canceled)
                }
                Toggle("Due date", isOn: $hasDueDate)
                if hasDueDate {
                    DatePicker("Due at", selection: $dueDate)
                }
            }

            Section {
                PriorityTierSelector(
                    palette: palette,
                    title: "Focus level",
                    subtitle: "Urgent tasks stay at the top of Today.",
                    selection: selectedPriorityTier
                ) { tier in
                    selectedPriorityTier = tier
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            }

            Section {
                Button(showsAdvanced ? "Hide more options" : "More options") {
                    withAnimation(OneMotion.animation(.expand)) {
                        showsAdvanced.toggle()
                    }
                }
            }

            if showsAdvanced {
                Section("Notes") {
                    OneTextEditorField(title: "Notes", text: $notes, placeholder: "Optional context")
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }
            }

            Section {
                Button("Delete task", role: .destructive) {
                    pendingDelete = true
                }
            } footer: {
                Text("Deleting this task removes it from Today and future follow-up.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(OneScreenBackground(palette: palette))
        .navigationTitle(todo?.title ?? "Task")
        .oneNavigationBarDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .oneNavigationTrailing) {
                Button("Save") {
                    Task {
                        guard await tasksViewModel.updateTodo(
                            id: todoId,
                            input: TodoUpdateInput(
                                categoryId: selectedCategoryID,
                                title: title,
                                notes: notes,
                                dueAt: hasDueDate ? dueDate : nil,
                                priority: selectedPriorityTier.representativeValue,
                                isPinned: selectedPriorityTier == .urgent,
                                status: status
                            )
                        ) != nil else {
                            return
                        }
                        await onSave()
                        dismiss()
                    }
                }
                .fontWeight(.semibold)
            }
        }
        .task {
            if tasksViewModel.todos.isEmpty {
                await tasksViewModel.loadTasks()
            }
            hydrateFromTodo()
        }
        .confirmationDialog("Delete this task?", isPresented: $pendingDelete, titleVisibility: .visible) {
            Button("Delete task", role: .destructive) {
                OneHaptics.shared.trigger(.destructiveConfirmed)
                Task {
                    if await tasksViewModel.deleteTodo(id: todoId) {
                        await onSave()
                        dismiss()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the task from Today and future follow-up.")
        }
    }

    private func hydrateFromTodo() {
        guard let todo else {
            return
        }
        title = todo.title
        selectedCategoryID = todo.categoryId
        notes = todo.notes
        selectedPriorityTier = todo.priorityTier
        status = todo.status
        hasDueDate = todo.dueAt != nil
        if let dueAt = todo.dueAt {
            dueDate = dueAt
        }
    }

    private var statusTitle: String {
        switch status {
        case .open:
            return "Open"
        case .completed:
            return "Completed"
        case .canceled:
            return "Canceled"
        }
    }
}

private struct NotificationPreferencesView: View {
    @ObservedObject var profileViewModel: ProfileViewModel
    let onClose: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var habitReminders = true
    @State private var todoReminders = true
    @State private var reflectionPrompts = true
    @State private var weeklySummary = true
    @State private var quietHoursStartSelection = OneTimeValueFormatter.date(from: "22:00:00") ?? Date()
    @State private var quietHoursEndSelection = OneTimeValueFormatter.date(from: "07:00:00") ?? Date()
    @State private var coachEnabled = true
    @Environment(\.colorScheme) private var colorScheme

    private var palette: OneTheme.Palette {
        OneTheme.palette(for: colorScheme)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Reminder types") {
                    Toggle("Habit reminders", isOn: $habitReminders)
                    Toggle("Task reminders", isOn: $todoReminders)
                    Toggle("Notes prompts", isOn: $reflectionPrompts)
                    Toggle("Weekly summary", isOn: $weeklySummary)
                    Toggle("Coach prompts", isOn: $coachEnabled)
                }

                Section {
                    DatePicker("Starts", selection: $quietHoursStartSelection, displayedComponents: [.hourAndMinute])
                    DatePicker("Ends", selection: $quietHoursEndSelection, displayedComponents: [.hourAndMinute])
                } header: {
                    Text("Quiet hours")
                } footer: {
                    Text("Quiet hours silence reminders between the times you set here.")
                }

                if let status = profileViewModel.notificationStatus {
                    Section {
                        LabeledContent("Permission", value: status.permissionGranted ? "On" : "Off")
                        LabeledContent("Scheduled", value: "\(status.scheduledCount)")
                        if let lastRefreshedAt = status.lastRefreshedAt {
                            LabeledContent("Last refreshed", value: lastRefreshedAt.formatted(date: .abbreviated, time: .shortened))
                        }
                        Button("Refresh schedules") {
                            Task {
                                await profileViewModel.refreshSchedules()
                            }
                        }
                        if !status.permissionGranted {
                            Button("Open iPhone Settings") {
                                openSystemSettings()
                            }
                        }
                        if let error = status.lastError, !error.isEmpty {
                            InlineStatusCard(message: error, kind: .danger, palette: palette)
                                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        }
                    } header: {
                        Text("Schedule status")
                    } footer: {
                        Text(
                            status.permissionGranted
                            ? "Reminders are being scheduled on this device."
                            : "Reminder scheduling needs notification permission in iOS Settings."
                        )
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(OneScreenBackground(palette: palette))
            .navigationTitle("Notifications")
            .oneNavigationBarDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .oneNavigationLeading) {
                    Button("Done") {
                        OneHaptics.shared.trigger(.sheetDismissed)
                        onClose()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .oneNavigationTrailing) {
                    Button("Save") {
                        Task {
                            await profileViewModel.savePreferences(
                                input: UserPreferencesUpdateInput(
                                    quietHoursStart: OneTimeValueFormatter.string(from: quietHoursStartSelection),
                                    quietHoursEnd: OneTimeValueFormatter.string(from: quietHoursEndSelection),
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
                    .fontWeight(.semibold)
                }
            }
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
        if let quietHoursStart = OneTimeValueFormatter.date(from: preferences.quietHoursStart) {
            quietHoursStartSelection = quietHoursStart
        }
        if let quietHoursEnd = OneTimeValueFormatter.date(from: preferences.quietHoursEnd) {
            quietHoursEndSelection = quietHoursEnd
        }
        coachEnabled = preferences.coachEnabled
    }

    private func openSystemSettings() {
        #if os(iOS)
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        UIApplication.shared.open(url)
        #endif
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
            OneScrollScreen(palette: palette, bottomPadding: 36) {
                if viewModel.cards.isEmpty {
                    EmptyStateCard(
                        palette: palette,
                        title: "No coach content yet",
                        message: "Guidance will appear here when it is available."
                    )
                    .oneEntranceReveal(index: 1)
                } else {
                    if let featuredCard = viewModel.cards.first {
                        OneGlassCard(palette: palette) {
                            Text("Today")
                                .font(OneType.label)
                                .foregroundStyle(palette.highlight)
                            Text(featuredCard.title)
                                .font(OneType.title)
                                .foregroundStyle(palette.text)
                            Text(featuredCard.body)
                                .font(OneType.body)
                                .foregroundStyle(palette.subtext)
                                .fixedSize(horizontal: false, vertical: true)
                            CoachVerseBlock(palette: palette, card: featuredCard)
                        }
                        .oneEntranceReveal(index: 0)
                    }

                    ForEach(Array(viewModel.cards.dropFirst().enumerated()), id: \.element.id) { index, card in
                        OneSurfaceCard(palette: palette) {
                            Text(card.title)
                                .font(OneType.sectionTitle)
                                .foregroundStyle(palette.text)
                            Text(card.body)
                                .font(OneType.body)
                                .foregroundStyle(palette.subtext)
                                .fixedSize(horizontal: false, vertical: true)
                            CoachVerseBlock(palette: palette, card: card)
                        }
                        .oneEntranceReveal(index: index + 1)
                    }
                }

                if let message = viewModel.errorMessage {
                    InlineStatusCard(message: message, kind: .danger, palette: palette)
                        .oneEntranceReveal(index: 4)
                }
            }
            .navigationTitle("Coach")
            .oneNavigationBarDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .oneNavigationTrailing) {
                    Button("Done") {
                        OneHaptics.shared.trigger(.sheetDismissed)
                        onClose()
                    }
                }
            }
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
    let isHighlighted: Bool
    let onToggle: () -> Void
    @ViewBuilder let destination: Destination
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var supportingLine: String? {
        if let dueAt = item.dueAt {
            return "Due \(OneDate.dateTimeString(from: dueAt))"
        }
        if let preferredTime = item.preferredTime, !preferredTime.isEmpty {
            if let parsedPreferredTime = OneTimeValueFormatter.date(from: preferredTime) {
                return "Around \(OneDate.timeString(from: parsedPreferredTime))"
            }
            return "Around \(preferredTime)"
        }
        return item.subtitle?.hasPrefix("Habit ·") == true ? nil : item.subtitle
    }

    private var itemTypeTitle: String {
        item.itemType == .habit ? "Habit" : "Task"
    }

    private var metadataLine: String {
        [itemTypeTitle, categoryName].joined(separator: " · ")
    }

    private var priorityTier: PriorityTier {
        item.priorityTier
    }

    private var isOverdue: Bool {
        guard let dueAt = item.dueAt, !item.completed else {
            return false
        }
        return dueAt < Date()
    }

    private var emphasisColor: Color {
        if isOverdue || priorityTier == .urgent {
            return palette.danger
        }
        if priorityTier == .high {
            return palette.highlight
        }
        return palette.accent
    }

    var body: some View {
        OneSurfaceCard(palette: palette) {
            HStack(alignment: .top, spacing: 12) {
                Button(action: onToggle) {
                    Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(item.completed ? palette.success : palette.subtext)
                        .scaleEffect(isHighlighted && !reduceMotion ? 1.08 : 1)
                }
                .onePressable(scale: 0.92, opacity: 0.85)
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(item.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(item.completed ? palette.subtext : palette.text)
                            .strikethrough(item.completed, color: palette.subtext)
                        if priorityTier == .high || priorityTier == .urgent {
                            Text(priorityTier.title)
                                .font(OneType.caption.weight(.semibold))
                                .foregroundStyle(emphasisColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(emphasisColor.opacity(0.12))
                                )
                        }
                    }
                    if let supportingLine, !supportingLine.isEmpty {
                        Text(supportingLine)
                            .font(OneType.secondary)
                            .foregroundStyle(isOverdue ? palette.danger : palette.subtext)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(metadataLine)
                        .font(OneType.caption)
                        .foregroundStyle(palette.subtext)
                        .fixedSize(horizontal: false, vertical: true)
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
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(palette.accent)
                            .frame(width: 28, height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: OneTheme.radiusSmall, style: .continuous)
                                    .fill(palette.surfaceMuted)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: OneTheme.radiusSmall, style: .continuous)
                                    .stroke(palette.border, lineWidth: 1)
                            )
                    }
                    .onePressable(scale: 0.96)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: OneTheme.radiusLarge, style: .continuous)
                .fill(
                    isHighlighted
                    ? (item.completed ? palette.success.opacity(palette.isDark ? 0.16 : 0.1) : palette.accentSoft)
                    : Color.clear
                )
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: OneTheme.radiusSmall, style: .continuous)
                .fill(item.completed ? palette.success : emphasisColor)
                .frame(width: 4)
                .padding(.vertical, 12)
                .opacity(item.completed || priorityTier == .high || priorityTier == .urgent || isOverdue ? 1 : 0.2)
        }
        .scaleEffect(isHighlighted && !reduceMotion ? 0.992 : 1)
        .animation(
            OneMotion.animation(item.completed ? .stateChange : .dismiss, reduceMotion: reduceMotion),
            value: isHighlighted
        )
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
    let tier: PriorityTier
    let palette: OneTheme.Palette

    var body: some View {
        Circle()
            .fill(priorityTierColor(for: tier, palette: palette))
            .frame(width: 24, height: 24)
            .overlay(
                Circle()
                    .stroke(palette.surface, lineWidth: 2)
            )
            .overlay(
                Circle()
                    .stroke(priorityTierColor(for: tier, palette: palette).opacity(0.35), lineWidth: 6)
            )
            .accessibilityLabel("\(tier.title) priority")
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
                    .font(OneType.caption)
                    .foregroundStyle(palette.subtext)
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: note.sentiment.symbolName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(note.sentiment.tint(in: palette))
                    Text(note.sentiment.title)
                        .font(OneType.caption)
                        .foregroundStyle(palette.text)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(palette.surface)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(palette.border, lineWidth: 1)
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
                .onePressable(scale: 0.92)
            }
            Text(note.content)
                .font(OneType.body)
                .foregroundStyle(palette.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mood")
                .font(OneType.label)
                .foregroundStyle(palette.subtext)
            FlowLayout(spacing: 8) {
                ForEach(ReflectionSentiment.allCases, id: \.self) { sentiment in
                    Button {
                        OneHaptics.shared.trigger(.selectionChanged)
                        selectedSentiment = sentiment
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: sentiment.symbolName)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(selectedSentiment == sentiment ? sentiment.tint(in: palette) : palette.subtext)
                            Text(sentiment.title)
                                .font(OneType.caption)
                                .foregroundStyle(palette.text)
                        }
                            .frame(width: 82, height: 64)
                            .scaleEffect(selectedSentiment == sentiment && !reduceMotion ? 1.04 : 1)
                            .background(
                                RoundedRectangle(cornerRadius: OneTheme.radiusSmall, style: .continuous)
                                    .fill(selectedSentiment == sentiment ? palette.accentSoft : palette.surfaceMuted)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: OneTheme.radiusSmall, style: .continuous)
                                    .stroke(selectedSentiment == sentiment ? palette.accent : palette.border, lineWidth: 1)
                            )
                    }
                    .onePressable(scale: 0.94, opacity: 0.9)
                    .animation(
                        OneMotion.animation(.stateChange, reduceMotion: reduceMotion),
                        value: selectedSentiment == sentiment
                    )
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
                Text(item.subtitle ?? (item.itemType == .habit ? "Scheduled habit" : "Task"))
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
            .navigationTitle(categoryName)
            .oneNavigationBarDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .oneNavigationTrailing) {
                    Button("Done") {
                        OneHaptics.shared.trigger(.sheetDismissed)
                        onDismiss()
                    }
                }
            }
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
                PriorityBadge(tier: habit.priorityTier, palette: palette)
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

    var symbolName: String {
        switch self {
        case .great:
            return "sun.max.fill"
        case .focused:
            return "scope"
        case .okay:
            return "circle.fill"
        case .tired:
            return "moon.zzz.fill"
        case .stressed:
            return "exclamationmark.circle.fill"
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

    func tint(in palette: OneTheme.Palette) -> Color {
        switch self {
        case .great:
            return palette.success
        case .focused:
            return palette.accent
        case .okay:
            return palette.subtext
        case .tired:
            return palette.warning
        case .stressed:
            return palette.danger
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
                .font(OneType.caption)
                .foregroundStyle(palette.subtext)
            Text(value)
                .font(OneType.title)
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
            VStack(alignment: .leading, spacing: 6) {
                Text(verseRef)
                    .font(OneType.caption)
                    .foregroundStyle(palette.subtext)
                Text(verse)
                    .font(OneType.body)
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
        } else if let verse = card.verseText,
                  !verse.isEmpty {
            Text(verse)
                .font(OneType.body)
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
                .font(OneType.title)
                .foregroundStyle(palette.text)
            Text(message)
                .font(OneType.secondary)
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
                    .font(OneType.secondary)
                    .foregroundStyle(kind == .danger ? palette.danger : palette.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private enum OneTimeValueFormatter {
    private static let storageFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private static let fallbackFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static func string(from date: Date) -> String {
        storageFormatter.string(from: date)
    }

    static func date(from raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else {
            return nil
        }
        return storageFormatter.date(from: raw) ?? fallbackFormatter.date(from: raw)
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

private struct OneSecureField: View {
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
            SecureField(placeholder, text: $text)
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
        .onChange(of: selection) { _, _ in
            OneHaptics.shared.trigger(.selectionChanged)
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
        .animation(OneMotion.animation(.stateChange), value: value)
    }
}

private struct ToggleCard: View {
    let palette: OneTheme.Palette
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                .fill(isOn ? palette.accentSoft : palette.surfaceMuted)
        )
        .overlay(
            RoundedRectangle(cornerRadius: OneTheme.radiusMedium, style: .continuous)
                .stroke(isOn ? palette.accent.opacity(0.55) : palette.border, lineWidth: 1)
        )
        .animation(OneMotion.animation(.stateChange, reduceMotion: reduceMotion), value: isOn)
        .onChange(of: isOn) { _, _ in
            OneHaptics.shared.trigger(.selectionChanged)
        }
    }
}

private struct DatePickerCard: View {
    let palette: OneTheme.Palette
    let title: String
    @Binding var selection: Date
    var displayedComponents: DatePickerComponents = [.date]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.subtext)
            DatePicker("", selection: $selection, displayedComponents: displayedComponents)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        .animation(OneMotion.animation(.stateChange, reduceMotion: reduceMotion), value: selection)
        .onChange(of: selection) { _, _ in
            OneHaptics.shared.trigger(.selectionChanged)
        }
    }
}

private struct RecurrenceBuilderCard: View {
    let palette: OneTheme.Palette
    @Binding var recurrence: HabitRecurrenceRule
    @State private var yearlyDraftDate = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                OneHaptics.shared.trigger(.selectionChanged)
                withAnimation(OneMotion.animation(.stateChange, reduceMotion: reduceMotion)) {
                    recurrence = updated
                }
            }

            Group {
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
                            OneHaptics.shared.trigger(.selectionChanged)
                            withAnimation(OneMotion.animation(.stateChange, reduceMotion: reduceMotion)) {
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
                            OneHaptics.shared.trigger(.selectionChanged)
                            withAnimation(OneMotion.animation(.stateChange, reduceMotion: reduceMotion)) {
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
                                        OneHaptics.shared.trigger(.destructiveConfirmed)
                                        withAnimation(OneMotion.animation(.dismiss, reduceMotion: reduceMotion)) {
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
                            let nextDate = HabitRecurrenceYearlyDate(month: month, day: day)
                            guard !updated.yearlyDates.contains(nextDate) else {
                                return
                            }
                            updated.yearlyDates.append(nextDate)
                            OneHaptics.shared.trigger(.selectionChanged)
                            withAnimation(OneMotion.animation(.stateChange, reduceMotion: reduceMotion)) {
                                recurrence = HabitRecurrenceRule(
                                    frequency: updated.frequency,
                                    weekdays: updated.weekdays,
                                    monthDays: updated.monthDays,
                                    yearlyDates: updated.yearlyDates
                                )
                            }
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.accent)
                        .onePressable(scale: 0.97)
                    }
                }
            }
            }
            .transition(.move(edge: .top).combined(with: .opacity))

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
        .animation(OneMotion.animation(.stateChange, reduceMotion: reduceMotion), value: recurrence.frequency)
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
        .onePressable(scale: 0.96)
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
        .onePressable(scale: 0.96)
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
                    .font(OneType.body)
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
                    .onePressable(scale: 0.96, opacity: 0.92)
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
                .onePressable(scale: 0.96, opacity: 0.92)
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
                            title: "\(item.sentiment.title) \(item.count)",
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
            Image(systemName: point.sentiment?.symbolName ?? "circle")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(point.sentiment?.tint(in: palette) ?? palette.subtext)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(point.sentiment == nil ? palette.surfaceMuted : palette.surface)
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
            .onePressable(scale: 0.96, opacity: 0.92)
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

private func priorityTierColor(for tier: PriorityTier, palette: OneTheme.Palette) -> Color {
    switch tier {
    case .low:
        return palette.subtext
    case .standard:
        return palette.accent
    case .high:
        return palette.highlight
    case .urgent:
        return palette.danger
    }
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

private enum OneNavigationBarDisplayMode {
    case automatic
    case inline
    case large
}

private extension ToolbarItemPlacement {
    static var oneNavigationLeading: ToolbarItemPlacement {
        #if os(iOS)
        .navigationBarLeading
        #else
        .automatic
        #endif
    }

    static var oneNavigationTrailing: ToolbarItemPlacement {
        #if os(iOS)
        .navigationBarTrailing
        #else
        .primaryAction
        #endif
    }
}

private extension View {
    @ViewBuilder
    func oneNavigationBarDisplayMode(_ displayMode: OneNavigationBarDisplayMode) -> some View {
        #if os(iOS)
        switch displayMode {
        case .automatic:
            self.navigationBarTitleDisplayMode(.automatic)
        case .inline:
            self.navigationBarTitleDisplayMode(.inline)
        case .large:
            self.navigationBarTitleDisplayMode(.large)
        }
        #else
        self
        #endif
    }

    @ViewBuilder
    func oneInlineNavigationBarTitle() -> some View {
        #if os(iOS)
        self.oneNavigationBarDisplayMode(.inline)
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
