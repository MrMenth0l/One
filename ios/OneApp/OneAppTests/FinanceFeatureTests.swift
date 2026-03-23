import XCTest
import Foundation
import SwiftData
import Combine
import OneClient

@MainActor
final class FinanceFeatureTests: XCTestCase {
    func testFinanceRepositorySeedsCategoriesAndAppliesExpenseBalanceDelta() async throws {
        let harness = try await makeFinanceHarness()

        let categories = try await harness.repository.loadCategories()
        XCTAssertEqual(categories.count, 11)
        XCTAssertTrue(categories.contains(where: { $0.name == "Food" }))

        guard let food = categories.first(where: { $0.name == "Food" }) else {
            XCTFail("Expected starter Food category")
            return
        }
        XCTAssertEqual(food.iconName, OneIconKey.financeFood.rawValue)
        XCTAssertTrue(categories.allSatisfy { OneIconKey(rawValue: $0.iconName) != nil })

        _ = try await harness.repository.saveBalance(
            FinanceBalanceUpdateInput(
                cardBalance: 500,
                cashBalance: 100,
                lowBalanceThreshold: 50,
                weeklyPaceThreshold: 200
            )
        )

        let created = try await harness.repository.createTransaction(
            FinanceTransactionWriteInput(
                amount: 25,
                categoryId: food.id,
                paymentMethod: .card
            )
        )

        let home = try await harness.repository.loadHome(weekStart: 0)
        XCTAssertEqual(home.balanceState.totalBalance, 575, accuracy: 0.001)
        XCTAssertEqual(home.balanceState.cardBalance, 475, accuracy: 0.001)
        XCTAssertEqual(home.balanceState.cashBalance, 100, accuracy: 0.001)
        XCTAssertEqual(home.todayTransactions.first?.id, created.id)
        XCTAssertEqual(home.suggestedPaymentMethod, .card)
    }

    func testFinanceRepositoryDuplicateUpdateDeleteKeepsBalanceConsistent() async throws {
        let harness = try await makeFinanceHarness()
        let categories = try await harness.repository.loadCategories()
        guard let food = categories.first(where: { $0.name == "Food" }) else {
            XCTFail("Expected starter Food category")
            return
        }

        _ = try await harness.repository.saveBalance(
            FinanceBalanceUpdateInput(cardBalance: 100, cashBalance: 0)
        )

        let original = try await harness.repository.createTransaction(
            FinanceTransactionWriteInput(
                amount: 20,
                categoryId: food.id,
                paymentMethod: .card
            )
        )

        let duplicate = try await harness.repository.duplicateTransaction(id: original.id)
        XCTAssertNotEqual(original.id, duplicate.id)

        _ = try await harness.repository.updateTransaction(
            id: original.id,
            input: FinanceTransactionWriteInput(
                amount: 10,
                categoryId: food.id,
                paymentMethod: .card
            )
        )

        try await harness.repository.deleteTransaction(id: duplicate.id)

        let home = try await harness.repository.loadHome(weekStart: 0)
        XCTAssertEqual(home.balanceState.totalBalance, 90, accuracy: 0.001)
        XCTAssertEqual(home.balanceState.cardBalance, 90, accuracy: 0.001)
        XCTAssertEqual(home.todayTransactions.count, 1)
    }

    func testFinanceRecurringMaterializesDueTransactionOnlyOnce() async throws {
        let harness = try await makeFinanceHarness()
        let categories = try await harness.repository.loadCategories()
        guard let subscriptions = categories.first(where: { $0.name == "Subscriptions" }) else {
            XCTFail("Expected starter Subscriptions category")
            return
        }

        _ = try await harness.repository.saveBalance(
            FinanceBalanceUpdateInput(cardBalance: 200, cashBalance: 0)
        )

        let today = financeTestISODate(Date())
        _ = try await harness.repository.createRecurring(
            FinanceRecurringCreateInput(
                title: "Music",
                amount: 15,
                categoryId: subscriptions.id,
                paymentMethod: .card,
                cadenceType: .monthly,
                nextDueDate: today,
                startDate: today
            )
        )

        let firstHome = try await harness.repository.loadHome(weekStart: 0)
        let secondHome = try await harness.repository.loadHome(weekStart: 0)
        let overview = try await harness.repository.loadRecurringOverview()

        XCTAssertEqual(firstHome.todayTransactions.filter { $0.source == .recurring }.count, 1)
        XCTAssertEqual(secondHome.todayTransactions.filter { $0.source == .recurring }.count, 1)
        XCTAssertEqual(firstHome.balanceState.totalBalance, 185, accuracy: 0.001)
        XCTAssertEqual(overview.activeItems.count, 1)
        XCTAssertNotEqual(overview.activeItems[0].nextDueDate, today)
    }

    func testOneIconKeyNormalizesLegacyFinanceSymbols() {
        XCTAssertEqual(OneIconKey.financeCategory(name: "Food", storedIcon: "fork.knife"), .financeFood)
        XCTAssertEqual(OneIconKey.financeCategory(name: "Gas / Transport", storedIcon: "car.fill"), .financeTransport)
        XCTAssertEqual(OneIconKey.financeCategory(name: "Shopping", storedIcon: "bag.fill"), .financeShopping)
        XCTAssertEqual(OneIconKey.financeCategory(name: "Subscriptions", storedIcon: "repeat.circle.fill"), .financeSubscriptions)
        XCTAssertEqual(OneIconKey.financeCategory(name: "Custom", storedIcon: "questionmark.circle"), .financeMisc)
        XCTAssertEqual(OneIconKey.financeCategory(name: "Unknown", storedIcon: nil), .financeCategory)
    }

    func testFinanceVoiceParserParsesSimpleExpensePhrases() {
        let categories = [
            FinanceCategory(
                id: "food",
                name: "Food",
                iconName: OneIconKey.financeFood.rawValue,
                isCustom: false,
                sortOrder: 0,
                createdAt: Date(),
                updatedAt: Date()
            ),
            FinanceCategory(
                id: "gas",
                name: "Gas / Transport",
                iconName: OneIconKey.financeTransport.rawValue,
                isCustom: false,
                sortOrder: 1,
                createdAt: Date(),
                updatedAt: Date()
            )
        ]

        let parser = FinanceVoiceExpenseParser()
        let gasPhrase = parser.parse("75 quetzales on gas with card", categories: categories)
        let coffeePhrase = parser.parse("30 coffee cash", categories: categories)

        XCTAssertEqual(gasPhrase.input.type, .expense)
        XCTAssertEqual(gasPhrase.input.amount, 75)
        XCTAssertEqual(gasPhrase.input.categoryId, "gas")
        XCTAssertEqual(gasPhrase.input.paymentMethod, .card)

        XCTAssertEqual(coffeePhrase.input.amount, 30)
        XCTAssertEqual(coffeePhrase.input.categoryId, "food")
        XCTAssertEqual(coffeePhrase.input.paymentMethod, .cash)
        XCTAssertNotEqual(coffeePhrase.confidence, .low)
    }

    func testContainerForwardsFinanceViewModelChanges() async throws {
        let api = MockAPIClient()
        let syncQueue = InMemorySyncQueue()
        let financeRepository = FinanceRepositoryStub()
        let container = OneAppContainer(
            authRepository: DefaultAuthRepository(apiClient: api),
            tasksRepository: DefaultTasksRepository(apiClient: api, syncQueue: syncQueue),
            todayRepository: DefaultTodayRepository(apiClient: api, syncQueue: syncQueue),
            financeRepository: financeRepository,
            analyticsRepository: DefaultAnalyticsRepository(apiClient: api),
            reflectionsRepository: DefaultReflectionsRepository(apiClient: api),
            profileRepository: DefaultProfileRepository(apiClient: api),
            coachRepository: DefaultCoachRepository(apiClient: api)
        )

        let changeExpectation = expectation(description: "Container forwards finance updates")
        changeExpectation.assertForOverFulfill = false
        var cancellable: AnyCancellable?
        cancellable = container.objectWillChange.sink {
            changeExpectation.fulfill()
        }

        await container.financeViewModel.refreshAll(weekStart: 0)

        await fulfillment(of: [changeExpectation], timeout: 1.0)
        XCTAssertEqual(container.financeViewModel.homeSnapshot?.todayTransactions.count, 1)
        cancellable?.cancel()
    }

    func testFinanceAnalyticsPeriodCommitWaitsForYearSnapshot() async throws {
        let repository = FinanceRepositoryStub(delayNanos: 150_000_000)
        let viewModel = FinanceViewModel(repository: repository)

        let loadTask = Task {
            await viewModel.selectAnalyticsPeriod(.year, weekStart: 0)
        }

        try await Task.sleep(for: .milliseconds(20))

        XCTAssertEqual(viewModel.selectedAnalyticsPeriod, .week)
        XCTAssertEqual(viewModel.pendingAnalyticsPeriod, .year)
        XCTAssertTrue(viewModel.isSwitchingAnalyticsPeriod)

        await loadTask.value

        XCTAssertEqual(viewModel.selectedAnalyticsPeriod, .year)
        XCTAssertNil(viewModel.pendingAnalyticsPeriod)
        XCTAssertFalse(viewModel.isSwitchingAnalyticsPeriod)
        XCTAssertEqual(viewModel.analyticsSnapshot?.chartPoints.count, 12)
        XCTAssertEqual(viewModel.analyticsSnapshot?.comparisonPoints.count, 12)
    }

    func testLocalFinanceAnalyticsYearSnapshotHasTwelveBuckets() async throws {
        let harness = try await makeFinanceHarness()
        let categories = try await harness.repository.loadCategories()
        guard let food = categories.first(where: { $0.name == "Food" }) else {
            XCTFail("Expected starter Food category")
            return
        }

        _ = try await harness.repository.saveBalance(
            FinanceBalanceUpdateInput(cardBalance: 500, cashBalance: 100)
        )

        _ = try await harness.repository.createTransaction(
            FinanceTransactionWriteInput(
                amount: 25,
                categoryId: food.id,
                paymentMethod: .card,
                occurredAt: Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 1, day: 12))
            )
        )
        _ = try await harness.repository.createTransaction(
            FinanceTransactionWriteInput(
                type: .income,
                amount: 80,
                paymentMethod: .card,
                occurredAt: Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 6, day: 8))
            )
        )

        let snapshot = try await harness.repository.loadAnalytics(period: .year, weekStart: 0)

        XCTAssertEqual(snapshot.chartPoints.count, 12)
        XCTAssertEqual(snapshot.comparisonPoints.count, 12)
    }

    private func makeFinanceHarness() async throws -> FinanceHarness {
        let sessionStore = InMemoryAuthSessionStore()
        let stack = try LocalPersistenceFactory.makeInMemory(sessionStore: sessionStore)
        let authRepository = DefaultAuthRepository(apiClient: stack.apiClient)
        let suffix = String(UUID().uuidString.prefix(8))

        _ = try await authRepository.signup(
            email: "finance-\(suffix)@one.local",
            password: "offline-local-profile",
            displayName: "Finance \(suffix)",
            timezone: "America/Guatemala"
        )

        return FinanceHarness(
            stack: stack,
            repository: LocalFinanceRepository(
                container: stack.container,
                sessionStore: sessionStore
            )
        )
    }
}

private struct FinanceHarness {
    let stack: LocalPersistenceStack
    let repository: LocalFinanceRepository
}

private actor FinanceRepositoryStub: FinanceRepository {
    let delayNanos: UInt64
    private let sampleCategory = FinanceCategory(
        id: "food",
        name: "Food",
        iconName: OneIconKey.financeFood.rawValue,
        isCustom: false,
        sortOrder: 0,
        createdAt: Date(),
        updatedAt: Date()
    )

    private var sampleTransaction: FinanceTransaction {
        FinanceTransaction(
            id: "txn-1",
            type: .expense,
            amount: 12,
            currencyCode: "USD",
            categoryId: sampleCategory.id,
            paymentMethod: .card,
            note: "Coffee",
            occurredAt: Date(),
            createdAt: Date(),
            updatedAt: Date(),
            source: .manual
        )
    }

    init(delayNanos: UInt64 = 0) {
        self.delayNanos = delayNanos
    }

    func loadHome(weekStart: Int) async throws -> FinanceHomeSnapshot {
        FinanceHomeSnapshot(
            balanceState: FinanceBalanceState(
                totalBalance: 320,
                cardBalance: 300,
                cashBalance: 20,
                defaultCurrencyCode: "USD",
                lowBalanceThreshold: 40,
                weeklyPaceThreshold: 100,
                updatedAt: Date()
            ),
            balanceComparisons: [
                FinanceBalanceComparison(label: "Week", delta: -12)
            ],
            insightSummary: FinanceInsightSummary(
                weekSpent: 12,
                weekIncome: 0,
                weekNet: -12,
                projectedMonthSpend: 48,
                topCategories: [
                    FinanceCategoryTotal(
                        categoryId: sampleCategory.id,
                        categoryName: sampleCategory.name,
                        iconName: sampleCategory.iconName,
                        amount: 12
                    )
                ],
                weeklyPaceVsBaseline: 1.0,
                upcomingRecurringCharges: [],
                remainingBalanceProjection: 272
            ),
            warnings: [],
            todayTransactions: [sampleTransaction],
            categoryBreakdown: [
                FinanceCategoryTotal(
                    categoryId: sampleCategory.id,
                    categoryName: sampleCategory.name,
                    iconName: sampleCategory.iconName,
                    amount: 12
                )
            ],
            monthlyRecurringTotal: 0,
            yearlyRecurringTotal: 0,
            suggestedPaymentMethod: .card
        )
    }

    func loadTransactionSections() async throws -> [FinanceTransactionDaySection] {
        [FinanceTransactionDaySection(dateLocal: financeTestISODate(Date()), total: 12, transactions: [sampleTransaction])]
    }

    func loadCategories() async throws -> [FinanceCategory] {
        [sampleCategory]
    }

    func loadAnalytics(period: FinanceAnalyticsPeriod, weekStart: Int) async throws -> FinanceAnalyticsSnapshot {
        try await sleepIfNeeded()
        return FinanceAnalyticsSnapshot(
            period: period,
            startDate: "2026-03-01",
            endDate: "2026-03-31",
            totalSpent: 12,
            totalIncome: 0,
            netMovement: -12,
            projectedMonthSpend: 48,
            recurringBurden: 0,
            insightMessage: "Spending is tracking normally.",
            chartPoints: chartPoints(for: period),
            topCategories: [
                FinanceCategoryTotal(
                    categoryId: sampleCategory.id,
                    categoryName: sampleCategory.name,
                    iconName: sampleCategory.iconName,
                    amount: 12
                )
            ],
            comparisonPoints: comparisonPoints(for: period)
        )
    }

    func loadRecurringOverview() async throws -> FinanceRecurringOverview {
        FinanceRecurringOverview(activeItems: [], monthlyTotal: 0, yearlyTotal: 0, upcomingCharges: [])
    }

    func saveBalance(_ input: FinanceBalanceUpdateInput) async throws -> FinanceBalanceState {
        FinanceBalanceState(
            totalBalance: input.cardBalance + input.cashBalance,
            cardBalance: input.cardBalance,
            cashBalance: input.cashBalance,
            defaultCurrencyCode: input.defaultCurrencyCode ?? "USD",
            lowBalanceThreshold: input.lowBalanceThreshold,
            weeklyPaceThreshold: input.weeklyPaceThreshold,
            updatedAt: Date()
        )
    }

    func createTransaction(_ input: FinanceTransactionWriteInput) async throws -> FinanceTransaction { sampleTransaction }
    func updateTransaction(id: String, input: FinanceTransactionWriteInput) async throws -> FinanceTransaction { sampleTransaction }
    func duplicateTransaction(id: String) async throws -> FinanceTransaction { sampleTransaction }
    func deleteTransaction(id: String) async throws {}
    func createCategory(_ input: FinanceCategoryCreateInput) async throws -> FinanceCategory { sampleCategory }
    func updateCategory(id: String, input: FinanceCategoryUpdateInput) async throws -> FinanceCategory { sampleCategory }
    func setCategoryArchived(id: String, isArchived: Bool) async throws -> FinanceCategory { sampleCategory }

    func createRecurring(_ input: FinanceRecurringCreateInput) async throws -> RecurringFinanceTransaction {
        RecurringFinanceTransaction(
            id: "recurring-1",
            title: input.title,
            amount: input.amount,
            currencyCode: input.currencyCode ?? "USD",
            categoryId: input.categoryId,
            paymentMethod: input.paymentMethod,
            cadenceType: input.cadenceType,
            cadenceInterval: input.cadenceInterval,
            nextDueDate: input.nextDueDate,
            startDate: input.startDate,
            endDate: input.endDate,
            note: input.note,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    func updateRecurring(id: String, input: FinanceRecurringUpdateInput) async throws -> RecurringFinanceTransaction {
        RecurringFinanceTransaction(
            id: id,
            title: input.title ?? "Recurring",
            amount: input.amount ?? 0,
            currencyCode: "USD",
            categoryId: input.categoryId ?? sampleCategory.id,
            paymentMethod: input.paymentMethod ?? .card,
            cadenceType: input.cadenceType ?? .monthly,
            cadenceInterval: input.cadenceInterval,
            nextDueDate: input.nextDueDate ?? financeTestISODate(Date()),
            startDate: input.startDate ?? financeTestISODate(Date()),
            endDate: input.endDate,
            note: input.note,
            isActive: input.isActive ?? true,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    func setRecurringActive(id: String, isActive: Bool) async throws -> RecurringFinanceTransaction {
        try await updateRecurring(id: id, input: FinanceRecurringUpdateInput(isActive: isActive))
    }

    func deleteRecurring(id: String) async throws {}

    private func sleepIfNeeded() async throws {
        guard delayNanos > 0 else {
            return
        }
        try await Task.sleep(nanoseconds: delayNanos)
    }

    private func chartPoints(for period: FinanceAnalyticsPeriod) -> [FinanceAmountChartPoint] {
        switch period {
        case .week:
            return ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"].map { label in
                FinanceAmountChartPoint(label: label, spent: 12, income: 3, net: -9)
            }
        case .month:
            return (1...5).map { week in
                FinanceAmountChartPoint(label: "W\(week)", spent: Double(week) * 10, income: Double(week) * 6, net: Double(week) * -4)
            }
        case .year:
            return (1...12).map { month in
                FinanceAmountChartPoint(label: shortMonth(month), spent: Double(month) * 10, income: Double(month) * 12, net: Double(month) * 2)
            }
        }
    }

    private func comparisonPoints(for period: FinanceAnalyticsPeriod) -> [FinanceComparisonPoint] {
        switch period {
        case .week:
            return (0..<4).map { offset in
                FinanceComparisonPoint(label: offset == 0 ? "Current" : "-\(offset)w", spent: Double(offset + 1) * 12, income: Double(offset + 1) * 4, net: Double(offset + 1) * -8)
            }
        case .month:
            return ["Dec", "Jan", "Feb", "Current"].map { label in
                FinanceComparisonPoint(label: label, spent: 24, income: 10, net: -14)
            }
        case .year:
            return (1...12).map { month in
                FinanceComparisonPoint(label: shortMonth(month), spent: Double(month) * 10, income: Double(month) * 12, net: Double(month) * 2)
            }
        }
    }

    private func shortMonth(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM"
        let date = formatter.calendar.date(from: DateComponents(year: 2026, month: month, day: 1)) ?? Date()
        return formatter.string(from: date)
    }
}

private func financeTestISODate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .autoupdatingCurrent
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
}
