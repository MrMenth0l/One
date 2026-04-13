import Foundation

struct FinanceStarterCategoryTemplate: Sendable, Equatable {
    let name: String
    let iconName: String
    let aliases: [String]
}

struct LocalFinanceCategoryService {
    let starterTemplates: [FinanceStarterCategoryTemplate] = [
        FinanceStarterCategoryTemplate(name: "Food", iconName: OneIconKey.financeFood.rawValue, aliases: ["food", "coffee", "groceries", "lunch", "dinner", "breakfast", "snack"]),
        FinanceStarterCategoryTemplate(name: "Gas / Transport", iconName: OneIconKey.financeTransport.rawValue, aliases: ["gas", "transport", "uber", "taxi", "fuel", "bus", "parking"]),
        FinanceStarterCategoryTemplate(name: "Shopping", iconName: OneIconKey.financeShopping.rawValue, aliases: ["shopping", "store", "clothes", "market"]),
        FinanceStarterCategoryTemplate(name: "Entertainment", iconName: OneIconKey.financeEntertainment.rawValue, aliases: ["entertainment", "movie", "games", "cinema", "music"]),
        FinanceStarterCategoryTemplate(name: "Subscriptions", iconName: OneIconKey.financeSubscriptions.rawValue, aliases: ["subscription", "subscriptions", "netflix", "spotify", "streaming"]),
        FinanceStarterCategoryTemplate(name: "Bills", iconName: OneIconKey.financeBills.rawValue, aliases: ["bill", "bills", "utilities", "internet", "rent", "electricity", "water"]),
        FinanceStarterCategoryTemplate(name: "Health", iconName: OneIconKey.financeHealth.rawValue, aliases: ["health", "doctor", "medicine", "pharmacy", "clinic"]),
        FinanceStarterCategoryTemplate(name: "School", iconName: OneIconKey.financeEducation.rawValue, aliases: ["school", "study", "books", "class", "tuition"]),
        FinanceStarterCategoryTemplate(name: "Gifts", iconName: OneIconKey.financeGifts.rawValue, aliases: ["gift", "gifts", "present"]),
        FinanceStarterCategoryTemplate(name: "Savings", iconName: OneIconKey.financeSavings.rawValue, aliases: ["savings", "save"]),
        FinanceStarterCategoryTemplate(name: "Miscellaneous", iconName: OneIconKey.financeMisc.rawValue, aliases: ["misc", "miscellaneous", "other"])
    ]

    func defaultCurrencyCode() -> String {
        Locale.autoupdatingCurrent.currency?.identifier ?? "USD"
    }
}

enum FinanceDateCoding {
    private static let posixLocale = Locale(identifier: "en_US_POSIX")

    static func calendar(timezoneID: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timezoneID) ?? .autoupdatingCurrent
        return calendar
    }

    static func date(from value: String, timezoneID: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = calendar(timezoneID: timezoneID)
        formatter.locale = posixLocale
        formatter.timeZone = formatter.calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    static func isoDateString(from value: Date, timezoneID: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar(timezoneID: timezoneID)
        formatter.locale = posixLocale
        formatter.timeZone = formatter.calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: value)
    }

    static func localDateString(from value: Date, timezoneID: String) -> String {
        OfflineDateCoding.localDateString(from: value, timezoneID: timezoneID)
    }

    static func dateTime(for isoDate: String, timezoneID: String) -> Date {
        guard let base = date(from: isoDate, timezoneID: timezoneID) else {
            return Date()
        }
        let localCalendar = calendar(timezoneID: timezoneID)
        return localCalendar.date(byAdding: .hour, value: 12, to: base) ?? base
    }

    static func bounds(
        for period: FinanceAnalyticsPeriod,
        anchorDate: String,
        weekStart: Int,
        timezoneID: String
    ) -> (startDate: String, endDate: String) {
        guard let anchor = date(from: anchorDate, timezoneID: timezoneID) else {
            return (anchorDate, anchorDate)
        }
        let localCalendar = calendar(timezoneID: timezoneID)
        switch period {
        case .week:
            let weekday = localCalendar.component(.weekday, from: anchor)
            let normalizedWeekday = (weekday + 5) % 7
            let offset = (normalizedWeekday - weekStart + 7) % 7
            let start = localCalendar.date(byAdding: .day, value: -offset, to: anchor) ?? anchor
            let end = localCalendar.date(byAdding: .day, value: 6, to: start) ?? start
            return (isoDateString(from: start, timezoneID: timezoneID), isoDateString(from: end, timezoneID: timezoneID))
        case .month:
            let components = localCalendar.dateComponents([.year, .month], from: anchor)
            let start = localCalendar.date(from: components) ?? anchor
            let end = localCalendar.date(byAdding: DateComponents(month: 1, day: -1), to: start) ?? anchor
            return (isoDateString(from: start, timezoneID: timezoneID), isoDateString(from: end, timezoneID: timezoneID))
        case .year:
            let year = localCalendar.component(.year, from: anchor)
            let start = localCalendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? anchor
            let end = localCalendar.date(from: DateComponents(year: year, month: 12, day: 31)) ?? anchor
            return (isoDateString(from: start, timezoneID: timezoneID), isoDateString(from: end, timezoneID: timezoneID))
        }
    }

    static func daysElapsedInMonth(anchorDate: String, timezoneID: String) -> Int {
        Int(dayNumber(from: anchorDate)) ?? 1
    }

    static func daysInMonth(anchorDate: String, timezoneID: String) -> Int {
        guard let anchor = date(from: anchorDate, timezoneID: timezoneID) else {
            return 30
        }
        let localCalendar = calendar(timezoneID: timezoneID)
        return localCalendar.range(of: .day, in: .month, for: anchor)?.count ?? 30
    }

    static func shortWeekday(from isoDate: String, timezoneID: String) -> String {
        guard let date = date(from: isoDate, timezoneID: timezoneID) else {
            return ""
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar(timezoneID: timezoneID)
        formatter.locale = posixLocale
        formatter.timeZone = formatter.calendar.timeZone
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    static func shortMonth(for month: Int, timezoneID: String) -> String {
        let localCalendar = calendar(timezoneID: timezoneID)
        guard let date = localCalendar.date(from: DateComponents(year: 2026, month: month, day: 1)) else {
            return ""
        }
        let formatter = DateFormatter()
        formatter.calendar = localCalendar
        formatter.locale = posixLocale
        formatter.timeZone = formatter.calendar.timeZone
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }

    static func dayNumber(from isoDate: String) -> String {
        String(isoDate.suffix(2))
    }

    static func weekOfMonth(from isoDate: String, timezoneID: String) -> Int {
        guard let date = date(from: isoDate, timezoneID: timezoneID) else {
            return 1
        }
        return calendar(timezoneID: timezoneID).component(.weekOfMonth, from: date)
    }

    static func addCadence(
        to isoDate: String,
        cadenceType: FinanceRecurringCadenceType,
        cadenceInterval: Int?,
        timezoneID: String
    ) -> String {
        guard let base = date(from: isoDate, timezoneID: timezoneID) else {
            return isoDate
        }
        let localCalendar = calendar(timezoneID: timezoneID)
        let next: Date
        switch cadenceType {
        case .weekly:
            next = localCalendar.date(byAdding: .day, value: 7, to: base) ?? base
        case .biweekly:
            next = localCalendar.date(byAdding: .day, value: 14, to: base) ?? base
        case .monthly:
            next = localCalendar.date(byAdding: .month, value: 1, to: base) ?? base
        case .yearly:
            next = localCalendar.date(byAdding: .year, value: 1, to: base) ?? base
        case .custom:
            let days = max(cadenceInterval ?? 30, 1)
            next = localCalendar.date(byAdding: .day, value: days, to: base) ?? base
        }
        return isoDateString(from: next, timezoneID: timezoneID)
    }

    static func sequenceDates(startDate: String, endDate: String, timezoneID: String) -> [String] {
        guard let start = date(from: startDate, timezoneID: timezoneID),
              let end = date(from: endDate, timezoneID: timezoneID) else {
            return []
        }
        let localCalendar = calendar(timezoneID: timezoneID)
        var cursor = start
        var values: [String] = []
        while cursor <= end {
            values.append(isoDateString(from: cursor, timezoneID: timezoneID))
            cursor = localCalendar.date(byAdding: .day, value: 1, to: cursor) ?? end.addingTimeInterval(1)
        }
        return values
    }
}

private enum FinanceComputation {
    static func expenseAmount(for transaction: FinanceTransaction) -> Double {
        transaction.type == .expense ? transaction.amount : 0
    }

    static func incomeAmount(for transaction: FinanceTransaction) -> Double {
        transaction.type == .income ? transaction.amount : 0
    }

    static func netAmount(for transaction: FinanceTransaction) -> Double {
        switch transaction.type {
        case .expense:
            return -transaction.amount
        case .income:
            return transaction.amount
        case .transfer:
            return 0
        }
    }
}

struct LocalFinanceRecurringMaterialization {
    let transactions: [FinanceTransaction]
    let updatedRecurringItems: [RecurringFinanceTransaction]
}

struct LocalFinanceRecurringService {
    func materializeDueTransactions(
        recurringItems: [RecurringFinanceTransaction],
        existingTransactions: [FinanceTransaction],
        currentDateLocal: String,
        timezoneID: String
    ) -> LocalFinanceRecurringMaterialization {
        let existingInstanceIDs = Set(existingTransactions.compactMap(\.recurringInstanceId))
        var createdTransactions: [FinanceTransaction] = []
        var updatedRecurringItems: [RecurringFinanceTransaction] = []
        let now = Date()

        for var item in recurringItems where item.isActive {
            guard item.nextDueDate <= currentDateLocal else {
                continue
            }

            while item.isActive && item.nextDueDate <= currentDateLocal {
                if let endDate = item.endDate, item.nextDueDate > endDate {
                    item.isActive = false
                    item.updatedAt = now
                    break
                }

                let instanceID = "\(item.id)|\(item.nextDueDate)"
                if !existingInstanceIDs.contains(instanceID) {
                    createdTransactions.append(
                        FinanceTransaction(
                            id: UUID().uuidString,
                            type: .expense,
                            amount: item.amount,
                            currencyCode: item.currencyCode,
                            categoryId: item.categoryId,
                            paymentMethod: item.paymentMethod,
                            note: item.note,
                            occurredAt: FinanceDateCoding.dateTime(for: item.nextDueDate, timezoneID: timezoneID),
                            createdAt: now,
                            updatedAt: now,
                            source: .recurring,
                            recurringInstanceId: instanceID
                        )
                    )
                }
                item.nextDueDate = FinanceDateCoding.addCadence(
                    to: item.nextDueDate,
                    cadenceType: item.cadenceType,
                    cadenceInterval: item.cadenceInterval,
                    timezoneID: timezoneID
                )
                item.updatedAt = now
                if let endDate = item.endDate, item.nextDueDate > endDate {
                    item.isActive = false
                }
            }
            updatedRecurringItems.append(item)
        }

        return LocalFinanceRecurringMaterialization(
            transactions: createdTransactions.sorted { $0.occurredAt < $1.occurredAt },
            updatedRecurringItems: updatedRecurringItems
        )
    }

    func monthlyTotal(for items: [RecurringFinanceTransaction]) -> Double {
        items
            .filter(\.isActive)
            .reduce(0) { partial, item in
                partial + monthlyAmount(for: item)
            }
    }

    func yearlyTotal(for items: [RecurringFinanceTransaction]) -> Double {
        items
            .filter(\.isActive)
            .reduce(0) { partial, item in
                partial + yearlyAmount(for: item)
            }
    }

    func upcomingCharges(
        for items: [RecurringFinanceTransaction],
        limit: Int = 6
    ) -> [FinanceUpcomingRecurringCharge] {
        items
            .filter(\.isActive)
            .sorted { lhs, rhs in
                if lhs.nextDueDate != rhs.nextDueDate {
                    return lhs.nextDueDate < rhs.nextDueDate
                }
                return lhs.title < rhs.title
            }
            .prefix(limit)
            .map {
                FinanceUpcomingRecurringCharge(
                    recurringId: $0.id,
                    title: $0.title,
                    amount: $0.amount,
                    currencyCode: $0.currencyCode,
                    dueDate: $0.nextDueDate,
                    categoryId: $0.categoryId,
                    paymentMethod: $0.paymentMethod
                )
            }
    }

    private func monthlyAmount(for item: RecurringFinanceTransaction) -> Double {
        switch item.cadenceType {
        case .weekly:
            return item.amount * (52.0 / 12.0)
        case .biweekly:
            return item.amount * (26.0 / 12.0)
        case .monthly:
            return item.amount
        case .yearly:
            return item.amount / 12.0
        case .custom:
            let interval = Double(max(item.cadenceInterval ?? 30, 1))
            return item.amount * (30.0 / interval)
        }
    }

    private func yearlyAmount(for item: RecurringFinanceTransaction) -> Double {
        switch item.cadenceType {
        case .weekly:
            return item.amount * 52.0
        case .biweekly:
            return item.amount * 26.0
        case .monthly:
            return item.amount * 12.0
        case .yearly:
            return item.amount
        case .custom:
            let interval = Double(max(item.cadenceInterval ?? 30, 1))
            return item.amount * (365.0 / interval)
        }
    }
}

struct LocalFinanceAnalyticsService {
    private let recurringService = LocalFinanceRecurringService()

    func transactionSections(
        transactions: [FinanceTransaction],
        timezoneID: String
    ) -> [FinanceTransactionDaySection] {
        let grouped = Dictionary(grouping: transactions) { transaction in
            FinanceDateCoding.localDateString(from: transaction.occurredAt, timezoneID: timezoneID)
        }
        return grouped.keys.sorted(by: >).map { dateLocal in
            let dayTransactions = (grouped[dateLocal] ?? []).sorted { $0.occurredAt > $1.occurredAt }
            let total = dayTransactions.reduce(0) { $0 + FinanceComputation.netAmount(for: $1) }
            return FinanceTransactionDaySection(dateLocal: dateLocal, total: total, transactions: dayTransactions)
        }
    }

    func homeSnapshot(
        balanceState: FinanceBalanceState,
        manualAdjustmentAt: Date?,
        categories: [FinanceCategory],
        transactions: [FinanceTransaction],
        recurringItems: [RecurringFinanceTransaction],
        currentDateLocal: String,
        weekStart: Int,
        timezoneID: String
    ) -> FinanceHomeSnapshot {
        let weekBounds = FinanceDateCoding.bounds(
            for: .week,
            anchorDate: currentDateLocal,
            weekStart: weekStart,
            timezoneID: timezoneID
        )
        let monthBounds = FinanceDateCoding.bounds(
            for: .month,
            anchorDate: currentDateLocal,
            weekStart: weekStart,
            timezoneID: timezoneID
        )
        let previousMonthBounds = shiftedBounds(
            for: .month,
            anchorDate: currentDateLocal,
            offset: -1,
            weekStart: weekStart,
            timezoneID: timezoneID
        )
        let weekTransactions = filter(transactions: transactions, startDate: weekBounds.startDate, endDate: weekBounds.endDate, timezoneID: timezoneID)
        let monthTransactions = filter(transactions: transactions, startDate: monthBounds.startDate, endDate: monthBounds.endDate, timezoneID: timezoneID)
        let previousMonthTransactions = filter(
            transactions: transactions,
            startDate: previousMonthBounds.startDate,
            endDate: previousMonthBounds.endDate,
            timezoneID: timezoneID
        )
        let todayTransactions = transactions
            .filter { FinanceDateCoding.localDateString(from: $0.occurredAt, timezoneID: timezoneID) == currentDateLocal }
            .sorted { $0.occurredAt > $1.occurredAt }
        let categoryBreakdown = topCategories(
            from: monthTransactions,
            categories: categories,
            limit: 4
        )
        let monthlyRecurringTotal = recurringService.monthlyTotal(for: recurringItems)
        let yearlyRecurringTotal = recurringService.yearlyTotal(for: recurringItems)
        let upcomingRecurringCharges = recurringService.upcomingCharges(for: recurringItems)
        let weekSpent = weekTransactions.reduce(0) { $0 + FinanceComputation.expenseAmount(for: $1) }
        let weekIncome = weekTransactions.reduce(0) { $0 + FinanceComputation.incomeAmount(for: $1) }
        let weekNet = weekTransactions.reduce(0) { $0 + FinanceComputation.netAmount(for: $1) }
        let monthSpent = monthTransactions.reduce(0) { $0 + FinanceComputation.expenseAmount(for: $1) }
        let projectedMonthSpend = projectedMonthSpend(
            anchorDate: currentDateLocal,
            monthSpent: monthSpent,
            timezoneID: timezoneID
        )
        let monthIncome = monthTransactions.reduce(0) { $0 + FinanceComputation.incomeAmount(for: $1) }
        let baseline = weeklyBaseline(
            transactions: transactions,
            currentWeekStart: weekBounds.startDate,
            weekStart: weekStart,
            timezoneID: timezoneID
        )
        let paceComparisonBase = baseline > 0 ? baseline : (balanceState.weeklyPaceThreshold ?? 0)
        let weeklyPaceVsBaseline = paceComparisonBase > 0 ? weekSpent / paceComparisonBase : 0
        let upcomingThisMonth = upcomingRecurringWithinMonth(
            currentDateLocal: currentDateLocal,
            recurringItems: recurringItems
        )
        let projectedRemainingSpend = max(projectedMonthSpend - monthSpent, 0)
        let remainingProjection = balanceState.totalBalance - projectedRemainingSpend - upcomingThisMonth
        let insightSummary = FinanceInsightSummary(
            weekSpent: weekSpent,
            weekIncome: weekIncome,
            weekNet: weekNet,
            projectedMonthSpend: projectedMonthSpend,
            topCategories: topCategories(from: monthTransactions, categories: categories, limit: 4),
            weeklyPaceVsBaseline: weeklyPaceVsBaseline,
            upcomingRecurringCharges: upcomingRecurringCharges,
            remainingBalanceProjection: remainingProjection
        )
        let warnings = warnings(
            balanceState: balanceState,
            weekSpent: weekSpent,
            weeklyBaseline: baseline,
            transactions: transactions,
            currentDateLocal: currentDateLocal,
            weekStart: weekStart,
            timezoneID: timezoneID
        )

        return FinanceHomeSnapshot(
            balanceState: balanceState,
            balanceComparisons: balanceComparisons(
                balanceState: balanceState,
                manualAdjustmentAt: manualAdjustmentAt,
                transactions: transactions,
                weekBounds: weekBounds,
                monthBounds: monthBounds,
                timezoneID: timezoneID
            ),
            insightSummary: insightSummary,
            warnings: warnings,
            todayTransactions: Array(todayTransactions.prefix(5)),
            categoryBreakdown: categoryBreakdown,
            monthlyRecurringTotal: monthlyRecurringTotal,
            yearlyRecurringTotal: yearlyRecurringTotal,
            suggestedPaymentMethod: suggestedPaymentMethod(from: transactions),
            cashflowHealth: cashflowHealth(
                balanceState: balanceState,
                totalSpent: monthSpent,
                totalIncome: monthIncome,
                projectedSpend: projectedMonthSpend,
                recurringCommitment: monthlyRecurringTotal,
                upcomingRecurring: upcomingThisMonth,
                weeklyPaceRatio: weeklyPaceVsBaseline,
                recentDailySpend: recentExpenseAverage(
                    transactions: transactions,
                    anchorDate: currentDateLocal,
                    days: 7,
                    timezoneID: timezoneID
                )
            ),
            safeToSpend: safeToSpendSummary(
                balanceState: balanceState,
                totalIncome: monthIncome,
                totalSpent: monthSpent,
                upcomingRecurring: upcomingThisMonth,
                currentDateLocal: currentDateLocal,
                recentDailySpend: recentExpenseAverage(
                    transactions: transactions,
                    anchorDate: currentDateLocal,
                    days: 7,
                    timezoneID: timezoneID
                ),
                timezoneID: timezoneID
            ),
            recurringPressure: recurringPressureSummary(
                period: .month,
                currentTransactions: monthTransactions,
                previousTransactions: previousMonthTransactions,
                recurringItems: recurringItems,
                comparisonIncome: monthIncome,
                previousIncome: previousMonthTransactions.reduce(0) { $0 + FinanceComputation.incomeAmount(for: $1) },
                currentDateLocal: currentDateLocal
            ),
            spendingPattern: spendingPatternSummary(
                period: .month,
                currentTransactions: monthTransactions,
                allTransactions: transactions,
                currentDateLocal: currentDateLocal,
                timezoneID: timezoneID
            ),
            attentionSignals: attentionSignals(
                cashflowHealth: cashflowHealth(
                    balanceState: balanceState,
                    totalSpent: monthSpent,
                    totalIncome: monthIncome,
                    projectedSpend: projectedMonthSpend,
                    recurringCommitment: monthlyRecurringTotal,
                    upcomingRecurring: upcomingThisMonth,
                    weeklyPaceRatio: weeklyPaceVsBaseline,
                    recentDailySpend: recentExpenseAverage(
                        transactions: transactions,
                        anchorDate: currentDateLocal,
                        days: 7,
                        timezoneID: timezoneID
                    )
                ),
                safeToSpend: safeToSpendSummary(
                    balanceState: balanceState,
                    totalIncome: monthIncome,
                    totalSpent: monthSpent,
                    upcomingRecurring: upcomingThisMonth,
                    currentDateLocal: currentDateLocal,
                    recentDailySpend: recentExpenseAverage(
                        transactions: transactions,
                        anchorDate: currentDateLocal,
                        days: 7,
                        timezoneID: timezoneID
                    ),
                    timezoneID: timezoneID
                ),
                recurringPressure: recurringPressureSummary(
                    period: .month,
                    currentTransactions: monthTransactions,
                    previousTransactions: previousMonthTransactions,
                    recurringItems: recurringItems,
                    comparisonIncome: monthIncome,
                    previousIncome: previousMonthTransactions.reduce(0) { $0 + FinanceComputation.incomeAmount(for: $1) },
                    currentDateLocal: currentDateLocal
                ),
                spendingPattern: spendingPatternSummary(
                    period: .month,
                    currentTransactions: monthTransactions,
                    allTransactions: transactions,
                    currentDateLocal: currentDateLocal,
                    timezoneID: timezoneID
                ),
                categoryDrift: categoryDrift(
                    currentTransactions: monthTransactions,
                    previousTransactions: previousMonthTransactions,
                    categories: categories,
                    totalSpent: monthSpent,
                    period: .month
                ),
                unusualRecentSpending: unusualRecentSpending(
                    transactions: transactions,
                    currentDateLocal: currentDateLocal,
                    timezoneID: timezoneID
                )
            ),
            categoryDrift: categoryDrift(
                currentTransactions: monthTransactions,
                previousTransactions: previousMonthTransactions,
                categories: categories,
                totalSpent: monthSpent,
                period: .month
            )
        )
    }

    func analyticsSnapshot(
        period: FinanceAnalyticsPeriod,
        balanceState: FinanceBalanceState,
        categories: [FinanceCategory],
        transactions: [FinanceTransaction],
        recurringItems: [RecurringFinanceTransaction],
        currentDateLocal: String,
        weekStart: Int,
        timezoneID: String
    ) -> FinanceAnalyticsSnapshot {
        let bounds = FinanceDateCoding.bounds(
            for: period,
            anchorDate: currentDateLocal,
            weekStart: weekStart,
            timezoneID: timezoneID
        )
        let previousBounds = shiftedBounds(
            for: period,
            anchorDate: currentDateLocal,
            offset: -1,
            weekStart: weekStart,
            timezoneID: timezoneID
        )
        let periodTransactions = filter(
            transactions: transactions,
            startDate: bounds.startDate,
            endDate: bounds.endDate,
            timezoneID: timezoneID
        )
        let previousTransactions = filter(
            transactions: transactions,
            startDate: previousBounds.startDate,
            endDate: previousBounds.endDate,
            timezoneID: timezoneID
        )
        let totalSpent = periodTransactions.reduce(0) { $0 + FinanceComputation.expenseAmount(for: $1) }
        let totalIncome = periodTransactions.reduce(0) { $0 + FinanceComputation.incomeAmount(for: $1) }
        let netMovement = periodTransactions.reduce(0) { $0 + FinanceComputation.netAmount(for: $1) }
        let topCategories = topCategories(from: periodTransactions, categories: categories, limit: 5)
        let chartPoints = chartPoints(
            period: period,
            transactions: periodTransactions,
            bounds: bounds,
            timezoneID: timezoneID
        )
        let comparisonPoints = comparisonPoints(
            period: period,
            transactions: transactions,
            currentDateLocal: currentDateLocal,
            weekStart: weekStart,
            timezoneID: timezoneID
        )
        let projected = period == .month ? projectedMonthSpend(anchorDate: currentDateLocal, monthSpent: totalSpent, timezoneID: timezoneID) : nil
        let recurringBurden = period == .year
            ? recurringService.yearlyTotal(for: recurringItems)
            : recurringService.monthlyTotal(for: recurringItems)
        let monthBounds = FinanceDateCoding.bounds(
            for: .month,
            anchorDate: currentDateLocal,
            weekStart: weekStart,
            timezoneID: timezoneID
        )
        let monthTransactions = filter(
            transactions: transactions,
            startDate: monthBounds.startDate,
            endDate: monthBounds.endDate,
            timezoneID: timezoneID
        )
        let currentMonthIncome = monthTransactions.reduce(0) { $0 + FinanceComputation.incomeAmount(for: $1) }
        let currentMonthSpent = monthTransactions.reduce(0) { $0 + FinanceComputation.expenseAmount(for: $1) }
        let currentMonthProjected = projectedMonthSpend(
            anchorDate: currentDateLocal,
            monthSpent: currentMonthSpent,
            timezoneID: timezoneID
        )
        let upcomingThisMonth = upcomingRecurringWithinMonth(
            currentDateLocal: currentDateLocal,
            recurringItems: recurringItems
        )
        let recentDailySpend = recentExpenseAverage(
            transactions: transactions,
            anchorDate: currentDateLocal,
            days: 7,
            timezoneID: timezoneID
        )
        let paceRatio = period == .week ? weeklyPaceRatio(
            transactions: transactions,
            currentDateLocal: currentDateLocal,
            weekStart: weekStart,
            timezoneID: timezoneID
        ) : projectedPaceRatio(
            currentTotal: projected ?? totalSpent,
            previousTotal: previousTransactions.reduce(0) { $0 + FinanceComputation.expenseAmount(for: $1) }
        )
        let cashflow = cashflowHealth(
            balanceState: balanceState,
            totalSpent: period == .month ? currentMonthSpent : totalSpent,
            totalIncome: period == .month ? currentMonthIncome : totalIncome,
            projectedSpend: period == .month ? currentMonthProjected : projected,
            recurringCommitment: recurringService.monthlyTotal(for: recurringItems),
            upcomingRecurring: upcomingThisMonth,
            weeklyPaceRatio: paceRatio,
            recentDailySpend: recentDailySpend
        )
        let safeToSpend = safeToSpendSummary(
            balanceState: balanceState,
            totalIncome: currentMonthIncome,
            totalSpent: currentMonthSpent,
            upcomingRecurring: upcomingThisMonth,
            currentDateLocal: currentDateLocal,
            recentDailySpend: recentDailySpend,
            timezoneID: timezoneID
        )
        let recurringPressure = recurringPressureSummary(
            period: period,
            currentTransactions: periodTransactions,
            previousTransactions: previousTransactions,
            recurringItems: recurringItems,
            comparisonIncome: totalIncome,
            previousIncome: previousTransactions.reduce(0) { $0 + FinanceComputation.incomeAmount(for: $1) },
            currentDateLocal: currentDateLocal
        )
        let spendingPattern = spendingPatternSummary(
            period: period,
            currentTransactions: periodTransactions,
            allTransactions: transactions,
            currentDateLocal: currentDateLocal,
            timezoneID: timezoneID
        )
        let drift = categoryDrift(
            currentTransactions: periodTransactions,
            previousTransactions: previousTransactions,
            categories: categories,
            totalSpent: totalSpent,
            period: period
        )
        return FinanceAnalyticsSnapshot(
            period: period,
            startDate: bounds.startDate,
            endDate: bounds.endDate,
            totalSpent: totalSpent,
            totalIncome: totalIncome,
            netMovement: netMovement,
            projectedMonthSpend: projected,
            recurringBurden: recurringBurden,
            insightMessage: insightMessage(
                period: period,
                totalSpent: totalSpent,
                totalIncome: totalIncome,
                comparisonPoints: comparisonPoints
            ),
            chartPoints: chartPoints,
            topCategories: topCategories,
            comparisonPoints: comparisonPoints,
            cashflowHealth: cashflow,
            safeToSpend: safeToSpend,
            recurringPressure: recurringPressure,
            spendingPattern: spendingPattern,
            attentionSignals: attentionSignals(
                cashflowHealth: cashflow,
                safeToSpend: safeToSpend,
                recurringPressure: recurringPressure,
                spendingPattern: spendingPattern,
                categoryDrift: drift,
                unusualRecentSpending: unusualRecentSpending(
                    transactions: transactions,
                    currentDateLocal: currentDateLocal,
                    timezoneID: timezoneID
                )
            ),
            categoryDrift: drift
        )
    }

    func recurringOverview(for recurringItems: [RecurringFinanceTransaction]) -> FinanceRecurringOverview {
        FinanceRecurringOverview(
            activeItems: recurringItems.filter(\.isActive).sorted { lhs, rhs in
                if lhs.nextDueDate != rhs.nextDueDate {
                    return lhs.nextDueDate < rhs.nextDueDate
                }
                return lhs.title < rhs.title
            },
            monthlyTotal: recurringService.monthlyTotal(for: recurringItems),
            yearlyTotal: recurringService.yearlyTotal(for: recurringItems),
            upcomingCharges: recurringService.upcomingCharges(for: recurringItems)
        )
    }

    private func shiftedBounds(
        for period: FinanceAnalyticsPeriod,
        anchorDate: String,
        offset: Int,
        weekStart: Int,
        timezoneID: String
    ) -> (startDate: String, endDate: String) {
        guard let anchor = FinanceDateCoding.date(from: anchorDate, timezoneID: timezoneID) else {
            return FinanceDateCoding.bounds(for: period, anchorDate: anchorDate, weekStart: weekStart, timezoneID: timezoneID)
        }
        let localCalendar = FinanceDateCoding.calendar(timezoneID: timezoneID)
        let shiftedDate: Date
        switch period {
        case .week:
            shiftedDate = localCalendar.date(byAdding: .day, value: 7 * offset, to: anchor) ?? anchor
        case .month:
            shiftedDate = localCalendar.date(byAdding: .month, value: offset, to: anchor) ?? anchor
        case .year:
            shiftedDate = localCalendar.date(byAdding: .year, value: offset, to: anchor) ?? anchor
        }
        let shiftedAnchor = FinanceDateCoding.isoDateString(from: shiftedDate, timezoneID: timezoneID)
        return FinanceDateCoding.bounds(for: period, anchorDate: shiftedAnchor, weekStart: weekStart, timezoneID: timezoneID)
    }

    private func filter(
        transactions: [FinanceTransaction],
        startDate: String,
        endDate: String,
        timezoneID: String
    ) -> [FinanceTransaction] {
        transactions.filter { transaction in
            let localDate = FinanceDateCoding.localDateString(from: transaction.occurredAt, timezoneID: timezoneID)
            return localDate >= startDate && localDate <= endDate
        }
    }

    private func topCategories(
        from transactions: [FinanceTransaction],
        categories: [FinanceCategory],
        limit: Int
    ) -> [FinanceCategoryTotal] {
        let expenseTransactions = transactions.filter { $0.type == .expense }
        let grouped = Dictionary(grouping: expenseTransactions, by: { $0.categoryId ?? "uncategorized" })
        return grouped
            .map { categoryID, items in
                let total = items.reduce(0) { $0 + $1.amount }
                let category = categories.first(where: { $0.id == categoryID })
                return FinanceCategoryTotal(
                    categoryId: categoryID,
                    categoryName: category?.name ?? "Uncategorized",
                    iconName: category?.iconName ?? "questionmark.circle",
                    amount: total
                )
            }
            .sorted { lhs, rhs in
                if lhs.amount != rhs.amount {
                    return lhs.amount > rhs.amount
                }
                return lhs.categoryName < rhs.categoryName
            }
            .prefix(limit)
            .map { $0 }
    }

    private func categoryDrift(
        currentTransactions: [FinanceTransaction],
        previousTransactions: [FinanceTransaction],
        categories: [FinanceCategory],
        totalSpent: Double,
        period: FinanceAnalyticsPeriod
    ) -> [FinanceCategoryDrift] {
        let currentTotals = categoryTotalsMap(from: currentTransactions, categories: categories)
        let previousTotals = categoryTotalsMap(from: previousTransactions, categories: categories)
        let categoryIDs = Set(currentTotals.keys).union(previousTotals.keys)
        return categoryIDs.compactMap { categoryID in
            let current = currentTotals[categoryID]
            let previous = previousTotals[categoryID]
            let currentAmount = current?.amount ?? 0
            let previousAmount = previous?.amount ?? 0
            let deltaAmount = currentAmount - previousAmount
            guard currentAmount > 0.009 || previousAmount > 0.009 else {
                return nil
            }
            let changeRatio = previousAmount > 0.009 ? currentAmount / previousAmount : nil
            let share = totalSpent > 0 ? currentAmount / totalSpent : 0
            let name = current?.categoryName ?? previous?.categoryName ?? "Uncategorized"
            let message: String
            if previousAmount <= 0.009 {
                message = "\(name) is newly material in this \(period.title.lowercased()) view."
            } else if let changeRatio, changeRatio >= 1.18 {
                let percent = Int(((changeRatio - 1) * 100).rounded())
                message = "\(name) is \(percent)% above the previous \(period.title.lowercased()) reference."
            } else if let changeRatio, changeRatio <= 0.82 {
                let percent = Int(((1 - changeRatio) * 100).rounded())
                message = "\(name) eased by \(percent)% versus the previous \(period.title.lowercased()) reference."
            } else {
                message = "\(name) remains one of the dominant categories in this \(period.title.lowercased()) range."
            }
            return FinanceCategoryDrift(
                categoryId: categoryID,
                categoryName: name,
                iconName: current?.iconName ?? previous?.iconName ?? "questionmark.circle",
                currentAmount: currentAmount,
                previousAmount: previousAmount,
                deltaAmount: deltaAmount,
                shareOfSpend: share,
                changeRatio: changeRatio,
                message: message
            )
        }
        .sorted { lhs, rhs in
            let lhsScore = lhs.currentAmount + max(lhs.deltaAmount, 0) + (lhs.shareOfSpend * 100)
            let rhsScore = rhs.currentAmount + max(rhs.deltaAmount, 0) + (rhs.shareOfSpend * 100)
            if lhsScore != rhsScore {
                return lhsScore > rhsScore
            }
            return lhs.categoryName < rhs.categoryName
        }
    }

    private func categoryTotalsMap(
        from transactions: [FinanceTransaction],
        categories: [FinanceCategory]
    ) -> [String: FinanceCategoryTotal] {
        Dictionary(
            uniqueKeysWithValues: topCategories(
                from: transactions,
                categories: categories,
                limit: max(categories.count + 5, 12)
            ).map { ($0.categoryId, $0) }
        )
    }

    private func projectedMonthSpend(anchorDate: String, monthSpent: Double, timezoneID: String) -> Double {
        let elapsed = Double(max(FinanceDateCoding.daysElapsedInMonth(anchorDate: anchorDate, timezoneID: timezoneID), 1))
        let days = Double(max(FinanceDateCoding.daysInMonth(anchorDate: anchorDate, timezoneID: timezoneID), 1))
        return (monthSpent / elapsed) * days
    }

    private func projectedPaceRatio(currentTotal: Double, previousTotal: Double) -> Double {
        guard previousTotal > 0.009 else {
            return currentTotal > 0.009 ? 1 : 0
        }
        return currentTotal / previousTotal
    }

    private func weeklyBaseline(
        transactions: [FinanceTransaction],
        currentWeekStart: String,
        weekStart: Int,
        timezoneID: String
    ) -> Double {
        guard let currentWeekStartDate = FinanceDateCoding.date(from: currentWeekStart, timezoneID: timezoneID) else {
            return 0
        }
        let localCalendar = FinanceDateCoding.calendar(timezoneID: timezoneID)
        var priorTotals: [Double] = []
        for offset in 1...4 {
            guard let weekStartDate = localCalendar.date(byAdding: .day, value: -(7 * offset), to: currentWeekStartDate) else {
                continue
            }
            let start = FinanceDateCoding.isoDateString(from: weekStartDate, timezoneID: timezoneID)
            let endDate = localCalendar.date(byAdding: .day, value: 6, to: weekStartDate) ?? weekStartDate
            let end = FinanceDateCoding.isoDateString(from: endDate, timezoneID: timezoneID)
            let total = filter(transactions: transactions, startDate: start, endDate: end, timezoneID: timezoneID)
                .reduce(0) { $0 + FinanceComputation.expenseAmount(for: $1) }
            if total > 0 {
                priorTotals.append(total)
            }
        }
        guard !priorTotals.isEmpty else {
            return 0
        }
        return priorTotals.reduce(0, +) / Double(priorTotals.count)
    }

    private func weeklyPaceRatio(
        transactions: [FinanceTransaction],
        currentDateLocal: String,
        weekStart: Int,
        timezoneID: String
    ) -> Double {
        let weekBounds = FinanceDateCoding.bounds(
            for: .week,
            anchorDate: currentDateLocal,
            weekStart: weekStart,
            timezoneID: timezoneID
        )
        let weekSpent = filter(
            transactions: transactions,
            startDate: weekBounds.startDate,
            endDate: weekBounds.endDate,
            timezoneID: timezoneID
        ).reduce(0) { $0 + FinanceComputation.expenseAmount(for: $1) }
        let baseline = weeklyBaseline(
            transactions: transactions,
            currentWeekStart: weekBounds.startDate,
            weekStart: weekStart,
            timezoneID: timezoneID
        )
        guard baseline > 0.009 else {
            return weekSpent > 0.009 ? 1 : 0
        }
        return weekSpent / baseline
    }

    private func upcomingRecurringWithinMonth(
        currentDateLocal: String,
        recurringItems: [RecurringFinanceTransaction]
    ) -> Double {
        let currentMonthPrefix = String(currentDateLocal.prefix(7))
        return recurringItems
            .filter(\.isActive)
            .filter { $0.nextDueDate.hasPrefix(currentMonthPrefix) && $0.nextDueDate >= currentDateLocal }
            .reduce(0) { $0 + $1.amount }
    }

    private func recentExpenseAverage(
        transactions: [FinanceTransaction],
        anchorDate: String,
        days: Int,
        timezoneID: String
    ) -> Double {
        let localCalendar = FinanceDateCoding.calendar(timezoneID: timezoneID)
        guard let anchor = FinanceDateCoding.date(from: anchorDate, timezoneID: timezoneID),
              let start = localCalendar.date(byAdding: .day, value: -(days - 1), to: anchor) else {
            return 0
        }
        let spent = filter(
            transactions: transactions,
            startDate: FinanceDateCoding.isoDateString(from: start, timezoneID: timezoneID),
            endDate: anchorDate,
            timezoneID: timezoneID
        ).reduce(0) { partial, transaction in
            partial + FinanceComputation.expenseAmount(for: transaction)
        }
        return spent / Double(max(days, 1))
    }

    private func reserveFloor(balanceState: FinanceBalanceState) -> Double {
        let balancePercentFloor = max(balanceState.totalBalance * 0.12, 0)
        let paceFloor = max((balanceState.weeklyPaceThreshold ?? 0) * 0.35, 0)
        return max(balanceState.lowBalanceThreshold ?? 0, max(balancePercentFloor, paceFloor))
    }

    private func cashflowHealth(
        balanceState: FinanceBalanceState,
        totalSpent: Double,
        totalIncome: Double,
        projectedSpend: Double?,
        recurringCommitment: Double,
        upcomingRecurring: Double,
        weeklyPaceRatio: Double,
        recentDailySpend: Double
    ) -> FinanceCashflowHealth {
        let reserve = reserveFloor(balanceState: balanceState)
        let projectedOutflow = projectedSpend ?? totalSpent
        let freeCashflow = totalIncome - projectedOutflow - recurringCommitment
        let projectedBalance = balanceState.totalBalance - max(projectedOutflow - totalSpent, 0) - upcomingRecurring
        let availableRunwayCash = max(balanceState.totalBalance - reserve, 0)
        let runwayDays = recentDailySpend > 0.009
            ? Int((availableRunwayCash / recentDailySpend).rounded(.down))
            : 999
        let commitmentShare = totalIncome > 0.009 ? recurringCommitment / totalIncome : (recurringCommitment > 0.009 ? 1 : 0)

        var score = 86
        if freeCashflow < 0 {
            score -= 22
        }
        if projectedBalance < reserve {
            score -= 24
        }
        if commitmentShare > 0.38 {
            score -= 16
        }
        if weeklyPaceRatio > 1.16 {
            score -= 14
        } else if weeklyPaceRatio > 1.04 {
            score -= 7
        }
        if runwayDays < 14 {
            score -= 14
        } else if runwayDays < 28 {
            score -= 8
        }
        score = min(max(score, 8), 98)

        let status: FinanceHealthStatus
        switch score {
        case 78...:
            status = .resilient
        case 58...:
            status = .steady
        case 36...:
            status = .pressured
        default:
            status = .critical
        }

        let headline: String
        let message: String
        switch status {
        case .resilient:
            headline = "Cashflow is covering the cycle."
            message = commitmentShare > 0.28
                ? "Income still covers spending, but fixed commitments are taking a meaningful share of inflow."
                : "Income, balance, and commitments remain in a healthy relationship right now."
        case .steady:
            headline = "This month is healthy, but tighter than usual."
            message = weeklyPaceRatio > 1.08
                ? "Spending pace is accelerating faster than your recent baseline."
                : "Free cash remains positive, but balance resilience is narrowing."
        case .pressured:
            headline = "Free cash is tightening."
            message = freeCashflow < 0
                ? "Projected spending and fixed commitments are now moving ahead of current inflow."
                : "Balance is still covering the month, but the remaining cushion is getting thin."
        case .critical:
            headline = "Cashflow needs attention now."
            message = "Projected balance is falling close to reserve after current pace and scheduled charges."
        }

        return FinanceCashflowHealth(
            status: status,
            score: score,
            headline: headline,
            message: message,
            freeCashflow: freeCashflow,
            projectedBalance: projectedBalance,
            reserveFloor: reserve,
            runwayDays: max(runwayDays, 0),
            commitmentShareOfIncome: commitmentShare,
            spendingPaceRatio: weeklyPaceRatio
        )
    }

    private func safeToSpendSummary(
        balanceState: FinanceBalanceState,
        totalIncome: Double,
        totalSpent: Double,
        upcomingRecurring: Double,
        currentDateLocal: String,
        recentDailySpend: Double,
        timezoneID: String
    ) -> FinanceSafeToSpendSummary {
        let reserve = reserveFloor(balanceState: balanceState)
        let daysRemaining = max(
            FinanceDateCoding.daysInMonth(anchorDate: currentDateLocal, timezoneID: timezoneID)
                - FinanceDateCoding.daysElapsedInMonth(anchorDate: currentDateLocal, timezoneID: timezoneID),
            0
        )
        let liquidityRoom = max(balanceState.totalBalance - reserve - upcomingRecurring, 0)
        let cycleRoom = max(totalIncome - totalSpent - upcomingRecurring, 0)
        let paceBuffer = recentDailySpend * min(Double(max(daysRemaining, 1)), 5) * 0.45
        let safeAmount = max(min(liquidityRoom, max(cycleRoom, liquidityRoom * 0.72)) - paceBuffer, 0)
        let dailyAllowance = daysRemaining > 0 ? safeAmount / Double(daysRemaining) : safeAmount

        let status: FinanceHealthStatus
        if safeAmount <= 0.009 {
            status = .critical
        } else if dailyAllowance < max(recentDailySpend * 0.6, 4) {
            status = .pressured
        } else if dailyAllowance < max(recentDailySpend * 0.95, 8) {
            status = .steady
        } else {
            status = .resilient
        }

        let headline: String
        let message: String
        switch status {
        case .resilient:
            headline = "Discretionary room remains open."
            message = "After reserve and scheduled charges, spending can stay near \(Int(dailyAllowance.rounded())) per day for the rest of the month."
        case .steady:
            headline = "Safe to spend is healthy, but measured."
            message = "You can keep discretionary spending near \(Int(dailyAllowance.rounded())) per day without eroding the month."
        case .pressured:
            headline = "Discretionary room is narrowing."
            message = "Keep discretionary spending close to \(Int(dailyAllowance.rounded())) per day to avoid dipping below reserve."
        case .critical:
            headline = "There is no clear discretionary cushion."
            message = "Current pace already consumes the cash left after reserve and scheduled commitments."
        }

        return FinanceSafeToSpendSummary(
            status: status,
            amount: safeAmount,
            dailyAllowance: dailyAllowance,
            daysRemaining: daysRemaining,
            headline: headline,
            message: message
        )
    }

    private func recurringPressureSummary(
        period: FinanceAnalyticsPeriod,
        currentTransactions _: [FinanceTransaction],
        previousTransactions: [FinanceTransaction],
        recurringItems: [RecurringFinanceTransaction],
        comparisonIncome: Double,
        previousIncome: Double,
        currentDateLocal: String
    ) -> FinanceRecurringPressureSummary {
        let monthlyCommitment = recurringService.monthlyTotal(for: recurringItems)
        let yearlyCommitment = recurringService.yearlyTotal(for: recurringItems)
        let priorRecurringSpend = previousTransactions
            .filter { $0.source == .recurring }
            .reduce(0) { $0 + FinanceComputation.expenseAmount(for: $1) }
        let referenceIncome = max(comparisonIncome, previousIncome)
        let shareOfIncome = referenceIncome > 0.009 ? (period == .year ? yearlyCommitment / referenceIncome : monthlyCommitment / referenceIncome) : 0
        let upcomingCharges = recurringItems
            .filter(\.isActive)
            .filter { $0.nextDueDate >= currentDateLocal && $0.nextDueDate.hasPrefix(String(currentDateLocal.prefix(7))) }
            .reduce(0) { $0 + $1.amount }
        let growth = priorRecurringSpend > 0.009 ? (monthlyCommitment - priorRecurringSpend) / priorRecurringSpend : nil

        let headline: String
        let message: String
        if let growth, growth > 0.12, comparisonIncome <= max(previousIncome * 1.05, 0.01) {
            headline = "Commitment load is rising."
            message = "Fixed monthly commitments are increasing faster than income."
        } else if shareOfIncome > 0.35 {
            headline = "Recurring load is heavy."
            message = "Recurring charges are taking a large share of current inflow."
        } else if upcomingCharges > (monthlyCommitment * 0.45) && monthlyCommitment > 0.009 {
            headline = "A large share of fixed charges is still ahead."
            message = "Much of this month's commitment load still has to clear."
        } else {
            headline = "Recurring load is contained."
            message = "Fixed commitments remain stable relative to the current income picture."
        }

        return FinanceRecurringPressureSummary(
            activeCount: recurringItems.filter(\.isActive).count,
            monthlyCommitment: monthlyCommitment,
            yearlyCommitment: yearlyCommitment,
            shareOfIncome: shareOfIncome,
            upcomingChargesTotal: upcomingCharges,
            growthVsPreviousMonth: growth,
            headline: headline,
            message: message
        )
    }

    private func spendingPatternSummary(
        period: FinanceAnalyticsPeriod,
        currentTransactions: [FinanceTransaction],
        allTransactions: [FinanceTransaction],
        currentDateLocal: String,
        timezoneID: String
    ) -> FinanceSpendingPatternSummary {
        let recentDaily = recentExpenseAverage(
            transactions: allTransactions,
            anchorDate: currentDateLocal,
            days: 7,
            timezoneID: timezoneID
        )
        let baselineDaily = recentExpenseAverage(
            transactions: allTransactions,
            anchorDate: shiftedAnchorDate(from: currentDateLocal, days: -7, timezoneID: timezoneID),
            days: 14,
            timezoneID: timezoneID
        )
        let currentSpend = currentTransactions.reduce(0) { $0 + FinanceComputation.expenseAmount(for: $1) }
        let projectedSpend = period == .month ? projectedMonthSpend(anchorDate: currentDateLocal, monthSpent: currentSpend, timezoneID: timezoneID) : nil

        let acceleratedAfterMidpoint: Bool = {
            guard period == .month else {
                return recentDaily > (baselineDaily * 1.18) && baselineDaily > 0.009
            }
            let midpoint = 15
            let firstHalf = currentTransactions.filter {
                FinanceComputation.expenseAmount(for: $0) > 0 &&
                Int(FinanceDateCoding.dayNumber(from: FinanceDateCoding.localDateString(from: $0.occurredAt, timezoneID: timezoneID))) ?? 0 <= midpoint
            }.reduce(0) { $0 + FinanceComputation.expenseAmount(for: $1) } / 15.0
            let secondHalfDayCount = max(FinanceDateCoding.daysElapsedInMonth(anchorDate: currentDateLocal, timezoneID: timezoneID) - midpoint, 1)
            let secondHalf = currentTransactions.filter {
                FinanceComputation.expenseAmount(for: $0) > 0 &&
                Int(FinanceDateCoding.dayNumber(from: FinanceDateCoding.localDateString(from: $0.occurredAt, timezoneID: timezoneID))) ?? 0 > midpoint
            }.reduce(0) { $0 + FinanceComputation.expenseAmount(for: $1) } / Double(secondHalfDayCount)
            return secondHalf > (firstHalf * 1.18) && secondHalf > 0.009
        }()

        let message: String
        if acceleratedAfterMidpoint {
            message = "Discretionary spending accelerated after the second week of the month."
        } else if baselineDaily > 0.009 && recentDaily > (baselineDaily * 1.15) {
            message = "Recent daily spending is running above your recent baseline."
        } else if baselineDaily > 0.009 && recentDaily < (baselineDaily * 0.85) {
            message = "Recent daily spending cooled versus the prior two-week baseline."
        } else {
            message = "Recent spending is holding close to its recent baseline."
        }

        return FinanceSpendingPatternSummary(
            recentDailyAverage: recentDaily,
            baselineDailyAverage: baselineDaily,
            currentPeriodSpend: currentSpend,
            projectedPeriodSpend: projectedSpend,
            acceleratedAfterMidpoint: acceleratedAfterMidpoint,
            message: message
        )
    }

    private func attentionSignals(
        cashflowHealth: FinanceCashflowHealth,
        safeToSpend: FinanceSafeToSpendSummary,
        recurringPressure: FinanceRecurringPressureSummary,
        spendingPattern: FinanceSpendingPatternSummary,
        categoryDrift: [FinanceCategoryDrift],
        unusualRecentSpending: Bool
    ) -> [FinanceAttentionSignal] {
        var signals: [FinanceAttentionSignal] = []

        if cashflowHealth.status == .pressured || cashflowHealth.status == .critical {
            signals.append(
                FinanceAttentionSignal(
                    kind: .cashflow,
                    severity: severity(for: cashflowHealth.status),
                    title: cashflowHealth.headline,
                    message: cashflowHealth.message,
                    metricLabel: "Projected balance",
                    metricValue: cashflowHealth.projectedBalance
                )
            )
        }

        if safeToSpend.status == .pressured || safeToSpend.status == .critical {
            signals.append(
                FinanceAttentionSignal(
                    kind: .safeToSpend,
                    severity: severity(for: safeToSpend.status),
                    title: safeToSpend.headline,
                    message: safeToSpend.message,
                    metricLabel: "Safe to spend",
                    metricValue: safeToSpend.amount
                )
            )
        }

        if recurringPressure.shareOfIncome > 0.3 || (recurringPressure.growthVsPreviousMonth ?? 0) > 0.12 {
            signals.append(
                FinanceAttentionSignal(
                    kind: .recurring,
                    severity: recurringPressure.shareOfIncome > 0.38 ? .warning : .watch,
                    title: recurringPressure.headline,
                    message: recurringPressure.message,
                    metricLabel: "Monthly commitments",
                    metricValue: recurringPressure.monthlyCommitment
                )
            )
        }

        if let leadingCategory = categoryDrift.first,
           leadingCategory.currentAmount > 0.009,
           leadingCategory.deltaAmount > max(leadingCategory.previousAmount * 0.12, 18) || leadingCategory.shareOfSpend > 0.18 {
            signals.append(
                FinanceAttentionSignal(
                    kind: .category,
                    severity: leadingCategory.shareOfSpend > 0.24 ? .warning : .watch,
                    title: "\(leadingCategory.categoryName) is building pressure.",
                    message: leadingCategory.message,
                    metricLabel: "Category spend",
                    metricValue: leadingCategory.currentAmount
                )
            )
        }

        if unusualRecentSpending || spendingPattern.acceleratedAfterMidpoint {
            signals.append(
                FinanceAttentionSignal(
                    kind: .pace,
                    severity: unusualRecentSpending ? .warning : .watch,
                    title: unusualRecentSpending ? "Recent spending is above pattern." : "Spending pace accelerated.",
                    message: spendingPattern.message,
                    metricLabel: "Recent daily spend",
                    metricValue: spendingPattern.recentDailyAverage
                )
            )
        }

        if signals.isEmpty {
            signals.append(
                FinanceAttentionSignal(
                    kind: .balance,
                    severity: .stable,
                    title: "Cashflow is stable right now.",
                    message: "Nothing urgent is standing out across pace, fixed commitments, or category drift."
                )
            )
        }

        return signals
            .sorted { lhs, rhs in
                if severityRank(lhs.severity) != severityRank(rhs.severity) {
                    return severityRank(lhs.severity) > severityRank(rhs.severity)
                }
                return (lhs.metricValue ?? 0) > (rhs.metricValue ?? 0)
            }
            .prefix(4)
            .map { $0 }
    }

    private func severity(for status: FinanceHealthStatus) -> FinanceAttentionSeverity {
        switch status {
        case .resilient:
            return .stable
        case .steady:
            return .watch
        case .pressured:
            return .warning
        case .critical:
            return .critical
        }
    }

    private func severityRank(_ severity: FinanceAttentionSeverity) -> Int {
        switch severity {
        case .stable:
            return 0
        case .watch:
            return 1
        case .warning:
            return 2
        case .critical:
            return 3
        }
    }

    private func shiftedAnchorDate(from anchorDate: String, days: Int, timezoneID: String) -> String {
        guard let anchor = FinanceDateCoding.date(from: anchorDate, timezoneID: timezoneID) else {
            return anchorDate
        }
        let localCalendar = FinanceDateCoding.calendar(timezoneID: timezoneID)
        let shifted = localCalendar.date(byAdding: .day, value: days, to: anchor) ?? anchor
        return FinanceDateCoding.isoDateString(from: shifted, timezoneID: timezoneID)
    }

    private func warnings(
        balanceState: FinanceBalanceState,
        weekSpent: Double,
        weeklyBaseline: Double,
        transactions: [FinanceTransaction],
        currentDateLocal: String,
        weekStart: Int,
        timezoneID: String
    ) -> [FinanceWarning] {
        var results: [FinanceWarning] = []
        if let lowBalanceThreshold = balanceState.lowBalanceThreshold,
           balanceState.totalBalance < lowBalanceThreshold {
            results.append(
                FinanceWarning(
                    kind: .lowBalance,
                    title: "Balance is nearing your floor",
                    message: "Current balance is below the local threshold you set."
                )
            )
        }
        if let weeklyThreshold = balanceState.weeklyPaceThreshold,
           weekSpent > weeklyThreshold {
            results.append(
                FinanceWarning(
                    kind: .weeklyPace,
                    title: "This week is running above your pace cap",
                    message: "Spending for the week is above the threshold saved on this device."
                )
            )
        } else if weeklyBaseline > 0, weekSpent > (weeklyBaseline * 1.15) {
            results.append(
                FinanceWarning(
                    kind: .weeklyPace,
                    title: "This week is moving faster than usual",
                    message: "Spending is above your recent weekly baseline."
                )
            )
        }
        if unusualRecentSpending(
            transactions: transactions,
            currentDateLocal: currentDateLocal,
            timezoneID: timezoneID
        ) {
            results.append(
                FinanceWarning(
                    kind: .unusualSpending,
                    title: "Recent spending is above your recent pattern",
                    message: "The last few days are coming in heavier than your recent baseline."
                )
            )
        }
        return Array(results.prefix(2))
    }

    private func unusualRecentSpending(
        transactions: [FinanceTransaction],
        currentDateLocal: String,
        timezoneID: String
    ) -> Bool {
        let localCalendar = FinanceDateCoding.calendar(timezoneID: timezoneID)
        guard let anchor = FinanceDateCoding.date(from: currentDateLocal, timezoneID: timezoneID),
              let recentStart = localCalendar.date(byAdding: .day, value: -2, to: anchor),
              let baselineStart = localCalendar.date(byAdding: .day, value: -16, to: anchor),
              let baselineEnd = localCalendar.date(byAdding: .day, value: -3, to: anchor) else {
            return false
        }
        let recentSpent = filter(
            transactions: transactions,
            startDate: FinanceDateCoding.isoDateString(from: recentStart, timezoneID: timezoneID),
            endDate: currentDateLocal,
            timezoneID: timezoneID
        ).reduce(0) { $0 + FinanceComputation.expenseAmount(for: $1) }
        let baselineSpent = filter(
            transactions: transactions,
            startDate: FinanceDateCoding.isoDateString(from: baselineStart, timezoneID: timezoneID),
            endDate: FinanceDateCoding.isoDateString(from: baselineEnd, timezoneID: timezoneID),
            timezoneID: timezoneID
        ).reduce(0) { $0 + FinanceComputation.expenseAmount(for: $1) }
        guard baselineSpent > 0 else {
            return false
        }
        let baselineDaily = baselineSpent / 14.0
        return recentSpent > max(baselineDaily * 3.0 * 1.35, 20.0)
    }

    private func balanceComparisons(
        balanceState: FinanceBalanceState,
        manualAdjustmentAt: Date?,
        transactions: [FinanceTransaction],
        weekBounds: (startDate: String, endDate: String),
        monthBounds: (startDate: String, endDate: String),
        timezoneID: String
    ) -> [FinanceBalanceComparison] {
        var comparisons: [FinanceBalanceComparison] = []
        let currentTotal = balanceState.totalBalance
        if shouldShowComparison(startDate: weekBounds.startDate, manualAdjustmentAt: manualAdjustmentAt, timezoneID: timezoneID) {
            let weekNet = filter(transactions: transactions, startDate: weekBounds.startDate, endDate: weekBounds.endDate, timezoneID: timezoneID)
                .reduce(0) { $0 + FinanceComputation.netAmount(for: $1) }
            comparisons.append(FinanceBalanceComparison(label: "Week", delta: weekNet))
        }
        if shouldShowComparison(startDate: monthBounds.startDate, manualAdjustmentAt: manualAdjustmentAt, timezoneID: timezoneID) {
            let monthNet = filter(transactions: transactions, startDate: monthBounds.startDate, endDate: monthBounds.endDate, timezoneID: timezoneID)
                .reduce(0) { $0 + FinanceComputation.netAmount(for: $1) }
            if abs(monthNet) > 0.009 || comparisons.isEmpty || currentTotal != 0 {
                comparisons.append(FinanceBalanceComparison(label: "Month", delta: monthNet))
            }
        }
        return comparisons
    }

    private func shouldShowComparison(startDate: String, manualAdjustmentAt: Date?, timezoneID: String) -> Bool {
        guard let manualAdjustmentAt else {
            return true
        }
        let manualDate = FinanceDateCoding.localDateString(from: manualAdjustmentAt, timezoneID: timezoneID)
        return manualDate <= startDate
    }

    private func suggestedPaymentMethod(from transactions: [FinanceTransaction]) -> FinancePaymentMethod {
        transactions
            .sorted { $0.occurredAt > $1.occurredAt }
            .first(where: { $0.type == .expense && $0.paymentMethod != nil })?
            .paymentMethod ?? .card
    }

    private func chartPoints(
        period: FinanceAnalyticsPeriod,
        transactions: [FinanceTransaction],
        bounds: (startDate: String, endDate: String),
        timezoneID: String
    ) -> [FinanceAmountChartPoint] {
        switch period {
        case .week:
            let dates = FinanceDateCoding.sequenceDates(
                startDate: bounds.startDate,
                endDate: bounds.endDate,
                timezoneID: timezoneID
            )
            let grouped = Dictionary(grouping: transactions) {
                FinanceDateCoding.localDateString(from: $0.occurredAt, timezoneID: timezoneID)
            }
            return dates.map { dateLocal in
                let items = grouped[dateLocal] ?? []
                return FinanceAmountChartPoint(
                    label: FinanceDateCoding.shortWeekday(from: dateLocal, timezoneID: timezoneID),
                    spent: items.reduce(0) { $0 + FinanceComputation.expenseAmount(for: $1) },
                    income: items.reduce(0) { $0 + FinanceComputation.incomeAmount(for: $1) },
                    net: items.reduce(0) { $0 + FinanceComputation.netAmount(for: $1) }
                )
            }
        case .month:
            let grouped = Dictionary(grouping: transactions) {
                FinanceDateCoding.weekOfMonth(
                    from: FinanceDateCoding.localDateString(from: $0.occurredAt, timezoneID: timezoneID),
                    timezoneID: timezoneID
                )
            }
            let allWeeks = Set(grouped.keys).union(Set([1, 2, 3, 4, 5]))
            return allWeeks.sorted().map { week in
                let items = grouped[week] ?? []
                return FinanceAmountChartPoint(
                    label: "W\(week)",
                    spent: items.reduce(0) { $0 + FinanceComputation.expenseAmount(for: $1) },
                    income: items.reduce(0) { $0 + FinanceComputation.incomeAmount(for: $1) },
                    net: items.reduce(0) { $0 + FinanceComputation.netAmount(for: $1) }
                )
            }
        case .year:
            let grouped = Dictionary(grouping: transactions) {
                let localDate = FinanceDateCoding.localDateString(from: $0.occurredAt, timezoneID: timezoneID)
                return Int(localDate.split(separator: "-")[safe: 1] ?? "1") ?? 1
            }
            return (1...12).map { month in
                let items = grouped[month] ?? []
                return FinanceAmountChartPoint(
                    label: FinanceDateCoding.shortMonth(for: month, timezoneID: timezoneID),
                    spent: items.reduce(0) { $0 + FinanceComputation.expenseAmount(for: $1) },
                    income: items.reduce(0) { $0 + FinanceComputation.incomeAmount(for: $1) },
                    net: items.reduce(0) { $0 + FinanceComputation.netAmount(for: $1) }
                )
            }
        }
    }

    private func comparisonPoints(
        period: FinanceAnalyticsPeriod,
        transactions: [FinanceTransaction],
        currentDateLocal: String,
        weekStart: Int,
        timezoneID: String
    ) -> [FinanceComparisonPoint] {
        let localCalendar = FinanceDateCoding.calendar(timezoneID: timezoneID)
        guard let anchor = FinanceDateCoding.date(from: currentDateLocal, timezoneID: timezoneID) else {
            return []
        }
        switch period {
        case .week:
            return (0..<4).compactMap { offset in
                guard let reference = localCalendar.date(byAdding: .day, value: -(7 * offset), to: anchor) else {
                    return nil
                }
                let referenceDate = FinanceDateCoding.isoDateString(from: reference, timezoneID: timezoneID)
                let bounds = FinanceDateCoding.bounds(for: .week, anchorDate: referenceDate, weekStart: weekStart, timezoneID: timezoneID)
                let items = filter(transactions: transactions, startDate: bounds.startDate, endDate: bounds.endDate, timezoneID: timezoneID)
                return FinanceComparisonPoint(
                    label: offset == 0 ? "Current" : "-\(offset)w",
                    spent: items.reduce(0) { $0 + FinanceComputation.expenseAmount(for: $1) },
                    income: items.reduce(0) { $0 + FinanceComputation.incomeAmount(for: $1) },
                    net: items.reduce(0) { $0 + FinanceComputation.netAmount(for: $1) }
                )
            }.reversed()
        case .month:
            return (0..<4).compactMap { offset in
                guard let reference = localCalendar.date(byAdding: .month, value: -offset, to: anchor) else {
                    return nil
                }
                let referenceDate = FinanceDateCoding.isoDateString(from: reference, timezoneID: timezoneID)
                let bounds = FinanceDateCoding.bounds(for: .month, anchorDate: referenceDate, weekStart: weekStart, timezoneID: timezoneID)
                let items = filter(transactions: transactions, startDate: bounds.startDate, endDate: bounds.endDate, timezoneID: timezoneID)
                let month = localCalendar.component(.month, from: reference)
                return FinanceComparisonPoint(
                    label: offset == 0 ? "Current" : FinanceDateCoding.shortMonth(for: month, timezoneID: timezoneID),
                    spent: items.reduce(0) { $0 + FinanceComputation.expenseAmount(for: $1) },
                    income: items.reduce(0) { $0 + FinanceComputation.incomeAmount(for: $1) },
                    net: items.reduce(0) { $0 + FinanceComputation.netAmount(for: $1) }
                )
            }.reversed()
        case .year:
            let yearBounds = FinanceDateCoding.bounds(for: .year, anchorDate: currentDateLocal, weekStart: weekStart, timezoneID: timezoneID)
            let yearTransactions = filter(transactions: transactions, startDate: yearBounds.startDate, endDate: yearBounds.endDate, timezoneID: timezoneID)
            let grouped = Dictionary(grouping: yearTransactions) {
                let localDate = FinanceDateCoding.localDateString(from: $0.occurredAt, timezoneID: timezoneID)
                return Int(localDate.split(separator: "-")[safe: 1] ?? "1") ?? 1
            }
            return (1...12).map { month in
                let items = grouped[month] ?? []
                return FinanceComparisonPoint(
                    label: FinanceDateCoding.shortMonth(for: month, timezoneID: timezoneID),
                    spent: items.reduce(0) { $0 + FinanceComputation.expenseAmount(for: $1) },
                    income: items.reduce(0) { $0 + FinanceComputation.incomeAmount(for: $1) },
                    net: items.reduce(0) { $0 + FinanceComputation.netAmount(for: $1) }
                )
            }
        }
    }

    private func insightMessage(
        period: FinanceAnalyticsPeriod,
        totalSpent: Double,
        totalIncome: Double,
        comparisonPoints: [FinanceComparisonPoint]
    ) -> String {
        if totalSpent == 0 && totalIncome == 0 {
            return "This \(period.title.lowercased()) has no finance activity recorded yet."
        }
        let priorPoint = comparisonPoints.dropLast().last
        if let priorPoint, priorPoint.spent > 0 {
            let ratio = totalSpent / priorPoint.spent
            if ratio > 1.15 {
                return "Spending is higher than the previous \(period.title.lowercased()) reference."
            }
            if ratio < 0.9 {
                return "Spending is lighter than the previous \(period.title.lowercased()) reference."
            }
        }
        if totalIncome > totalSpent {
            return "Income is covering spending in this \(period.title.lowercased()) range."
        }
        return "Spending is the main movement in this \(period.title.lowercased()) range."
    }
}
