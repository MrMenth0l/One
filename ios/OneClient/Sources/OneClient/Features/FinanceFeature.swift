#if canImport(SwiftUI)
import SwiftUI
#if canImport(Charts)
import Charts
#endif

private struct FinanceTransactionEditorContext: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let transactionID: String?
    let input: FinanceTransactionWriteInput
}

private struct FinanceCategoryEditorContext: Identifiable, Equatable {
    let id = UUID()
    let categoryID: String?
    let name: String
    let iconName: String
}

private struct FinanceRecurringEditorContext: Identifiable, Equatable {
    let id = UUID()
    let recurringID: String?
    let title: String
    let amount: Double
    let categoryId: String
    let paymentMethod: FinancePaymentMethod
    let cadenceType: FinanceRecurringCadenceType
    let cadenceInterval: Int?
    let nextDueDate: String
    let startDate: String
    let endDate: String?
    let note: String?
}

private enum FinanceSheetRoute: Identifiable, Equatable {
    case transaction(FinanceTransactionEditorContext)
    case balance
    case category(FinanceCategoryEditorContext)
    case recurring(FinanceRecurringEditorContext)
    case voice

    var id: UUID {
        switch self {
        case .transaction(let context):
            return context.id
        case .balance:
            return UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE") ?? UUID()
        case .category(let context):
            return context.id
        case .recurring(let context):
            return context.id
        case .voice:
            return UUID(uuidString: "FFFFFFFF-BBBB-CCCC-DDDD-EEEEEEEEEEEE") ?? UUID()
        }
    }
}

struct FinanceTabView: View {
    @ObservedObject var viewModel: FinanceViewModel
    let weekStart: Int
    @Binding var quickAddRequest: OneAddAction?

    @State private var sheetRoute: FinanceSheetRoute?
    @State private var isShowingAddOptions = false
    @State private var activeRailSection: FinanceUtilityRailSection = .home
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        viewModel: FinanceViewModel,
        weekStart: Int,
        quickAddRequest: Binding<OneAddAction?> = .constant(nil)
    ) {
        self.viewModel = viewModel
        self.weekStart = weekStart
        _quickAddRequest = quickAddRequest
    }

    private var palette: OneTheme.Palette {
        OneTheme.palette(for: colorScheme)
    }

    private var activeCategories: [FinanceCategory] {
        viewModel.activeCategories.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder {
                return lhs.sortOrder < rhs.sortOrder
            }
            return lhs.name < rhs.name
        }
    }

    private var displayedPeriod: FinanceAnalyticsPeriod {
        viewModel.pendingAnalyticsPeriod ?? viewModel.selectedAnalyticsPeriod
    }

    private var currencyCode: String {
        viewModel.homeSnapshot?.balanceState.defaultCurrencyCode ?? "USD"
    }

    private var financeNavigationTitle: String {
        activeRailSection == .home ? "Finance" : activeRailSection.railItem.title
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                currentFinancePage
                    .id(activeRailSection)
                    .safeAreaInset(edge: .top) {
                        Color.clear
                            .frame(height: OneUtilityRailMetrics.persistentTopInset)
                    }
                    .transition(.opacity)

                if viewModel.homeSnapshot != nil {
                    OneUtilityRail(
                        palette: palette,
                        items: FinanceUtilityRailSection.railItems,
                        activeID: activeRailSection,
                        isSticky: true
                    ) { section in
                        OneHaptics.shared.trigger(.selectionChanged)
                        withAnimation(OneMotion.animation(.stateChange, reduceMotion: reduceMotion)) {
                            activeRailSection = section
                        }
                    }
                    .padding(.horizontal, OneUtilityRailMetrics.stickyHorizontalInset)
                    .padding(.top, OneUtilityRailMetrics.stickyTopPadding)
                    .zIndex(1)
                }
            }
            .animation(OneMotion.animation(.stateChange, reduceMotion: reduceMotion), value: activeRailSection)
            .navigationTitle(financeNavigationTitle)
            .oneNavigationBarDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .oneNavigationTrailing) {
                    Button {
                        sheetRoute = .voice
                    } label: {
                        OneAppIcon(
                            key: .ui(.microphone),
                            size: 18
                        )
                    }
                }
            }
            .task {
                if viewModel.homeSnapshot == nil {
                    await viewModel.refreshAll(weekStart: weekStart)
                }
            }
            .onChange(of: quickAddRequest?.rawValue) { _, _ in
                guard let action = quickAddRequest else {
                    return
                }
                defer { quickAddRequest = nil }
                guard action.isFinanceAction else {
                    return
                }
                openCreateTransaction(for: action)
            }
            .refreshable {
                await viewModel.refreshAll(weekStart: weekStart)
            }
            .confirmationDialog("Add to Finance", isPresented: $isShowingAddOptions, titleVisibility: .visible) {
                ForEach(OneAddContext.finance.actions) { action in
                    Button(action.title) {
                        openCreateTransaction(for: action)
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(item: $sheetRoute) { route in
                switch route {
                case .transaction(let context):
                    FinanceTransactionSheet(
                        palette: palette,
                        viewModel: viewModel,
                        weekStart: weekStart,
                        categories: activeCategories,
                        context: context,
                        suggestedPaymentMethod: viewModel.suggestedPaymentMethod
                    ) {
                        sheetRoute = nil
                    }
                case .balance:
                    FinanceBalanceSetupSheet(
                        palette: palette,
                        initialState: viewModel.homeSnapshot?.balanceState
                    ) { input in
                        Task {
                            let saved = await viewModel.saveBalance(input, weekStart: weekStart)
                            if saved {
                                sheetRoute = nil
                            }
                        }
                    } onClose: {
                        sheetRoute = nil
                    }
                case .category(let context):
                    FinanceCategorySheet(
                        palette: palette,
                        context: context
                    ) { input in
                        Task {
                            let success: Bool
                            if let categoryID = context.categoryID {
                                success = await viewModel.updateCategory(id: categoryID, input: input, weekStart: weekStart) != nil
                            } else {
                                success = await viewModel.createCategory(
                                    FinanceCategoryCreateInput(
                                        name: input.name ?? "",
                                        iconName: input.iconName ?? OneIconKey.financeCategory.rawValue
                                    ),
                                    weekStart: weekStart
                                ) != nil
                            }
                            if success {
                                sheetRoute = nil
                            }
                        }
                    } onClose: {
                        sheetRoute = nil
                    }
                case .recurring(let context):
                    FinanceRecurringSheet(
                        palette: palette,
                        categories: activeCategories,
                        context: context
                    ) { input in
                        Task {
                            let success: Bool
                            if let recurringID = context.recurringID {
                                success = await viewModel.updateRecurring(id: recurringID, input: input.asUpdateInput(), weekStart: weekStart) != nil
                            } else {
                                success = await viewModel.createRecurring(input.asCreateInput(), weekStart: weekStart) != nil
                            }
                            if success {
                                sheetRoute = nil
                            }
                        }
                    } onClose: {
                        sheetRoute = nil
                    }
                case .voice:
                    FinanceVoiceCaptureSheet(
                        palette: palette,
                        categories: activeCategories
                    ) { result in
                        sheetRoute = nil
                        sheetRoute = .transaction(
                            FinanceTransactionEditorContext(
                                title: "Confirm Expense",
                                transactionID: nil,
                                input: result.input
                            )
                        )
                    } onClose: {
                        sheetRoute = nil
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var currentFinancePage: some View {
        if let homeSnapshot = viewModel.homeSnapshot {
            switch activeRailSection {
            case .home:
                financePage {
                    homePageContent(snapshot: homeSnapshot)
                }
            case .overview:
                financePage {
                    overviewSection
                }
            case .analysis:
                financePage {
                    analysisSection
                }
            case .transactions:
                financePage {
                    transactionsSection
                }
            case .recurring:
                financePage {
                    recurringSection
                }
            case .categories:
                financePage {
                    categoriesSection(snapshot: homeSnapshot)
                }
            }
        } else {
            financePage {
                OneSurfaceCard(palette: palette) {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .tint(palette.accent)
                    } else {
                        Text("Finance will appear here after the latest workspace refresh.")
                            .font(OneType.secondary)
                            .foregroundStyle(palette.subtext)
                    }
                }
            }
        }
    }

    private func financePage<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        OneScrollScreen(
            palette: palette,
            bottomPadding: OneDockLayout.tabScreenBottomPadding
        ) {
            content()

            if let message = viewModel.errorMessage {
                FinanceInlineStatusCard(message: message, kind: .danger, palette: palette)
            }
        }
    }

    @ViewBuilder
    private func homePageContent(snapshot: FinanceHomeSnapshot) -> some View {
        FinanceHomeSummaryCard(
            palette: palette,
            snapshot: snapshot,
            health: snapshot.cashflowHealth,
            needsSetup: viewModel.needsBalanceSetup,
            onAdjustBalance: {
                sheetRoute = .balance
            },
            onOpenOverview: {
                OneHaptics.shared.trigger(.selectionChanged)
                withAnimation(OneMotion.animation(.stateChange, reduceMotion: reduceMotion)) {
                    activeRailSection = .overview
                }
            }
        )
    }

    private func openCreateTransaction(for action: OneAddAction = .expense) {
        let transactionType = action.financeTransactionType ?? .expense
        sheetRoute = .transaction(
            FinanceTransactionEditorContext(
                title: action.financeSheetTitle ?? "Add Transaction",
                transactionID: nil,
                input: FinanceTransactionWriteInput(
                    type: transactionType,
                    amount: nil,
                    currencyCode: viewModel.homeSnapshot?.balanceState.defaultCurrencyCode,
                    paymentMethod: viewModel.suggestedPaymentMethod,
                    occurredAt: Date(),
                    source: .manual
                )
            )
        )
    }

    private func openEditor(for transaction: FinanceTransaction) {
        sheetRoute = .transaction(
            FinanceTransactionEditorContext(
                title: "Edit Transaction",
                transactionID: transaction.id,
                input: FinanceTransactionWriteInput(
                    type: transaction.type,
                    amount: transaction.amount,
                    currencyCode: transaction.currencyCode,
                    categoryId: transaction.categoryId,
                    paymentMethod: transaction.paymentMethod,
                    transferCounterpartPaymentMethod: transaction.transferCounterpartPaymentMethod,
                    note: transaction.note,
                    occurredAt: transaction.occurredAt,
                    source: transaction.source
                )
            )
        )
    }

    private func openCategoryEditor(for category: FinanceCategory) {
        sheetRoute = .category(
            FinanceCategoryEditorContext(
                categoryID: category.id,
                name: category.name,
                iconName: category.iconName
            )
        )
    }

    private func openRecurringEditor(for recurring: RecurringFinanceTransaction) {
        sheetRoute = .recurring(
            FinanceRecurringEditorContext(
                recurringID: recurring.id,
                title: recurring.title,
                amount: recurring.amount,
                categoryId: recurring.categoryId,
                paymentMethod: recurring.paymentMethod,
                cadenceType: recurring.cadenceType,
                cadenceInterval: recurring.cadenceInterval,
                nextDueDate: recurring.nextDueDate,
                startDate: recurring.startDate,
                endDate: recurring.endDate,
                note: recurring.note
            )
        )
    }

    private func duplicateTransaction(id: String) {
        Task {
            await viewModel.duplicateTransaction(id: id, weekStart: weekStart)
        }
    }

    private func deleteTransaction(id: String) {
        Task {
            await viewModel.deleteTransaction(id: id, weekStart: weekStart)
        }
    }

    private func recurringDraftContext() -> FinanceRecurringEditorContext {
        FinanceRecurringEditorContext(
            recurringID: nil,
            title: "",
            amount: 0,
            categoryId: activeCategories.first?.id ?? "",
            paymentMethod: .card,
            cadenceType: .monthly,
            cadenceInterval: 30,
            nextDueDate: FinanceDateCoding.localDateString(from: Date(), timezoneID: TimeZone.autoupdatingCurrent.identifier),
            startDate: FinanceDateCoding.localDateString(from: Date(), timezoneID: TimeZone.autoupdatingCurrent.identifier),
            endDate: nil,
            note: nil
        )
    }

    private var transactionsSection: some View {
        VStack(spacing: OneSpacing.md) {
            if let snapshot = viewModel.homeSnapshot {
                FinanceTodayPreviewCard(
                    palette: palette,
                    snapshot: snapshot,
                    categories: viewModel.categories
                ) {
                    isShowingAddOptions = true
                }
            }

            OneSurfaceCard(palette: palette) {
                HStack(alignment: .firstTextBaseline, spacing: OneSpacing.sm) {
                    OneSectionHeading(
                        palette: palette,
                        title: "Transactions",
                        meta: viewModel.transactionSections.isEmpty ? nil : "\(viewModel.transactionSections.reduce(0) { $0 + $1.transactions.count })"
                    )
                    Spacer()
                    Button("Quick add") {
                        isShowingAddOptions = true
                    }
                    .font(OneType.label)
                    .foregroundStyle(palette.accent)
                    NavigationLink("Open history") {
                        FinanceTransactionsScreen(
                            viewModel: viewModel,
                            weekStart: weekStart,
                            onEdit: openEditor(for:),
                            onDuplicate: duplicateTransaction(id:),
                            onDelete: deleteTransaction(id:)
                        )
                    }
                    .font(OneType.label)
                    .foregroundStyle(palette.accent)
                }

                if viewModel.transactionSections.isEmpty {
                    Text("No transactions recorded yet. Capture the next expense, income, or transfer when it happens.")
                        .font(OneType.secondary)
                        .foregroundStyle(palette.subtext)
                } else {
                    let previewSections = Array(viewModel.transactionSections.prefix(3))
                    ForEach(previewSections) { section in
                        let previewTransactions = Array(section.transactions.prefix(4))
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(FinanceFormat.longDate(section.dateLocal))
                                    .font(OneType.label)
                                    .foregroundStyle(palette.subtext)
                                Spacer()
                                Text(FinanceFormat.currency(section.total, code: currencyCode))
                                    .font(OneType.label)
                                    .foregroundStyle(palette.subtext)
                            }

                            ForEach(Array(previewTransactions.enumerated()), id: \.element.id) { index, transaction in
                                Button {
                                    openEditor(for: transaction)
                                } label: {
                                    FinanceHistoryRow(
                                        palette: palette,
                                        transaction: transaction,
                                        categories: viewModel.categories,
                                        currencyCode: currencyCode
                                    )
                                }
                                .buttonStyle(.plain)

                                if index < previewTransactions.count - 1 {
                                    Divider().overlay(palette.border)
                                }
                            }
                        }

                        if section.id != previewSections.last?.id {
                            Divider().overlay(palette.border)
                        }
                    }
                }
            }
        }
    }

    private var overviewSection: some View {
        VStack(spacing: OneSpacing.md) {
            OneSurfaceCard(palette: palette) {
                HStack(alignment: .firstTextBaseline, spacing: OneSpacing.sm) {
                    OneSectionHeading(palette: palette, title: "Overview", meta: "Operational")
                    Spacer()
                    Button("Open analysis") {
                        OneHaptics.shared.trigger(.selectionChanged)
                        withAnimation(OneMotion.animation(.stateChange, reduceMotion: reduceMotion)) {
                            activeRailSection = .analysis
                        }
                    }
                    .font(OneType.label)
                    .foregroundStyle(palette.accent)
                }
                Text("Overview holds the supporting finance signals that do not belong on Home. Analysis is where you inspect period behavior and deeper patterns.")
                    .font(OneType.secondary)
                    .foregroundStyle(palette.subtext)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let snapshot = viewModel.homeSnapshot {
                if !snapshot.attentionSignals.isEmpty {
                    FinanceAttentionSignalsCard(
                        palette: palette,
                        signals: snapshot.attentionSignals,
                        currencyCode: currencyCode
                    )
                } else if !snapshot.warnings.isEmpty {
                    ForEach(snapshot.warnings) { warning in
                        FinanceWarningCard(palette: palette, warning: warning)
                    }
                }

                if let safeToSpend = snapshot.safeToSpend {
                    FinanceSafeToSpendCard(
                        palette: palette,
                        summary: safeToSpend,
                        currencyCode: currencyCode,
                        actionTitle: nil,
                        action: nil
                    )
                }

                if let recurringPressure = snapshot.recurringPressure {
                    FinanceRecurringPressureCard(
                        palette: palette,
                        summary: recurringPressure,
                        overview: viewModel.recurringOverview,
                        currencyCode: currencyCode,
                        actionTitle: "Open recurring"
                    ) {
                        OneHaptics.shared.trigger(.selectionChanged)
                        withAnimation(OneMotion.animation(.stateChange, reduceMotion: reduceMotion)) {
                            activeRailSection = .recurring
                        }
                    }
                }

                if !snapshot.categoryDrift.isEmpty {
                    FinanceCategoryPressureCard(
                        palette: palette,
                        categories: snapshot.categoryDrift,
                        currencyCode: currencyCode
                    ) {
                        OneHaptics.shared.trigger(.selectionChanged)
                        withAnimation(OneMotion.animation(.stateChange, reduceMotion: reduceMotion)) {
                            activeRailSection = .analysis
                        }
                    }
                }

                FinanceTodayPreviewCard(
                    palette: palette,
                    snapshot: snapshot,
                    categories: viewModel.categories
                ) {
                    isShowingAddOptions = true
                }
            }
        }
    }

    private var analysisSection: some View {
        VStack(spacing: OneSpacing.md) {
            OneSurfaceCard(palette: palette) {
                HStack(alignment: .firstTextBaseline, spacing: OneSpacing.sm) {
                    OneSectionHeading(palette: palette, title: "Analysis", meta: displayedPeriod.title)
                    Spacer()
                    Button("Back to overview") {
                        OneHaptics.shared.trigger(.selectionChanged)
                        withAnimation(OneMotion.animation(.stateChange, reduceMotion: reduceMotion)) {
                            activeRailSection = .overview
                        }
                    }
                    .font(OneType.label)
                    .foregroundStyle(palette.accent)
                }
                Text("Analysis is for period comparison, category drift inspection, commitment study, and safe-to-spend reasoning.")
                    .font(OneType.secondary)
                    .foregroundStyle(palette.subtext)
                    .fixedSize(horizontal: false, vertical: true)
            }

            FinanceAnalyticsWorkspace(viewModel: viewModel, weekStart: weekStart)
        }
    }

    private var recurringSection: some View {
        VStack(spacing: OneSpacing.md) {
            if let overview = viewModel.recurringOverview {
                if let recurringPressure = viewModel.homeSnapshot?.recurringPressure {
                    FinanceRecurringPressureCard(
                        palette: palette,
                        summary: recurringPressure,
                        overview: overview,
                        currencyCode: currencyCode,
                        actionTitle: "Review commitments"
                    ) {
                        OneHaptics.shared.trigger(.selectionChanged)
                    }
                }

                OneGlassCard(palette: palette) {
                    HStack(alignment: .firstTextBaseline, spacing: OneSpacing.sm) {
                        Text("Recurring")
                            .font(OneType.label)
                            .foregroundStyle(palette.subtext)
                        Spacer()
                        NavigationLink("Manage") {
                            FinanceRecurringScreen(
                                viewModel: viewModel,
                                weekStart: weekStart,
                                onEdit: openRecurringEditor(for:)
                            ) {
                                sheetRoute = .recurring(recurringDraftContext())
                            }
                        }
                        .font(OneType.label)
                        .foregroundStyle(palette.accent)
                    }

                    HStack(spacing: 10) {
                        FinanceMetricTile(
                            palette: palette,
                            title: "Monthly",
                            value: FinanceFormat.currency(overview.monthlyTotal, code: currencyCode)
                        )
                        FinanceMetricTile(
                            palette: palette,
                            title: "Yearly",
                            value: FinanceFormat.currency(overview.yearlyTotal, code: currencyCode)
                        )
                    }

                    OneActionButton(palette: palette, title: "Add recurring", style: .primary) {
                        sheetRoute = .recurring(recurringDraftContext())
                    }
                }

                if !overview.upcomingCharges.isEmpty {
                    OneSurfaceCard(palette: palette) {
                        OneSectionHeading(palette: palette, title: "Upcoming", meta: nil)
                        ForEach(overview.upcomingCharges) { charge in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(charge.title)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(palette.text)
                                    Text("Due \(FinanceFormat.longDate(charge.dueDate))")
                                        .font(OneType.secondary)
                                        .foregroundStyle(palette.subtext)
                                }
                                Spacer()
                                Text(FinanceFormat.currency(charge.amount, code: currencyCode))
                                    .font(OneType.secondary.weight(.semibold))
                                    .foregroundStyle(palette.text)
                            }
                        }
                    }
                }

                if overview.activeItems.isEmpty {
                    OneSurfaceCard(palette: palette) {
                        Text("Recurring charges will appear here after you add the first item.")
                            .font(OneType.secondary)
                            .foregroundStyle(palette.subtext)
                    }
                } else {
                    ForEach(overview.activeItems) { recurring in
                        OneSurfaceCard(palette: palette) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(recurring.title)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(palette.text)
                                    Text("\(recurring.cadenceType.title) · \(recurring.paymentMethod.title)")
                                        .font(OneType.secondary)
                                        .foregroundStyle(palette.subtext)
                                    Text("Next charge \(FinanceFormat.longDate(recurring.nextDueDate))")
                                        .font(OneType.caption)
                                        .foregroundStyle(palette.subtext)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 8) {
                                    Text(FinanceFormat.currency(recurring.amount, code: currencyCode))
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(palette.text)
                                    Menu {
                                        Button("Edit") {
                                            openRecurringEditor(for: recurring)
                                        }
                                        Button(recurring.isActive ? "Pause" : "Resume") {
                                            Task {
                                                await viewModel.setRecurringActive(id: recurring.id, isActive: !recurring.isActive, weekStart: weekStart)
                                            }
                                        }
                                        Button("Delete", role: .destructive) {
                                            Task {
                                                await viewModel.deleteRecurring(id: recurring.id, weekStart: weekStart)
                                            }
                                        }
                                    } label: {
                                        OneAppIcon(
                                            key: .ui(.more),
                                            size: 18,
                                            tint: palette.subtext
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                OneSurfaceCard(palette: palette) {
                    Text("Recurring details will appear here once the latest overview loads.")
                        .font(OneType.secondary)
                        .foregroundStyle(palette.subtext)
                }
            }
        }
    }

    @ViewBuilder
    private func categoriesSection(snapshot: FinanceHomeSnapshot) -> some View {
        VStack(spacing: OneSpacing.md) {
            OneSurfaceCard(palette: palette) {
                HStack(alignment: .firstTextBaseline, spacing: OneSpacing.sm) {
                    OneSectionHeading(
                        palette: palette,
                        title: "Categories",
                        meta: activeCategories.isEmpty ? nil : "\(activeCategories.count)"
                    )
                    Spacer()
                    NavigationLink("Manage") {
                        FinanceCategoriesScreen(
                            viewModel: viewModel,
                            weekStart: weekStart,
                            onEdit: openCategoryEditor(for:)
                        ) {
                            sheetRoute = .category(
                                FinanceCategoryEditorContext(
                                    categoryID: nil,
                                    name: "",
                                    iconName: OneIconKey.financeCategory.rawValue
                                )
                            )
                        }
                    }
                    .font(OneType.label)
                    .foregroundStyle(palette.accent)
                }

                if activeCategories.isEmpty {
                    Text("Categories will appear here after finance data finishes loading.")
                        .font(OneType.secondary)
                        .foregroundStyle(palette.subtext)
                } else {
                    let previewCategories = Array(activeCategories.prefix(6))
                    ForEach(Array(previewCategories.enumerated()), id: \.element.id) { index, category in
                        Button {
                            openCategoryEditor(for: category)
                        } label: {
                            FinanceCategoryRow(palette: palette, category: category)
                        }
                        .buttonStyle(.plain)

                        if index < previewCategories.count - 1 {
                            Divider().overlay(palette.border)
                        }
                    }

                    if !viewModel.archivedCategories.isEmpty {
                        Text("\(viewModel.archivedCategories.count) archived categories stay in the full manage view.")
                            .font(OneType.caption)
                            .foregroundStyle(palette.subtext)
                    }
                }
            }

            FinanceCategoryPreviewCard(palette: palette, snapshot: snapshot)
        }
    }
}

private struct FinanceBalanceCard: View {
    let palette: OneTheme.Palette
    let snapshot: FinanceHomeSnapshot
    let needsSetup: Bool
    let onSetup: () -> Void

    var body: some View {
        OneGlassCard(palette: palette, padding: OneSpacing.lg) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Balance")
                        .font(OneType.label)
                        .foregroundStyle(palette.subtext)
                    Text(FinanceFormat.currency(snapshot.balanceState.totalBalance, code: snapshot.balanceState.defaultCurrencyCode))
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.text)
                    Text("Card \(FinanceFormat.currency(snapshot.balanceState.cardBalance, code: snapshot.balanceState.defaultCurrencyCode))  ·  Cash \(FinanceFormat.currency(snapshot.balanceState.cashBalance, code: snapshot.balanceState.defaultCurrencyCode))")
                        .font(OneType.secondary)
                        .foregroundStyle(palette.subtext)
                    Button(needsSetup ? "Set starting balances" : "Adjust balances") {
                        onSetup()
                    }
                    .font(OneType.label)
                    .foregroundStyle(palette.accent)
                }
                Spacer()
            }
            if !snapshot.balanceComparisons.isEmpty {
                HStack(spacing: 8) {
                    ForEach(snapshot.balanceComparisons) { comparison in
                        FinanceDeltaChip(
                            palette: palette,
                            label: comparison.label,
                            delta: comparison.delta,
                            currencyCode: snapshot.balanceState.defaultCurrencyCode
                        )
                    }
                }
            }
        }
    }
}

private struct FinanceStatusBadge: View {
    let palette: OneTheme.Palette
    let label: String
    let tone: FinanceHealthStatus

    private var tint: Color {
        switch tone {
        case .resilient:
            return palette.success
        case .steady:
            return palette.accent
        case .pressured:
            return palette.warning
        case .critical:
            return palette.danger
        }
    }

    var body: some View {
        Text(label.uppercased())
            .font(OneType.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: OneTheme.radiusSmall, style: .continuous)
                    .fill(tint.opacity(0.12))
            )
    }
}

private struct FinanceHomeSummaryCard: View {
    let palette: OneTheme.Palette
    let snapshot: FinanceHomeSnapshot
    let health: FinanceCashflowHealth?
    let needsSetup: Bool
    let onAdjustBalance: () -> Void
    let onOpenOverview: () -> Void

    private var currencyCode: String {
        snapshot.balanceState.defaultCurrencyCode
    }

    var body: some View {
        OneGlassCard(palette: palette, padding: 22) {
            Text("Home")
                .font(OneType.label)
                .foregroundStyle(palette.subtext)

            VStack(alignment: .leading, spacing: 8) {
                Text("Current balance")
                    .font(OneType.caption.weight(.semibold))
                    .foregroundStyle(palette.subtext)
                Text(FinanceFormat.currency(snapshot.balanceState.totalBalance, code: currencyCode))
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.text)
                    .minimumScaleFactor(0.82)
                Text("Card \(FinanceFormat.currency(snapshot.balanceState.cardBalance, code: currencyCode))  ·  Cash \(FinanceFormat.currency(snapshot.balanceState.cashBalance, code: currencyCode))")
                    .font(OneType.secondary)
                    .foregroundStyle(palette.subtext)
            }

            Divider()
                .overlay(palette.border)

            VStack(alignment: .leading, spacing: 8) {
                Text("Financial health")
                    .font(OneType.caption.weight(.semibold))
                    .foregroundStyle(palette.subtext)
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(health.map { "\($0.score)" } ?? "—")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.text)
                    if let health {
                        FinanceStatusBadge(palette: palette, label: health.status.title, tone: health.status)
                    }
                }
                Text(health?.headline ?? "Financial health score will appear after more finance activity is recorded.")
                    .font(OneType.secondary)
                    .foregroundStyle(palette.subtext)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Button(needsSetup ? "Set balance" : "Adjust balance") {
                    onAdjustBalance()
                }
                .font(OneType.label)
                .foregroundStyle(palette.accent)

                Spacer()

                Button("Open overview") {
                    onOpenOverview()
                }
                .font(OneType.label.weight(.semibold))
                .foregroundStyle(palette.text)
            }
        }
    }
}

private struct FinanceCashflowControlHeroCard: View {
    let palette: OneTheme.Palette
    let health: FinanceCashflowHealth
    let safeToSpend: FinanceSafeToSpendSummary?
    let currencyCode: String
    let onAdjustBalance: () -> Void
    let onOpenAnalysis: () -> Void

    var body: some View {
        OneGlassCard(palette: palette, padding: OneSpacing.lg) {
            HStack(alignment: .top, spacing: OneSpacing.md) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cashflow health")
                        .font(OneType.label)
                        .foregroundStyle(palette.subtext)
                    Text(health.headline)
                        .font(OneType.largeTitle)
                        .foregroundStyle(palette.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 10) {
                    FinanceStatusBadge(palette: palette, label: health.status.title, tone: health.status)
                    Text("\(health.score)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.text)
                    Text("score")
                        .font(OneType.caption)
                        .foregroundStyle(palette.subtext)
                }
            }

            Text(health.message)
                .font(OneType.secondary)
                .foregroundStyle(palette.subtext)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                FinanceMetricTile(
                    palette: palette,
                    title: "Free cash",
                    value: FinanceFormat.currency(health.freeCashflow, code: currencyCode)
                )
                FinanceMetricTile(
                    palette: palette,
                    title: "Projected",
                    value: FinanceFormat.currency(health.projectedBalance, code: currencyCode)
                )
                FinanceMetricTile(
                    palette: palette,
                    title: "Runway",
                    value: health.runwayDays >= 365 ? "Stable" : "\(health.runwayDays)d"
                )
            }

            FinanceEquationStrip(
                palette: palette,
                leading: "Control logic",
                equation: "Projected balance after current pace and scheduled charges",
                result: "Reserve \(FinanceFormat.currency(health.reserveFloor, code: currencyCode))"
            )

            if let safeToSpend {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Safe to spend now")
                            .font(OneType.caption.weight(.semibold))
                            .foregroundStyle(palette.subtext)
                        Text(FinanceFormat.currency(safeToSpend.amount, code: currencyCode))
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundStyle(palette.text)
                    }
                    Spacer()
                    Text("\(FinanceFormat.currency(safeToSpend.dailyAllowance, code: currencyCode)) / day")
                        .font(OneType.body.weight(.semibold))
                        .foregroundStyle(palette.text)
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

            HStack(spacing: 10) {
                OneActionButton(palette: palette, title: "Adjust balances", style: .secondary, action: onAdjustBalance)
                OneActionButton(palette: palette, title: "Open analysis", style: .primary, action: onOpenAnalysis)
            }
        }
    }
}

private struct FinanceAttentionSignalsCard: View {
    let palette: OneTheme.Palette
    let signals: [FinanceAttentionSignal]
    let currencyCode: String

    private func tint(for severity: FinanceAttentionSeverity) -> Color {
        switch severity {
        case .stable:
            return palette.accent
        case .watch:
            return palette.highlight
        case .warning:
            return palette.warning
        case .critical:
            return palette.danger
        }
    }

    var body: some View {
        OneSurfaceCard(palette: palette) {
            OneSectionHeading(palette: palette, title: "Attention stack", meta: "Ranked")
            ForEach(signals) { signal in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(signal.title)
                            .font(OneType.body.weight(.semibold))
                            .foregroundStyle(palette.text)
                        Spacer()
                        if let metricLabel = signal.metricLabel, let metricValue = signal.metricValue {
                            Text("\(metricLabel) · \(FinanceFormat.currency(metricValue, code: currencyCode))")
                                .font(OneType.caption.weight(.semibold))
                                .foregroundStyle(tint(for: signal.severity))
                        }
                    }
                    Text(signal.message)
                        .font(OneType.secondary)
                        .foregroundStyle(palette.subtext)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: OneTheme.radiusMedium, style: .continuous)
                        .fill(palette.surfaceMuted)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: OneTheme.radiusMedium, style: .continuous)
                        .stroke(tint(for: signal.severity).opacity(0.28), lineWidth: 1)
                )
            }
        }
    }
}

private struct FinanceSafeToSpendCard: View {
    let palette: OneTheme.Palette
    let summary: FinanceSafeToSpendSummary
    let currencyCode: String
    var actionTitle: String? = "Open safety"
    var action: (() -> Void)? = nil

    var body: some View {
        OneSurfaceCard(palette: palette) {
            HStack(alignment: .firstTextBaseline, spacing: OneSpacing.sm) {
                OneSectionHeading(palette: palette, title: "Safe to spend", meta: "\(summary.daysRemaining)d left")
                Spacer()
                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .font(OneType.label)
                        .foregroundStyle(palette.accent)
                }
            }

            HStack(spacing: 10) {
                FinanceMetricTile(
                    palette: palette,
                    title: "Available",
                    value: FinanceFormat.currency(summary.amount, code: currencyCode)
                )
                FinanceMetricTile(
                    palette: palette,
                    title: "Daily guide",
                    value: FinanceFormat.currency(summary.dailyAllowance, code: currencyCode)
                )
            }

            FinanceStatusBadge(palette: palette, label: summary.status.title, tone: summary.status)
            Text(summary.headline)
                .font(OneType.sectionTitle)
                .foregroundStyle(palette.text)
            Text(summary.message)
                .font(OneType.secondary)
                .foregroundStyle(palette.subtext)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct FinanceRecurringPressureCard: View {
    let palette: OneTheme.Palette
    let summary: FinanceRecurringPressureSummary
    let overview: FinanceRecurringOverview?
    let currencyCode: String
    var actionTitle: String? = "Open recurring"
    let action: () -> Void

    var body: some View {
        OneSurfaceCard(palette: palette) {
            HStack(alignment: .firstTextBaseline, spacing: OneSpacing.sm) {
                OneSectionHeading(palette: palette, title: "Recurring pressure", meta: "\(summary.activeCount) active")
                Spacer()
                if let actionTitle {
                    Button(actionTitle, action: action)
                        .font(OneType.label)
                        .foregroundStyle(palette.accent)
                }
            }

            Text(summary.headline)
                .font(OneType.sectionTitle)
                .foregroundStyle(palette.text)
            Text(summary.message)
                .font(OneType.secondary)
                .foregroundStyle(palette.subtext)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                FinanceMetricTile(
                    palette: palette,
                    title: "Monthly",
                    value: FinanceFormat.currency(summary.monthlyCommitment, code: currencyCode)
                )
                FinanceMetricTile(
                    palette: palette,
                    title: "Share of inflow",
                    value: "\(OneLayoutMath.percent(summary.shareOfIncome))%"
                )
                FinanceMetricTile(
                    palette: palette,
                    title: "Still due",
                    value: FinanceFormat.currency(summary.upcomingChargesTotal, code: currencyCode)
                )
            }

            if let overview, !overview.upcomingCharges.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Next charges")
                        .font(OneType.caption.weight(.semibold))
                        .foregroundStyle(palette.subtext)
                    ForEach(overview.upcomingCharges.prefix(3)) { charge in
                        HStack {
                            Text(charge.title)
                                .font(OneType.body.weight(.semibold))
                                .foregroundStyle(palette.text)
                            Spacer()
                            Text(FinanceFormat.currency(charge.amount, code: currencyCode))
                                .font(OneType.secondary.weight(.semibold))
                                .foregroundStyle(palette.text)
                        }
                    }
                }
            }
        }
    }
}

private struct FinanceCategoryPressureCard: View {
    let palette: OneTheme.Palette
    let categories: [FinanceCategoryDrift]
    let currencyCode: String
    let onOpenAnalysis: () -> Void

    var body: some View {
        OneSurfaceCard(palette: palette) {
            HStack(alignment: .firstTextBaseline, spacing: OneSpacing.sm) {
                OneSectionHeading(palette: palette, title: "Category pressure", meta: "Ranked")
                Spacer()
                Button("Open analysis", action: onOpenAnalysis)
                    .font(OneType.label)
                    .foregroundStyle(palette.accent)
            }

            ForEach(categories.prefix(3)) { category in
                FinanceCategoryDriftRow(
                    palette: palette,
                    drift: category,
                    currencyCode: currencyCode,
                    isExpanded: true
                )
            }
        }
    }
}

private struct FinanceAnalyticsHeroCard: View {
    let palette: OneTheme.Palette
    let snapshot: FinanceAnalyticsSnapshot
    let currencyCode: String

    var body: some View {
        OneGlassCard(palette: palette, padding: OneSpacing.lg) {
            HStack(alignment: .top, spacing: OneSpacing.md) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(snapshot.period.title) analysis")
                        .font(OneType.label)
                        .foregroundStyle(palette.subtext)
                    Text(snapshot.cashflowHealth?.headline ?? snapshot.insightMessage)
                        .font(OneType.title)
                        .foregroundStyle(palette.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if let health = snapshot.cashflowHealth {
                    FinanceStatusBadge(palette: palette, label: health.status.title, tone: health.status)
                }
            }

            HStack(spacing: 10) {
                FinanceMetricTile(
                    palette: palette,
                    title: "Spent",
                    value: FinanceFormat.currency(snapshot.totalSpent, code: currencyCode)
                )
                FinanceMetricTile(
                    palette: palette,
                    title: "Income",
                    value: FinanceFormat.currency(snapshot.totalIncome, code: currencyCode)
                )
                FinanceMetricTile(
                    palette: palette,
                    title: "Net",
                    value: FinanceFormat.currency(snapshot.netMovement, code: currencyCode)
                )
            }

            if let health = snapshot.cashflowHealth {
                FinanceEquationStrip(
                    palette: palette,
                    leading: "Operational truth",
                    equation: health.message,
                    result: "Projected \(FinanceFormat.currency(health.projectedBalance, code: currencyCode))"
                )
            }
        }
    }
}

private struct FinanceCategoryDriftRow: View {
    let palette: OneTheme.Palette
    let drift: FinanceCategoryDrift
    let currencyCode: String
    let isExpanded: Bool

    private var deltaColor: Color {
        if drift.deltaAmount > 0.009 {
            return palette.warning
        }
        if drift.deltaAmount < -0.009 {
            return palette.success
        }
        return palette.subtext
    }

    private var deltaLabel: String {
        let shareText = "\(OneLayoutMath.percent(drift.shareOfSpend))%"
        if let changeRatio = drift.changeRatio, drift.previousAmount > 0.009 {
            let deltaPercent = Int(((changeRatio - 1) * 100).rounded())
            let prefix = deltaPercent > 0 ? "+" : ""
            return "\(prefix)\(deltaPercent)% · \(shareText) share"
        }
        return "New pressure · \(shareText) share"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: OneSpacing.sm) {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(palette.surfaceStrong)
                        .frame(width: 34, height: 34)
                        .overlay(
                            OneIcon(
                                key: drift.oneIconKey,
                                palette: palette,
                                size: 16,
                                tint: palette.symbol
                            )
                        )
                    Text(drift.categoryName)
                        .font(OneType.body.weight(.semibold))
                        .foregroundStyle(palette.text)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(FinanceFormat.currency(drift.currentAmount, code: currencyCode))
                        .font(OneType.body.weight(.semibold))
                        .foregroundStyle(palette.text)
                    Text(deltaLabel)
                        .font(OneType.caption.weight(.semibold))
                        .foregroundStyle(deltaColor)
                }
            }

            GeometryReader { proxy in
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(palette.surfaceStrong)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(deltaColor.opacity(0.78))
                            .frame(
                                width: OneLayoutMath.filledWidth(
                                    containerWidth: proxy.size.width,
                                    fraction: drift.shareOfSpend,
                                    minimumWhenVisible: 14
                                )
                            )
                    }
            }
            .frame(height: 8)

            if isExpanded {
                Text(drift.message)
                    .font(OneType.secondary)
                    .foregroundStyle(palette.subtext)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct FinanceWeeklyPaceCard: View {
    let palette: OneTheme.Palette
    let snapshot: FinanceHomeSnapshot

    private var insight: String {
        let pace = snapshot.insightSummary.weeklyPaceVsBaseline
        if pace >= 1.15 {
            return "This week is moving faster than your recent pace."
        }
        if pace > 0, pace <= 0.85 {
            return "This week is landing below your recent pace."
        }
        return "This week is tracking close to your recent pace."
    }

    var body: some View {
        OneSurfaceCard(palette: palette) {
            OneSectionHeading(palette: palette, title: "This week", meta: "Pace")
            HStack(spacing: 10) {
                FinanceMetricTile(
                    palette: palette,
                    title: "Spent",
                    value: FinanceFormat.currency(snapshot.insightSummary.weekSpent, code: snapshot.balanceState.defaultCurrencyCode)
                )
                FinanceMetricTile(
                    palette: palette,
                    title: "Net",
                    value: FinanceFormat.currency(snapshot.insightSummary.weekNet, code: snapshot.balanceState.defaultCurrencyCode)
                )
                FinanceMetricTile(
                    palette: palette,
                    title: "Projected",
                    value: FinanceFormat.currency(snapshot.insightSummary.projectedMonthSpend, code: snapshot.balanceState.defaultCurrencyCode)
                )
            }
            Text(insight)
                .font(OneType.secondary)
                .foregroundStyle(palette.subtext)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct FinanceTodayPreviewCard: View {
    let palette: OneTheme.Palette
    let snapshot: FinanceHomeSnapshot
    let categories: [FinanceCategory]
    let onQuickAdd: () -> Void

    var body: some View {
        OneSurfaceCard(palette: palette) {
            HStack {
                OneSectionHeading(palette: palette, title: "Today", meta: "\(snapshot.todayTransactions.count)")
                Spacer()
                Button("Quick add") {
                    onQuickAdd()
                }
                .font(OneType.label)
                .foregroundStyle(palette.accent)
            }
            if snapshot.todayTransactions.isEmpty {
                Text("No transactions recorded today. Log the next expense or income when it happens.")
                    .font(OneType.secondary)
                    .foregroundStyle(palette.subtext)
            } else {
                ForEach(snapshot.todayTransactions.prefix(4)) { transaction in
                    FinanceCompactTransactionRow(
                        palette: palette,
                        transaction: transaction,
                        categories: categories,
                        currencyCode: snapshot.balanceState.defaultCurrencyCode
                    )
                    if transaction.id != snapshot.todayTransactions.prefix(4).last?.id {
                        Divider().overlay(palette.border)
                    }
                }
            }
        }
    }
}

private struct FinanceCategoryPreviewCard: View {
    let palette: OneTheme.Palette
    let snapshot: FinanceHomeSnapshot

    var body: some View {
        OneSurfaceCard(palette: palette) {
            OneSectionHeading(palette: palette, title: "Top categories", meta: nil)
            if snapshot.categoryBreakdown.isEmpty {
                Text("Your most active categories will appear here after a few expenses.")
                    .font(OneType.secondary)
                    .foregroundStyle(palette.subtext)
            } else {
                let maxAmount = snapshot.categoryBreakdown.map(\.amount).max() ?? 1
                ForEach(snapshot.categoryBreakdown) { category in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            HStack(spacing: 8) {
                                OneIcon(
                                    key: category.oneIconKey,
                                    palette: palette,
                                    size: 16,
                                    tint: palette.symbol
                                )
                                Text(category.categoryName)
                            }
                            .font(OneType.body.weight(.semibold))
                            .foregroundStyle(palette.text)
                            Spacer()
                            Text(FinanceFormat.currency(category.amount, code: snapshot.balanceState.defaultCurrencyCode))
                                .font(OneType.secondary.weight(.semibold))
                                .foregroundStyle(palette.subtext)
                        }
                        ProgressView(value: category.amount, total: maxAmount)
                            .tint(palette.accent)
                    }
                }
            }
        }
    }
}

private struct FinanceWarningCard: View {
    let palette: OneTheme.Palette
    let warning: FinanceWarning

    private var tint: Color {
        switch warning.kind {
        case .lowBalance:
            return palette.warning
        case .weeklyPace:
            return palette.highlight
        case .unusualSpending:
            return palette.danger
        }
    }

    var body: some View {
        OneSurfaceCard(palette: palette) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(tint.opacity(0.16))
                    .frame(width: 36, height: 36)
                    .overlay(
                        OneIcon(key: .warning, palette: palette, size: 16, tint: tint)
                    )
                VStack(alignment: .leading, spacing: 4) {
                    Text(warning.title)
                        .font(OneType.sectionTitle)
                        .foregroundStyle(palette.text)
                    Text(warning.message)
                        .font(OneType.secondary)
                        .foregroundStyle(palette.subtext)
                }
                Spacer()
            }
        }
    }
}

private struct FinanceCompactTransactionRow: View {
    let palette: OneTheme.Palette
    let transaction: FinanceTransaction
    let categories: [FinanceCategory]
    let currencyCode: String

    private var resolvedCategory: FinanceResolvedCategory {
        FinanceFormat.resolvedCategory(for: transaction, categories: categories)
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(palette.surfaceStrong)
                .frame(width: 38, height: 38)
                .overlay(
                    OneIcon(
                        key: resolvedCategory.iconKey,
                        palette: palette,
                        size: 18,
                        tint: palette.symbol
                    )
                )
            VStack(alignment: .leading, spacing: 3) {
                Text(resolvedCategory.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.text)
                Text(FinanceFormat.secondaryLine(for: transaction))
                    .font(OneType.secondary)
                    .foregroundStyle(palette.subtext)
            }
            Spacer()
            Text(FinanceFormat.signedCurrency(transaction, code: currencyCode))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(FinanceFormat.amountColor(for: transaction, palette: palette))
        }
    }
}

private struct FinanceTransactionsScreen: View {
    @ObservedObject var viewModel: FinanceViewModel
    let weekStart: Int
    let onEdit: (FinanceTransaction) -> Void
    let onDuplicate: (String) -> Void
    let onDelete: (String) -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var palette: OneTheme.Palette {
        OneTheme.palette(for: colorScheme)
    }

    private var currencyCode: String {
        viewModel.homeSnapshot?.balanceState.defaultCurrencyCode ?? "USD"
    }

    var body: some View {
        List {
            ForEach(viewModel.transactionSections) { section in
                Section {
                    ForEach(section.transactions) { transaction in
                        Button {
                            onEdit(transaction)
                        } label: {
                            FinanceHistoryRow(
                                palette: palette,
                                transaction: transaction,
                                categories: viewModel.categories,
                                currencyCode: currencyCode
                            )
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                onDuplicate(transaction.id)
                            } label: {
                                Label {
                                    Text("Duplicate")
                                } icon: {
                                    OneAppIcon(key: .ui(.duplicate), size: 14)
                                }
                            }
                            .tint(palette.accent)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                onDelete(transaction.id)
                            } label: {
                                Label {
                                    Text("Delete")
                                } icon: {
                                    OneAppIcon(key: .ui(.delete), size: 14)
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text(FinanceFormat.longDate(section.dateLocal))
                        Spacer()
                        Text(FinanceFormat.currency(section.total, code: currencyCode))
                    }
                    .font(OneType.label)
                    .foregroundStyle(palette.subtext)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(OneScreenBackground(palette: palette))
        .navigationTitle("Transactions")
        .oneNavigationBarDisplayMode(.inline)
        .task {
            if viewModel.transactionSections.isEmpty {
                await viewModel.refreshAll(weekStart: weekStart)
            }
        }
    }
}

private struct FinanceHistoryRow: View {
    let palette: OneTheme.Palette
    let transaction: FinanceTransaction
    let categories: [FinanceCategory]
    let currencyCode: String

    private var resolvedCategory: FinanceResolvedCategory {
        FinanceFormat.resolvedCategory(for: transaction, categories: categories)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(palette.surfaceStrong)
                .frame(width: 40, height: 40)
                .overlay(
                    OneIcon(
                        key: resolvedCategory.iconKey,
                        palette: palette,
                        size: 18,
                        tint: palette.symbol
                    )
                )
            VStack(alignment: .leading, spacing: 4) {
                Text(resolvedCategory.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.text)
                if let note = transaction.note, !note.isEmpty {
                    Text(note)
                        .font(OneType.secondary)
                        .foregroundStyle(palette.subtext)
                        .lineLimit(1)
                }
                Text(FinanceFormat.metaLine(for: transaction))
                    .font(OneType.caption)
                    .foregroundStyle(palette.subtext)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(FinanceFormat.signedCurrency(transaction, code: currencyCode))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(FinanceFormat.amountColor(for: transaction, palette: palette))
                Text(FinanceFormat.time(transaction.occurredAt))
                    .font(OneType.caption)
                    .foregroundStyle(palette.subtext)
            }
        }
        .padding(.vertical, 6)
    }
}

private enum FinanceAnalyticsFocus: String, CaseIterable, Hashable {
    case cashflow
    case categories
    case commitments
    case safety

    var title: String {
        switch self {
        case .cashflow:
            return "Cashflow"
        case .categories:
            return "Categories"
        case .commitments:
            return "Commitments"
        case .safety:
            return "Safety"
        }
    }
}

private struct FinanceAnalyticsWorkspace: View {
    @ObservedObject var viewModel: FinanceViewModel
    let weekStart: Int

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var focus: FinanceAnalyticsFocus = .cashflow
    @State private var selectedCategoryID: String?

    private var palette: OneTheme.Palette {
        OneTheme.palette(for: colorScheme)
    }

    private var currencyCode: String {
        viewModel.homeSnapshot?.balanceState.defaultCurrencyCode ?? "USD"
    }

    private var displayedPeriod: FinanceAnalyticsPeriod {
        viewModel.pendingAnalyticsPeriod ?? viewModel.selectedAnalyticsPeriod
    }

    var body: some View {
        VStack(spacing: OneSpacing.md) {
            OneSurfaceCard(palette: palette) {
                OneSectionHeading(palette: palette, title: "Analysis", meta: displayedPeriod.title)
                OneSegmentedControl(
                    palette: palette,
                    options: FinanceAnalyticsPeriod.allCases,
                    selection: displayedPeriod,
                    title: { $0.title }
                ) { selection in
                    Task {
                        await viewModel.selectAnalyticsPeriod(selection, weekStart: weekStart)
                    }
                }
                OneSegmentedControl(
                    palette: palette,
                    options: FinanceAnalyticsFocus.allCases,
                    selection: focus,
                    title: { $0.title }
                ) { selection in
                    withAnimation(OneMotion.animation(.stateChange, reduceMotion: reduceMotion)) {
                        focus = selection
                    }
                }
                if viewModel.isSwitchingAnalyticsPeriod {
                    HStack(spacing: OneSpacing.sm) {
                        ProgressView()
                            .tint(palette.accent)
                        Text("Refreshing \(displayedPeriod.title.lowercased()) analysis")
                            .font(OneType.secondary)
                            .foregroundStyle(palette.subtext)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if let snapshot = viewModel.analyticsSnapshot {
                FinanceAnalyticsHeroCard(
                    palette: palette,
                    snapshot: snapshot,
                    currencyCode: currencyCode
                )

                if !snapshot.attentionSignals.isEmpty {
                    FinanceAttentionSignalsCard(
                        palette: palette,
                        signals: snapshot.attentionSignals,
                        currencyCode: currencyCode
                    )
                }

                Group {
                    switch focus {
                    case .cashflow:
                        cashflowSection(snapshot: snapshot)
                    case .categories:
                        categoriesSection(snapshot: snapshot)
                    case .commitments:
                        commitmentsSection(snapshot: snapshot)
                    case .safety:
                        safetySection(snapshot: snapshot)
                    }
                }
                .transition(.opacity)
            } else {
                OneSurfaceCard(palette: palette) {
                    Text("Finance analysis will appear after the latest snapshot finishes loading.")
                        .font(OneType.secondary)
                        .foregroundStyle(palette.subtext)
                }
            }
        }
    }

    @ViewBuilder
    private func cashflowSection(snapshot: FinanceAnalyticsSnapshot) -> some View {
        OneSurfaceCard(palette: palette) {
            OneSectionHeading(palette: palette, title: "Cashflow Rhythm", meta: snapshot.period.title)
            if snapshot.chartPoints.isEmpty {
                Text("Cash movement appears here once this range has income or spending.")
                    .font(OneType.secondary)
                    .foregroundStyle(palette.subtext)
            } else {
                FinanceCashflowTrendChart(
                    palette: palette,
                    points: snapshot.chartPoints,
                    currencyCode: currencyCode
                )
                Text("Spent, inflow, and net movement stay separated so pressure is visible at a glance.")
                    .font(OneType.secondary)
                    .foregroundStyle(palette.subtext)
            }
        }

        OneSurfaceCard(palette: palette) {
            OneSectionHeading(palette: palette, title: "Reference Stack", meta: "Current versus prior")
            if snapshot.comparisonPoints.isEmpty {
                Text("Reference rows appear after more history builds up.")
                    .font(OneType.secondary)
                    .foregroundStyle(palette.subtext)
            } else {
                FinanceTableHeader(
                    palette: palette,
                    columns: ["Period", "Spent", "Income", "Net"]
                )
                ForEach(Array(snapshot.comparisonPoints.enumerated()), id: \.element.id) { index, point in
                    FinanceComparisonRow(
                        palette: palette,
                        point: point,
                        previousPoint: index > 0 ? snapshot.comparisonPoints[index - 1] : nil,
                        currencyCode: currencyCode
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func categoriesSection(snapshot: FinanceAnalyticsSnapshot) -> some View {
        if snapshot.categoryDrift.isEmpty {
            OneSurfaceCard(palette: palette) {
                Text("Category drift becomes available once there is enough spending history to compare.")
                    .font(OneType.secondary)
                    .foregroundStyle(palette.subtext)
            }
        } else {
            OneSurfaceCard(palette: palette) {
                OneSectionHeading(palette: palette, title: "Category Drift", meta: "Tap to isolate")
                ForEach(snapshot.categoryDrift.prefix(6)) { category in
                    Button {
                        withAnimation(OneMotion.animation(.stateChange, reduceMotion: reduceMotion)) {
                            selectedCategoryID = selectedCategoryID == category.id ? nil : category.id
                        }
                    } label: {
                        FinanceCategoryDriftRow(
                            palette: palette,
                            drift: category,
                            currencyCode: currencyCode,
                            isExpanded: selectedCategoryID == category.id
                        )
                    }
                    .buttonStyle(.plain)

                    if category.id != snapshot.categoryDrift.prefix(6).last?.id {
                        Divider().overlay(palette.border)
                    }
                }
            }
        }

        OneSurfaceCard(palette: palette) {
            OneSectionHeading(palette: palette, title: "Category Share", meta: nil)
            if snapshot.topCategories.isEmpty {
                Text("Category share appears after the first tracked expenses.")
                    .font(OneType.secondary)
                    .foregroundStyle(palette.subtext)
            } else {
                FinanceTableHeader(
                    palette: palette,
                    columns: ["Category", "Amount", "Share"]
                )
                ForEach(snapshot.topCategories) { category in
                    FinanceCategoryShareRow(
                        palette: palette,
                        category: category,
                        currencyCode: currencyCode,
                        share: snapshot.totalSpent == 0 ? 0 : category.amount / snapshot.totalSpent
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func commitmentsSection(snapshot: FinanceAnalyticsSnapshot) -> some View {
        if let recurringPressure = snapshot.recurringPressure {
            FinanceRecurringPressureCard(
                palette: palette,
                summary: recurringPressure,
                overview: viewModel.recurringOverview,
                currencyCode: currencyCode,
                actionTitle: "Open recurring"
            ) {
            }
        }

        OneSurfaceCard(palette: palette) {
            OneSectionHeading(palette: palette, title: "Commitment Math", meta: snapshot.period == .year ? "Annual view" : "Current monthly load")
            FinanceEquationStrip(
                palette: palette,
                leading: "Recurring Burden",
                equation: snapshot.period == .year ? "Annualized fixed items" : "Normalized fixed commitments",
                result: FinanceFormat.currency(snapshot.recurringBurden, code: currencyCode)
            )
            if let overview = viewModel.recurringOverview, !overview.upcomingCharges.isEmpty {
                Divider().overlay(palette.border)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Upcoming charges")
                        .font(OneType.label)
                        .foregroundStyle(palette.subtext)
                    ForEach(overview.upcomingCharges.prefix(4)) { charge in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(charge.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(palette.text)
                                Text("Due \(FinanceFormat.longDate(charge.dueDate))")
                                    .font(OneType.secondary)
                                    .foregroundStyle(palette.subtext)
                            }
                            Spacer()
                            Text(FinanceFormat.currency(charge.amount, code: currencyCode))
                                .font(OneType.secondary.weight(.semibold))
                                .foregroundStyle(palette.text)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func safetySection(snapshot: FinanceAnalyticsSnapshot) -> some View {
        if let safeToSpend = snapshot.safeToSpend {
            FinanceSafeToSpendCard(
                palette: palette,
                summary: safeToSpend,
                currencyCode: currencyCode,
                actionTitle: nil,
                action: nil
            )
        }

        if let pattern = snapshot.spendingPattern {
            OneSurfaceCard(palette: palette) {
                OneSectionHeading(palette: palette, title: "Pattern Shift", meta: pattern.acceleratedAfterMidpoint ? "Accelerated" : "Stable")
                HStack(spacing: 10) {
                    FinanceMetricTile(
                        palette: palette,
                        title: "Recent / day",
                        value: FinanceFormat.currency(pattern.recentDailyAverage, code: currencyCode)
                    )
                    FinanceMetricTile(
                        palette: palette,
                        title: "Baseline / day",
                        value: FinanceFormat.currency(pattern.baselineDailyAverage, code: currencyCode)
                    )
                    FinanceMetricTile(
                        palette: palette,
                        title: "Current",
                        value: FinanceFormat.currency(pattern.currentPeriodSpend, code: currencyCode)
                    )
                }
                Text(pattern.message)
                    .font(OneType.secondary)
                    .foregroundStyle(palette.subtext)
                    .fixedSize(horizontal: false, vertical: true)
                if let health = snapshot.cashflowHealth {
                    FinanceEquationStrip(
                        palette: palette,
                        leading: "Balance resilience",
                        equation: "Projected balance versus reserve floor",
                        result: "\(FinanceFormat.currency(health.projectedBalance, code: currencyCode))  ·  Reserve \(FinanceFormat.currency(health.reserveFloor, code: currencyCode))"
                    )
                }
            }
        }
    }
}

private struct FinanceAnalyticsScreen: View {
    @ObservedObject var viewModel: FinanceViewModel
    let weekStart: Int
    @Environment(\.colorScheme) private var colorScheme

    private var palette: OneTheme.Palette {
        OneTheme.palette(for: colorScheme)
    }

    var body: some View {
        OneScrollScreen(palette: palette, bottomPadding: 36) {
            FinanceAnalyticsWorkspace(viewModel: viewModel, weekStart: weekStart)

            if let message = viewModel.errorMessage {
                FinanceInlineStatusCard(message: message, kind: .danger, palette: palette)
            }
        }
        .navigationTitle("Analysis")
        .oneNavigationBarDisplayMode(.inline)
    }
}

private struct FinanceCashflowTrendChart: View {
    let palette: OneTheme.Palette
    let points: [FinanceAmountChartPoint]
    let currencyCode: String

    var body: some View {
        #if canImport(Charts)
        Chart {
            RuleMark(y: .value("Break Even", 0))
                .foregroundStyle(palette.border)

            ForEach(points) { point in
                BarMark(
                    x: .value("Bucket", point.label),
                    y: .value("Spent", point.spent)
                )
                .position(by: .value("Series", "Spent"))
                .foregroundStyle(palette.danger)

                BarMark(
                    x: .value("Bucket", point.label),
                    y: .value("Income", point.income)
                )
                .position(by: .value("Series", "Income"))
                .foregroundStyle(palette.success)

                LineMark(
                    x: .value("Bucket", point.label),
                    y: .value("Net", point.net)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(palette.accent)

                PointMark(
                    x: .value("Bucket", point.label),
                    y: .value("Net", point.net)
                )
                .foregroundStyle(palette.accent)
            }
        }
        .chartLegend(position: .top, alignment: .leading)
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .frame(height: 220)
        #else
        OneActivityLane(
            palette: palette,
            values: points.map { max($0.spent, $0.income, 0) },
            labels: points.map(\.label),
            highlightIndex: points.indices.last
        )
        #endif
    }
}

private struct FinanceTableHeader: View {
    let palette: OneTheme.Palette
    let columns: [String]

    var body: some View {
        HStack {
            ForEach(columns, id: \.self) { column in
                Text(column)
                    .font(OneType.caption.weight(.semibold))
                    .foregroundStyle(palette.subtext)
                    .frame(maxWidth: .infinity, alignment: column == columns.first ? .leading : .trailing)
            }
        }
        .padding(.bottom, 4)
    }
}

private struct FinanceCategoryShareRow: View {
    let palette: OneTheme.Palette
    let category: FinanceCategoryTotal
    let currencyCode: String
    let share: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: OneSpacing.sm) {
                HStack(spacing: 8) {
                    OneIcon(
                        key: category.oneIconKey,
                        palette: palette,
                        size: 16,
                        tint: palette.symbol
                    )
                    Text(category.categoryName)
                }
                .font(OneType.body.weight(.semibold))
                .foregroundStyle(palette.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(FinanceFormat.currency(category.amount, code: currencyCode))
                    .font(OneType.secondary.weight(.semibold))
                    .foregroundStyle(palette.text)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Text("\(OneLayoutMath.percent(share))%")
                    .font(OneType.secondary.weight(.semibold))
                    .foregroundStyle(palette.subtext)
                    .frame(width: 44, alignment: .trailing)
            }

            GeometryReader { proxy in
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(palette.surfaceStrong)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(palette.accent)
                            .frame(
                                width: OneLayoutMath.filledWidth(
                                    containerWidth: proxy.size.width,
                                    fraction: share,
                                    minimumWhenVisible: 10
                                )
                            )
                    }
            }
            .frame(height: 8)
        }
        .padding(.vertical, 4)
    }
}

private struct FinanceComparisonRow: View {
    let palette: OneTheme.Palette
    let point: FinanceComparisonPoint
    let previousPoint: FinanceComparisonPoint?
    let currencyCode: String

    private var deltaText: String {
        guard let previousPoint else {
            return "Baseline"
        }
        let delta = point.net - previousPoint.net
        let prefix = delta >= 0 ? "+" : ""
        return "Delta \(prefix)\(FinanceFormat.currency(delta, code: currencyCode))"
    }

    private var deltaColor: Color {
        guard let previousPoint else {
            return palette.subtext
        }
        let delta = point.net - previousPoint.net
        if delta > 0 {
            return palette.success
        }
        if delta < 0 {
            return palette.danger
        }
        return palette.subtext
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: OneSpacing.sm) {
                Text(point.label)
                    .font(OneType.body.weight(.semibold))
                    .foregroundStyle(palette.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(FinanceFormat.currency(point.spent, code: currencyCode))
                    .font(OneType.secondary)
                    .foregroundStyle(palette.text)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Text(FinanceFormat.currency(point.income, code: currencyCode))
                    .font(OneType.secondary)
                    .foregroundStyle(palette.text)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Text(FinanceFormat.currency(point.net, code: currencyCode))
                    .font(OneType.secondary.weight(.semibold))
                    .foregroundStyle(point.net >= 0 ? palette.success : palette.danger)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            Text(deltaText)
                .font(OneType.caption)
                .foregroundStyle(deltaColor)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }
}

private struct FinanceRecurringScreen: View {
    @ObservedObject var viewModel: FinanceViewModel
    let weekStart: Int
    let onEdit: (RecurringFinanceTransaction) -> Void
    let onAdd: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var palette: OneTheme.Palette {
        OneTheme.palette(for: colorScheme)
    }

    private var currencyCode: String {
        viewModel.homeSnapshot?.balanceState.defaultCurrencyCode ?? "USD"
    }

    var body: some View {
        OneScrollScreen(palette: palette, bottomPadding: 36) {
            if let overview = viewModel.recurringOverview {
                if let recurringPressure = viewModel.homeSnapshot?.recurringPressure {
                    FinanceRecurringPressureCard(
                        palette: palette,
                        summary: recurringPressure,
                        overview: overview,
                        currencyCode: currencyCode,
                        actionTitle: nil
                    ) {
                    }
                }

                OneGlassCard(palette: palette) {
                    Text("Recurring")
                        .font(OneType.label)
                        .foregroundStyle(palette.subtext)
                    HStack(spacing: 10) {
                        FinanceMetricTile(
                            palette: palette,
                            title: "Monthly",
                            value: FinanceFormat.currency(overview.monthlyTotal, code: currencyCode)
                        )
                        FinanceMetricTile(
                            palette: palette,
                            title: "Yearly",
                            value: FinanceFormat.currency(overview.yearlyTotal, code: currencyCode)
                        )
                    }
                    OneActionButton(palette: palette, title: "Add recurring", style: .primary, action: onAdd)
                }

                if !overview.upcomingCharges.isEmpty {
                    OneSurfaceCard(palette: palette) {
                        OneSectionHeading(palette: palette, title: "Upcoming", meta: nil)
                        ForEach(overview.upcomingCharges) { charge in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(charge.title)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(palette.text)
                                    Text("Due \(FinanceFormat.longDate(charge.dueDate))")
                                        .font(OneType.secondary)
                                        .foregroundStyle(palette.subtext)
                                }
                                Spacer()
                                Text(FinanceFormat.currency(charge.amount, code: currencyCode))
                                    .font(OneType.secondary.weight(.semibold))
                                    .foregroundStyle(palette.text)
                            }
                        }
                    }
                }

                ForEach(overview.activeItems) { recurring in
                    OneSurfaceCard(palette: palette) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(recurring.title)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(palette.text)
                                Text("\(recurring.cadenceType.title) · \(recurring.paymentMethod.title)")
                                    .font(OneType.secondary)
                                    .foregroundStyle(palette.subtext)
                                Text("Next charge \(FinanceFormat.longDate(recurring.nextDueDate))")
                                    .font(OneType.caption)
                                    .foregroundStyle(palette.subtext)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 8) {
                                Text(FinanceFormat.currency(recurring.amount, code: currencyCode))
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(palette.text)
                                Menu {
                                    Button("Edit") {
                                        onEdit(recurring)
                                    }
                                    Button(recurring.isActive ? "Pause" : "Resume") {
                                        Task {
                                            await viewModel.setRecurringActive(id: recurring.id, isActive: !recurring.isActive, weekStart: weekStart)
                                        }
                                    }
                                    Button("Delete", role: .destructive) {
                                        Task {
                                            await viewModel.deleteRecurring(id: recurring.id, weekStart: weekStart)
                                        }
                                    }
                                } label: {
                                    OneAppIcon(
                                        key: .ui(.more),
                                        size: 18,
                                        tint: palette.subtext
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Recurring")
        .oneNavigationBarDisplayMode(.inline)
    }
}

private struct FinanceCategoriesScreen: View {
    @ObservedObject var viewModel: FinanceViewModel
    let weekStart: Int
    let onEdit: (FinanceCategory) -> Void
    let onAdd: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var palette: OneTheme.Palette {
        OneTheme.palette(for: colorScheme)
    }

    var body: some View {
        List {
            Section {
                Button("Add custom category") {
                    onAdd()
                }
            }
            Section("Active") {
                ForEach(viewModel.activeCategories.sorted { $0.sortOrder < $1.sortOrder }) { category in
                    FinanceCategoryRow(palette: palette, category: category)
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button("Edit") {
                                onEdit(category)
                            }
                            .tint(palette.accent)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task {
                                    await viewModel.setCategoryArchived(id: category.id, isArchived: !category.isArchived, weekStart: weekStart)
                                }
                            } label: {
                                Text(category.isArchived ? "Unarchive" : "Archive")
                            }
                        }
                }
            }
            if !viewModel.archivedCategories.isEmpty {
                Section("Archived") {
                    ForEach(viewModel.archivedCategories.sorted { $0.name < $1.name }) { category in
                        FinanceCategoryRow(palette: palette, category: category)
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button("Edit") {
                                    onEdit(category)
                                }
                                .tint(palette.accent)
                            }
                            .swipeActions(edge: .trailing) {
                                Button("Restore") {
                                    Task {
                                        await viewModel.setCategoryArchived(id: category.id, isArchived: false, weekStart: weekStart)
                                    }
                                }
                                .tint(palette.success)
                            }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(OneScreenBackground(palette: palette))
        .navigationTitle("Categories")
        .oneNavigationBarDisplayMode(.inline)
    }
}

private struct FinanceCategoryRow: View {
    let palette: OneTheme.Palette
    let category: FinanceCategory

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(palette.surfaceStrong)
                .frame(width: 38, height: 38)
                .overlay(
                    OneIcon(
                        key: category.oneIconKey,
                        palette: palette,
                        size: 18,
                        tint: palette.symbol
                    )
                )
            VStack(alignment: .leading, spacing: 3) {
                Text(category.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.text)
                Text(category.isCustom ? "Custom" : "Starter")
                    .font(OneType.secondary)
                    .foregroundStyle(palette.subtext)
            }
            Spacer()
            if category.isArchived {
                Text("Archived")
                    .font(OneType.caption.weight(.semibold))
                    .foregroundStyle(palette.subtext)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct FinanceTransactionSheet: View {
    let palette: OneTheme.Palette
    @ObservedObject var viewModel: FinanceViewModel
    let weekStart: Int
    let categories: [FinanceCategory]
    let context: FinanceTransactionEditorContext
    let suggestedPaymentMethod: FinancePaymentMethod
    let onClose: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var type: FinanceTransactionType
    @State private var amountText: String
    @State private var selectedCategoryID: String
    @State private var paymentMethod: FinancePaymentMethod
    @State private var transferDestination: FinancePaymentMethod
    @State private var note: String
    @State private var showNote = false
    @State private var occurredAt: Date
    @State private var showTimeEditor = false
    @FocusState private var amountFocused: Bool

    init(
        palette: OneTheme.Palette,
        viewModel: FinanceViewModel,
        weekStart: Int,
        categories: [FinanceCategory],
        context: FinanceTransactionEditorContext,
        suggestedPaymentMethod: FinancePaymentMethod,
        onClose: @escaping () -> Void
    ) {
        self.palette = palette
        self.viewModel = viewModel
        self.weekStart = weekStart
        self.categories = categories
        self.context = context
        self.suggestedPaymentMethod = suggestedPaymentMethod
        self.onClose = onClose
        _type = State(initialValue: context.input.type)
        _amountText = State(initialValue: context.input.amount.map(FinanceFormat.decimalString) ?? "")
        _selectedCategoryID = State(initialValue: context.input.categoryId ?? categories.first?.id ?? "")
        _paymentMethod = State(initialValue: context.input.paymentMethod ?? suggestedPaymentMethod)
        _transferDestination = State(initialValue: context.input.transferCounterpartPaymentMethod ?? ((context.input.paymentMethod ?? suggestedPaymentMethod) == .card ? .cash : .card))
        _note = State(initialValue: context.input.note ?? "")
        _showNote = State(initialValue: !(context.input.note?.isEmpty ?? true))
        _occurredAt = State(initialValue: context.input.occurredAt ?? Date())
    }

    var body: some View {
        NavigationStack {
            OneScrollScreen(palette: palette, bottomPadding: 36) {
                OneGlassCard(palette: palette, padding: OneSpacing.lg) {
                    Text(type == .transfer ? "Move money between accounts without extra ceremony." : "Capture the amount first, then add only the details that matter.")
                        .font(OneType.secondary)
                        .foregroundStyle(palette.subtext)

                    FinanceAmountField(
                        palette: palette,
                        amountText: $amountText,
                        currencyCode: viewModel.homeSnapshot?.balanceState.defaultCurrencyCode ?? "USD"
                    )
                    .focused($amountFocused)

                    OneSegmentedControl(
                        palette: palette,
                        options: FinanceTransactionType.allCases,
                        selection: type,
                        title: { $0.title }
                    ) { selection in
                        type = selection
                    }

                }

                OneSurfaceCard(palette: palette) {
                    OneSectionHeading(
                        palette: palette,
                        title: type == .transfer ? "Transfer details" : "Details",
                        meta: type.title
                    )

                    if type != .transfer {
                        FinanceCategoryChipList(
                            palette: palette,
                            categories: categories,
                            selection: $selectedCategoryID
                        )
                    }

                    if type == .transfer {
                        FinanceTransferMethodPicker(
                            palette: palette,
                            source: $paymentMethod,
                            destination: $transferDestination
                        )
                    } else {
                        FinancePaymentMethodPicker(
                            palette: palette,
                            selection: $paymentMethod
                        )
                    }
                }

                OneSurfaceCard(palette: palette) {
                    OneSectionHeading(palette: palette, title: "Timing & note", meta: nil)

                    if context.transactionID != nil {
                        Button(showTimeEditor ? "Hide time" : "Adjust time") {
                            withAnimation(OneMotion.animation(.expand)) {
                                showTimeEditor.toggle()
                            }
                        }
                        .font(OneType.label)
                        .foregroundStyle(palette.accent)
                    }
                    if showTimeEditor {
                        DatePicker("Occurred", selection: $occurredAt)
                            .datePickerStyle(.compact)
                            .foregroundStyle(palette.text)
                    }

                    Button(showNote ? "Hide note" : "Add note") {
                        withAnimation(OneMotion.animation(.expand)) {
                            showNote.toggle()
                        }
                    }
                    .font(OneType.label)
                    .foregroundStyle(palette.accent)

                    if showNote {
                        FinanceTextEditorField(title: "Note", text: $note, placeholder: "Optional")
                    }
                }

                if let message = viewModel.errorMessage {
                    FinanceInlineStatusCard(message: message, kind: .danger, palette: palette)
                }

                OneActionButton(
                    palette: palette,
                    title: context.transactionID == nil ? "Log \(type.title)" : "Save Changes",
                    style: .primary
                ) {
                    Task {
                        await save()
                    }
                }
            }
            .navigationTitle(context.title)
            .oneNavigationBarDisplayMode(.inline)
            .oneKeyboardDismissible()
            .toolbar {
                ToolbarItem(placement: .oneNavigationLeading) {
                    Button("Cancel") {
                        OneHaptics.shared.trigger(.sheetDismissed)
                        onClose()
                        dismiss()
                    }
                }
            }
            .task {
                try? await Task.sleep(for: .milliseconds(120))
                amountFocused = true
            }
        }
    }

    private func save() async {
        guard let amount = FinanceFormat.amount(from: amountText) else {
            return
        }
        let input = FinanceTransactionWriteInput(
            type: type,
            amount: amount,
            currencyCode: viewModel.homeSnapshot?.balanceState.defaultCurrencyCode,
            categoryId: {
                switch type {
                case .expense, .income:
                    return selectedCategoryID.isEmpty ? nil : selectedCategoryID
                case .transfer:
                    return nil
                }
            }(),
            paymentMethod: paymentMethod,
            transferCounterpartPaymentMethod: type == .transfer ? transferDestination : nil,
            note: showNote ? note : nil,
            occurredAt: occurredAt,
            source: context.input.source
        )
        let success: Bool
        if let transactionID = context.transactionID {
            success = await viewModel.updateTransaction(id: transactionID, input: input, weekStart: weekStart) != nil
        } else {
            success = await viewModel.createTransaction(input, weekStart: weekStart) != nil
        }
        guard success else {
            return
        }
        try? await Task.sleep(for: .milliseconds(180))
        OneHaptics.shared.trigger(.sheetDismissed)
        onClose()
        dismiss()
    }
}

private struct FinanceBalanceSetupSheet: View {
    let palette: OneTheme.Palette
    let initialState: FinanceBalanceState?
    let onSave: (FinanceBalanceUpdateInput) -> Void
    let onClose: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var cardBalanceText: String
    @State private var cashBalanceText: String
    @State private var lowThresholdText: String
    @State private var weeklyThresholdText: String

    init(
        palette: OneTheme.Palette,
        initialState: FinanceBalanceState?,
        onSave: @escaping (FinanceBalanceUpdateInput) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.palette = palette
        self.initialState = initialState
        self.onSave = onSave
        self.onClose = onClose
        _cardBalanceText = State(initialValue: initialState.map { FinanceFormat.decimalString($0.cardBalance) } ?? "")
        _cashBalanceText = State(initialValue: initialState.map { FinanceFormat.decimalString($0.cashBalance) } ?? "")
        _lowThresholdText = State(initialValue: initialState?.lowBalanceThreshold.map(FinanceFormat.decimalString) ?? "")
        _weeklyThresholdText = State(initialValue: initialState?.weeklyPaceThreshold.map(FinanceFormat.decimalString) ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Current balances") {
                    TextField("Card", text: $cardBalanceText)
                        .oneDecimalInput()
                    TextField("Cash", text: $cashBalanceText)
                        .oneDecimalInput()
                }
                Section("Warnings") {
                    TextField("Low balance threshold", text: $lowThresholdText)
                        .oneDecimalInput()
                    TextField("Weekly pace threshold", text: $weeklyThresholdText)
                        .oneDecimalInput()
                }
            }
            .scrollContentBackground(.hidden)
            .background(OneScreenBackground(palette: palette))
            .navigationTitle("Balance Setup")
            .oneNavigationBarDisplayMode(.inline)
            .oneKeyboardDismissible()
            .toolbar {
                ToolbarItem(placement: .oneNavigationLeading) {
                    Button("Cancel") {
                        onClose()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .oneNavigationTrailing) {
                    Button("Save") {
                        onSave(
                            FinanceBalanceUpdateInput(
                                cardBalance: FinanceFormat.amount(from: cardBalanceText) ?? 0,
                                cashBalance: FinanceFormat.amount(from: cashBalanceText) ?? 0,
                                defaultCurrencyCode: initialState?.defaultCurrencyCode ?? Locale.autoupdatingCurrent.currency?.identifier ?? "USD",
                                lowBalanceThreshold: FinanceFormat.amount(from: lowThresholdText),
                                weeklyPaceThreshold: FinanceFormat.amount(from: weeklyThresholdText)
                            )
                        )
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

private struct FinanceCategorySheet: View {
    let palette: OneTheme.Palette
    let context: FinanceCategoryEditorContext
    let onSave: (FinanceCategoryUpdateInput) -> Void
    let onClose: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var iconName: String

    private let iconOptions = OneIconKey.financeCategoryPickerKeys

    init(
        palette: OneTheme.Palette,
        context: FinanceCategoryEditorContext,
        onSave: @escaping (FinanceCategoryUpdateInput) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.palette = palette
        self.context = context
        self.onSave = onSave
        self.onClose = onClose
        _name = State(initialValue: context.name)
        _iconName = State(initialValue: OneIconKey.normalizedFinanceCategoryID(name: context.name, storedIcon: context.iconName))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Category name", text: $name)
                }
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                        ForEach(iconOptions, id: \.self) { icon in
                            Button {
                                iconName = icon.rawValue
                            } label: {
                                OneIcon(
                                    key: icon,
                                    palette: palette,
                                    size: 18,
                                    tint: iconName == icon.rawValue ? palette.accent : palette.subtext
                                )
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: OneTheme.radiusMedium, style: .continuous)
                                        .fill(iconName == icon.rawValue ? palette.accentSoft : palette.surfaceMuted)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(OneScreenBackground(palette: palette))
            .navigationTitle(context.categoryID == nil ? "New Category" : "Edit Category")
            .oneNavigationBarDisplayMode(.inline)
            .oneKeyboardDismissible()
            .toolbar {
                ToolbarItem(placement: .oneNavigationLeading) {
                    Button("Cancel") {
                        onClose()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .oneNavigationTrailing) {
                    Button("Save") {
                        onSave(FinanceCategoryUpdateInput(name: name, iconName: iconName))
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

private struct FinanceRecurringSheet: View {
    let palette: OneTheme.Palette
    let categories: [FinanceCategory]
    let context: FinanceRecurringEditorContext
    let onSave: (FinanceRecurringEditorContext) -> Void
    let onClose: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var amountText: String
    @State private var categoryId: String
    @State private var paymentMethod: FinancePaymentMethod
    @State private var cadenceType: FinanceRecurringCadenceType
    @State private var cadenceIntervalText: String
    @State private var nextDueDate: Date
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var hasEndDate: Bool
    @State private var note: String

    init(
        palette: OneTheme.Palette,
        categories: [FinanceCategory],
        context: FinanceRecurringEditorContext,
        onSave: @escaping (FinanceRecurringEditorContext) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.palette = palette
        self.categories = categories
        self.context = context
        self.onSave = onSave
        self.onClose = onClose
        _title = State(initialValue: context.title)
        _amountText = State(initialValue: context.amount > 0 ? FinanceFormat.decimalString(context.amount) : "")
        _categoryId = State(initialValue: context.categoryId)
        _paymentMethod = State(initialValue: context.paymentMethod)
        _cadenceType = State(initialValue: context.cadenceType)
        _cadenceIntervalText = State(initialValue: context.cadenceInterval.map(String.init) ?? "")
        _nextDueDate = State(initialValue: FinanceFormat.date(from: context.nextDueDate) ?? Date())
        _startDate = State(initialValue: FinanceFormat.date(from: context.startDate) ?? Date())
        _endDate = State(initialValue: FinanceFormat.date(from: context.endDate ?? "") ?? Date())
        _hasEndDate = State(initialValue: context.endDate != nil)
        _note = State(initialValue: context.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Recurring expense") {
                    TextField("Title", text: $title)
                    TextField("Amount", text: $amountText)
                        .oneDecimalInput()
                    Picker("Category", selection: $categoryId) {
                        ForEach(categories, id: \.id) { category in
                            Text(category.name).tag(category.id)
                        }
                    }
                }
                Section("Payment") {
                    FinancePaymentMethodPicker(palette: palette, selection: $paymentMethod)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }
                Section("Cadence") {
                    Picker("Cadence", selection: $cadenceType) {
                        ForEach(FinanceRecurringCadenceType.allCases, id: \.self) { cadence in
                            Text(cadence.title).tag(cadence)
                        }
                    }
                    if cadenceType == .custom {
                        TextField("Every N days", text: $cadenceIntervalText)
                            .oneNumberInput()
                    }
                }
                Section("Dates") {
                    DatePicker("Next due", selection: $nextDueDate, displayedComponents: .date)
                    DatePicker("Start", selection: $startDate, displayedComponents: .date)
                    Toggle("End date", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("End", selection: $endDate, displayedComponents: .date)
                    }
                }
                Section("Note") {
                    FinanceTextEditorField(title: "Note", text: $note, placeholder: "Optional")
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }
            }
            .scrollContentBackground(.hidden)
            .background(OneScreenBackground(palette: palette))
            .navigationTitle(context.recurringID == nil ? "Add Recurring" : "Edit Recurring")
            .oneNavigationBarDisplayMode(.inline)
            .oneKeyboardDismissible()
            .toolbar {
                ToolbarItem(placement: .oneNavigationLeading) {
                    Button("Cancel") {
                        onClose()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .oneNavigationTrailing) {
                    Button("Save") {
                        onSave(
                            FinanceRecurringEditorContext(
                                recurringID: context.recurringID,
                                title: title,
                                amount: FinanceFormat.amount(from: amountText) ?? 0,
                                categoryId: categoryId,
                                paymentMethod: paymentMethod,
                                cadenceType: cadenceType,
                                cadenceInterval: cadenceType == .custom ? Int(cadenceIntervalText) : nil,
                                nextDueDate: FinanceFormat.isoDate(nextDueDate),
                                startDate: FinanceFormat.isoDate(startDate),
                                endDate: hasEndDate ? FinanceFormat.isoDate(endDate) : nil,
                                note: note
                            )
                        )
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

private struct FinanceVoiceCaptureSheet: View {
    let palette: OneTheme.Palette
    let categories: [FinanceCategory]
    let onParsed: (FinanceVoiceParseResult) -> Void
    let onClose: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = FinanceVoiceCaptureViewModel()

    var body: some View {
        NavigationStack {
            OneScrollScreen(palette: palette, bottomPadding: 36) {
                OneGlassCard(palette: palette) {
                    Text("Voice expense")
                        .font(OneType.label)
                        .foregroundStyle(palette.subtext)
                    Text(viewModel.availability == .available ? "Speak a short expense phrase." : "Voice entry is limited to short local expense phrases.")
                        .font(OneType.title)
                        .foregroundStyle(palette.text)
                    Text(exampleLine)
                        .font(OneType.secondary)
                        .foregroundStyle(palette.subtext)
                    Text(viewModel.availability.message)
                        .font(OneType.secondary)
                        .foregroundStyle(palette.subtext)
                }

                OneSurfaceCard(palette: palette) {
                    Text(viewModel.transcript.isEmpty ? "Transcript will appear here." : viewModel.transcript)
                        .font(OneType.body)
                        .foregroundStyle(viewModel.transcript.isEmpty ? palette.subtext : palette.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: 80, alignment: .leading)
                    OneActionButton(
                        palette: palette,
                        title: viewModel.isRecording ? "Stop recording" : "Start recording",
                        style: .primary
                    ) {
                        Task {
                            if viewModel.isRecording {
                                if let result = await viewModel.stop(categories: categories) {
                                    onParsed(result)
                                    dismiss()
                                }
                            } else {
                                await viewModel.start()
                            }
                        }
                    }
                }

                if let message = viewModel.errorMessage {
                    FinanceInlineStatusCard(message: message, kind: .danger, palette: palette)
                }
            }
            .navigationTitle("Voice")
            .oneNavigationBarDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .oneNavigationLeading) {
                    Button("Done") {
                        Task {
                            await viewModel.cancel()
                            onClose()
                            dismiss()
                        }
                    }
                }
            }
            .task {
                await viewModel.refreshAvailability()
            }
        }
    }

    private var exampleLine: String {
        "Examples: “120 on food”, “75 quetzales on gas with card”, “30 coffee cash”."
    }
}

private struct FinancePaymentMethodPicker: View {
    let palette: OneTheme.Palette
    @Binding var selection: FinancePaymentMethod

    var body: some View {
        OneSegmentedControl(
            palette: palette,
            options: FinancePaymentMethod.allCases,
            selection: selection,
            title: { $0.title }
        ) { option in
            selection = option
        }
    }
}

private struct FinanceTransferMethodPicker: View {
    let palette: OneTheme.Palette
    @Binding var source: FinancePaymentMethod
    @Binding var destination: FinancePaymentMethod

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transfer")
                .font(OneType.label)
                .foregroundStyle(palette.subtext)
            FinancePaymentMethodPicker(palette: palette, selection: $source)
            FinancePaymentMethodPicker(palette: palette, selection: $destination)
                .onChange(of: destination) { _, newValue in
                    if newValue == source {
                        destination = newValue == .card ? .cash : .card
                    }
                }
                .onChange(of: source) { _, newValue in
                    if destination == newValue {
                        destination = newValue == .card ? .cash : .card
                    }
                }
            Text("Top control is the source. Bottom control is the destination.")
                .font(OneType.caption)
                .foregroundStyle(palette.subtext)
        }
    }
}

private struct FinanceCategoryChipList: View {
    let palette: OneTheme.Palette
    let categories: [FinanceCategory]
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Category")
                .font(OneType.label)
                .foregroundStyle(palette.subtext)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories) { category in
                        Button {
                            selection = category.id
                        } label: {
                            HStack(spacing: 8) {
                                OneIcon(
                                    key: category.oneIconKey,
                                    palette: palette,
                                    size: 14,
                                    tint: selection == category.id ? palette.text : palette.subtext
                                )
                                Text(category.name)
                            }
                            .font(OneType.secondary.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .foregroundStyle(selection == category.id ? palette.text : palette.subtext)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(selection == category.id ? palette.accentSoft : palette.surfaceMuted)
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(selection == category.id ? palette.accent.opacity(0.6) : palette.border, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct FinanceAmountField: View {
    let palette: OneTheme.Palette
    @Binding var amountText: String
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Amount")
                .font(OneType.label)
                .foregroundStyle(palette.subtext)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(FinanceFormat.currencySymbol(for: currencyCode))
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.subtext)
                TextField("0", text: $amountText)
                    .oneDecimalInput()
                    .font(.system(size: 38, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.text)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: OneTheme.radiusLarge, style: .continuous)
                    .fill(palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: OneTheme.radiusLarge, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            )
        }
    }
}

private struct FinanceSuccessOverlay: View {
    let palette: OneTheme.Palette

    var body: some View {
        VStack(spacing: 12) {
            OneIcon(key: .success, palette: palette, size: 54, tint: palette.success)
            Text("Saved")
                .font(OneType.title)
                .foregroundStyle(palette.text)
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: OneTheme.radiusLarge, style: .continuous)
                .fill(palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: OneTheme.radiusLarge, style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        )
        .shadow(color: palette.shadowColor.opacity(0.18), radius: 18, x: 0, y: 12)
    }
}

private struct FinanceMetricTile: View {
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
                .lineLimit(2)
                .minimumScaleFactor(0.75)
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

private struct FinanceEquationStrip: View {
    let palette: OneTheme.Palette
    let leading: String
    let equation: String
    let result: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(leading)
                .font(OneType.caption.weight(.semibold))
                .foregroundStyle(palette.subtext)
            Text(equation)
                .font(OneType.secondary)
                .foregroundStyle(palette.subtext)
            Text(result)
                .font(OneType.body.weight(.semibold))
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

private struct FinanceInlineStatusCard: View {
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
                OneIcon(
                    key: kind == .danger ? .warning : .coachInsight,
                    palette: palette,
                    size: 16,
                    tint: kind == .danger ? palette.danger : palette.accent
                )
                Text(message)
                    .font(OneType.secondary)
                    .foregroundStyle(kind == .danger ? palette.danger : palette.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct FinanceTextEditorField: View {
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
                .font(OneType.label)
                .foregroundStyle(palette.subtext)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: OneTheme.radiusMedium, style: .continuous)
                    .fill(palette.surfaceMuted)
                if text.isEmpty {
                    Text(placeholder)
                        .font(OneType.body)
                        .foregroundStyle(palette.subtext.opacity(0.8))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                }
                TextEditor(text: $text)
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(palette.text)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(minHeight: 110)
            }
            .overlay(
                RoundedRectangle(cornerRadius: OneTheme.radiusMedium, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            )
        }
    }
}

private struct FinanceDeltaChip: View {
    let palette: OneTheme.Palette
    let label: String
    let delta: Double
    let currencyCode: String

    private var tint: Color {
        delta >= 0 ? palette.success : palette.danger
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(OneType.caption.weight(.semibold))
            Text(FinanceFormat.currency(delta, code: currencyCode))
                .font(OneType.caption.weight(.semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(tint.opacity(0.12))
        )
    }
}

private struct FinanceResolvedCategory {
    let title: String
    let iconKey: OneIconKey
}

private extension FinanceCategoryDrift {
    var oneIconKey: OneIconKey {
        OneIconKey.financeCategory(name: categoryName, storedIcon: iconName)
    }
}

private enum FinanceFormat {
    static func currency(_ amount: Double, code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "\(currencySymbol(for: code))\(decimalString(amount))"
    }

    static func signedCurrency(_ transaction: FinanceTransaction, code: String) -> String {
        let amount = currency(transaction.amount, code: code)
        switch transaction.type {
        case .expense:
            return "-\(amount)"
        case .income:
            return "+\(amount)"
        case .transfer:
            return amount
        }
    }

    static func amountColor(for transaction: FinanceTransaction, palette: OneTheme.Palette) -> Color {
        switch transaction.type {
        case .expense:
            return palette.text
        case .income:
            return palette.success
        case .transfer:
            return palette.highlight
        }
    }

    static func metaLine(for transaction: FinanceTransaction) -> String {
        switch transaction.type {
        case .transfer:
            let source = transaction.paymentMethod?.title ?? "Source"
            let destination = transaction.transferCounterpartPaymentMethod?.title ?? "Destination"
            return "\(source) → \(destination)"
        case .expense, .income:
            return transaction.paymentMethod?.title ?? transaction.source.rawValue.capitalized
        }
    }

    static func secondaryLine(for transaction: FinanceTransaction) -> String {
        if let note = transaction.note, !note.isEmpty {
            return "\(note) · \(metaLine(for: transaction))"
        }
        return metaLine(for: transaction)
    }

    static func resolvedCategory(
        for transaction: FinanceTransaction,
        categories: [FinanceCategory]
    ) -> FinanceResolvedCategory {
        if transaction.type == .transfer {
            return FinanceResolvedCategory(title: "Transfer", iconKey: .transfer)
        }
        if let categoryId = transaction.categoryId,
           let category = categories.first(where: { $0.id == categoryId }) {
            return FinanceResolvedCategory(title: category.name, iconKey: category.oneIconKey)
        }
        switch transaction.type {
        case .expense:
            return FinanceResolvedCategory(title: "Expense", iconKey: .expense)
        case .income:
            return FinanceResolvedCategory(title: "Income", iconKey: .income)
        case .transfer:
            return FinanceResolvedCategory(title: "Transfer", iconKey: .transfer)
        }
    }

    static func decimalString(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
    }

    static func amount(from value: String) -> Double? {
        let sanitized = value.replacingOccurrences(of: ",", with: ".")
        return Double(sanitized)
    }

    static func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func longDate(_ value: String) -> String {
        guard let date = date(from: value) else {
            return value
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    static func isoDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func date(from isoDate: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: isoDate)
    }

    static func currencySymbol(for code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.currencySymbol
    }
}

private extension FinanceRecurringEditorContext {
    func asCreateInput() -> FinanceRecurringCreateInput {
        FinanceRecurringCreateInput(
            title: title,
            amount: amount,
            categoryId: categoryId,
            paymentMethod: paymentMethod,
            cadenceType: cadenceType,
            cadenceInterval: cadenceInterval,
            nextDueDate: nextDueDate,
            startDate: startDate,
            endDate: endDate,
            note: note
        )
    }

    func asUpdateInput() -> FinanceRecurringUpdateInput {
        FinanceRecurringUpdateInput(
            title: title,
            amount: amount,
            categoryId: categoryId,
            paymentMethod: paymentMethod,
            cadenceType: cadenceType,
            cadenceInterval: cadenceInterval,
            nextDueDate: nextDueDate,
            startDate: startDate,
            endDate: endDate,
            note: note
        )
    }
}
#endif
