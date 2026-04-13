import Foundation

struct TodayIntelligenceEngine {
    func buildItems(
        user: User,
        targetDate: String,
        categories: [Category],
        habits: [Habit],
        todos: [Todo],
        completionLogs: [CompletionLog],
        overrides: [TodayOrderOverrideRecord]
    ) -> [TodayItem] {
        let categoriesByID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
        let currentContextDate = contextDate(for: targetDate, timezoneID: user.timezone)
        let currentBucket = TodayTimeBucket.bucket(for: currentContextDate)
        let habitLogs = Dictionary(
            uniqueKeysWithValues: completionLogs
                .filter { $0.itemType == .habit && $0.dateLocal == targetDate }
                .map { ($0.itemId, $0) }
        )
        let currentOverrideLookup = overrides
            .filter { $0.dateLocal == targetDate }
            .reduce(into: [String: Int]()) { partial, override in
                let key = "\(override.itemType.rawValue):\(override.itemId)"
                partial[key] = min(partial[key] ?? override.orderIndex, override.orderIndex)
            }
        let todoLookup = Dictionary(uniqueKeysWithValues: todos.map { ($0.id, $0) })

        let relevantTodos = todos.filter {
            $0.userId == user.id && (
                $0.status == .open ||
                ($0.status == .completed && todoActionDate(for: $0, timezoneID: user.timezone) == targetDate)
            )
        }
        let scheduledHabits = habits.filter { $0.userId == user.id && LocalTodayService().isHabitScheduled($0, on: targetDate) }

        var drafts: [TodayItemDraft] = []

        for todo in relevantTodos {
            let categoryName = categoriesByID[todo.categoryId] ?? ""
            let signature = normalizedTitleSignature(todo.title)
            let fallback = defaultTimeSignal(
                itemType: .todo,
                title: todo.title,
                notes: todo.notes,
                categoryName: categoryName,
                dueAt: todo.dueAt,
                preferredTime: nil,
                timezoneID: user.timezone
            )
            let history = todoHistorySignal(
                todo: todo,
                todos: todos,
                timezoneID: user.timezone,
                fallback: fallback
            )
            let manual = manualBoost(
                itemType: .todo,
                itemID: todo.id,
                signature: signature,
                categoryID: todo.categoryId,
                targetDate: targetDate,
                isPinned: todo.isPinned,
                currentOverrideLookup: currentOverrideLookup,
                overrides: overrides,
                todoLookup: todoLookup
            )
            let due = todoDueSignal(todo, targetDate: targetDate, timezoneID: user.timezone)
            let priorityValue = todo.isPinned ? 1.0 : Double(todo.priority) / 100.0
            let effort = effortBand(title: todo.title, notes: todo.notes)
            let timeMatch = timeMatchScore(currentBucket: currentBucket, targetBucket: history.timeBucket, confidence: history.timeConfidence)
            let weekdayMatch = weekdayMatchScore(
                targetDate: targetDate,
                preferredWeekdays: history.preferredWeekdays,
                confidence: history.weekdayConfidence
            )
            let contextFit = effortContextScore(
                itemType: .todo,
                effortBand: effort,
                currentBucket: currentBucket,
                categoryName: categoryName,
                title: todo.title,
                notes: todo.notes
            )
            let freshness = recentTodoBoost(todo, targetDate: targetDate, timezoneID: user.timezone, referenceDate: currentContextDate)
            let blendedScore = (priorityValue * 0.24) +
                (due.pressure * 0.36) +
                timeMatch +
                weekdayMatch +
                (history.routineStrength * 0.06) +
                contextFit +
                freshness +
                manual.boost
            let surfaceZone = zone(
                itemType: .todo,
                completed: todo.status == .completed,
                priorityValue: priorityValue,
                isPinned: todo.isPinned,
                history: history,
                manualBoost: manual.boost
            )
            let item = TodayItem(
                itemType: .todo,
                itemId: todo.id,
                title: todo.title,
                categoryId: todo.categoryId,
                completed: todo.status == .completed,
                sortBucket: zoneRank(surfaceZone) * 10 + urgencySortBonus(due.urgency),
                sortScore: blendedScore,
                subtitle: supportingLine(
                    itemType: .todo,
                    completed: todo.status == .completed,
                    surfaceZone: surfaceZone,
                    urgency: due.urgency,
                    manualBoost: manual.boost,
                    isPinned: todo.isPinned,
                    history: history,
                    categoryName: categoryName,
                    notes: todo.notes,
                    recurrenceRule: nil,
                    effortBand: effort
                ),
                isPinned: todo.isPinned,
                priority: todo.priority,
                dueAt: todo.dueAt,
                blendedScore: blendedScore,
                prominence: prominence(
                    surfaceZone: .flow,
                    flowRank: 0,
                    flowCount: 1,
                    topFlowScore: blendedScore,
                    blendedScore: blendedScore,
                    urgency: due.urgency,
                    currentOverrideIndex: manual.currentOverrideIndex,
                    priorityValue: priorityValue,
                    manualBoost: manual.boost
                ),
                surfaceZone: surfaceZone,
                urgency: due.urgency,
                timeBucket: history.timeBucket,
                clusterKey: "todo:\(todo.categoryId):\(signature)",
                learningConfidence: max(history.timeConfidence, history.weekdayConfidence),
                manualBoost: manual.boost
            )
            drafts.append(
                TodayItemDraft(
                    item: item,
                    currentOverrideIndex: manual.currentOverrideIndex,
                    recencyKey: todo.createdAt.timeIntervalSince1970,
                    titleKey: todo.title.lowercased(),
                    duePressure: due.pressure,
                    manualBoost: manual.boost,
                    priorityValue: priorityValue,
                    zoneRank: zoneRank(surfaceZone)
                )
            )
        }

        for habit in scheduledHabits {
            let categoryName = categoriesByID[habit.categoryId] ?? ""
            let signature = normalizedTitleSignature(habit.title)
            let fallback = defaultTimeSignal(
                itemType: .habit,
                title: habit.title,
                notes: habit.notes,
                categoryName: categoryName,
                dueAt: nil,
                preferredTime: habit.preferredTime,
                timezoneID: user.timezone
            )
            let history = habitHistorySignal(
                habit: habit,
                completionLogs: completionLogs,
                timezoneID: user.timezone,
                fallback: fallback
            )
            let manual = manualBoost(
                itemType: .habit,
                itemID: habit.id,
                signature: signature,
                categoryID: habit.categoryId,
                targetDate: targetDate,
                isPinned: false,
                currentOverrideLookup: currentOverrideLookup,
                overrides: overrides,
                todoLookup: todoLookup
            )
            let priorityValue = Double(habit.priorityWeight) / 100.0
            let duePressure = habitDuePressure(
                currentBucket: currentBucket,
                targetBucket: history.timeBucket,
                confidence: history.timeConfidence
            )
            let isCompleted = habitLogs[habit.id]?.state == .completed
            let urgency: TodayUrgency = duePressure >= 0.18 && !isCompleted ? .soon : .none
            let effort = effortBand(title: habit.title, notes: habit.notes)
            let contextFit = effortContextScore(
                itemType: .habit,
                effortBand: effort,
                currentBucket: currentBucket,
                categoryName: categoryName,
                title: habit.title,
                notes: habit.notes
            )
            let blendedScore = (priorityValue * 0.34) +
                (duePressure * 0.22) +
                timeMatchScore(currentBucket: currentBucket, targetBucket: history.timeBucket, confidence: history.timeConfidence) +
                weekdayMatchScore(targetDate: targetDate, preferredWeekdays: history.preferredWeekdays, confidence: history.weekdayConfidence) +
                (history.routineStrength * 0.14) +
                contextFit +
                manual.boost
            let surfaceZone = zone(
                itemType: .habit,
                completed: isCompleted,
                priorityValue: priorityValue,
                isPinned: false,
                history: history,
                manualBoost: manual.boost
            )
            let item = TodayItem(
                itemType: .habit,
                itemId: habit.id,
                title: habit.title,
                categoryId: habit.categoryId,
                completed: isCompleted,
                sortBucket: zoneRank(surfaceZone) * 10 + urgencySortBonus(urgency),
                sortScore: blendedScore,
                subtitle: supportingLine(
                    itemType: .habit,
                    completed: isCompleted,
                    surfaceZone: surfaceZone,
                    urgency: urgency,
                    manualBoost: manual.boost,
                    isPinned: false,
                    history: history,
                    categoryName: categoryName,
                    notes: habit.notes,
                    recurrenceRule: habit.recurrenceRule,
                    effortBand: effort
                ),
                isPinned: false,
                priority: habit.priorityWeight,
                preferredTime: habit.preferredTime,
                blendedScore: blendedScore,
                prominence: prominence(
                    surfaceZone: .flow,
                    flowRank: 0,
                    flowCount: 1,
                    topFlowScore: blendedScore,
                    blendedScore: blendedScore,
                    urgency: urgency,
                    currentOverrideIndex: manual.currentOverrideIndex,
                    priorityValue: priorityValue,
                    manualBoost: manual.boost
                ),
                surfaceZone: surfaceZone,
                urgency: urgency,
                timeBucket: history.timeBucket,
                clusterKey: "habit:\(habit.categoryId):\(signature)",
                learningConfidence: max(history.timeConfidence, history.weekdayConfidence),
                manualBoost: manual.boost
            )
            drafts.append(
                TodayItemDraft(
                    item: item,
                    currentOverrideIndex: manual.currentOverrideIndex,
                    recencyKey: 0,
                    titleKey: habit.title.lowercased(),
                    duePressure: duePressure,
                    manualBoost: manual.boost,
                    priorityValue: priorityValue,
                    zoneRank: zoneRank(surfaceZone)
                )
            )
        }

        let sortedDrafts = drafts.sorted { lhs, rhs in
            if lhs.zoneRank != rhs.zoneRank {
                return lhs.zoneRank < rhs.zoneRank
            }
            switch (lhs.currentOverrideIndex, rhs.currentOverrideIndex) {
            case let (left?, right?):
                if left != right {
                    return left < right
                }
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            case (nil, nil):
                break
            }
            if lhs.item.sortBucket != rhs.item.sortBucket {
                return lhs.item.sortBucket < rhs.item.sortBucket
            }
            if lhs.item.blendedScore != rhs.item.blendedScore {
                return lhs.item.blendedScore > rhs.item.blendedScore
            }
            if lhs.manualBoost != rhs.manualBoost {
                return lhs.manualBoost > rhs.manualBoost
            }
            if lhs.duePressure != rhs.duePressure {
                return lhs.duePressure > rhs.duePressure
            }
            if lhs.priorityValue != rhs.priorityValue {
                return lhs.priorityValue > rhs.priorityValue
            }
            if lhs.recencyKey != rhs.recencyKey {
                return lhs.recencyKey > rhs.recencyKey
            }
            return lhs.titleKey < rhs.titleKey
        }
        let flowDrafts = sortedDrafts.filter { $0.item.surfaceZone == .flow }
        let topFlowScore = flowDrafts.first?.item.blendedScore ?? 0
        let flowCount = flowDrafts.count
        var currentFlowRank = 0

        return sortedDrafts.map { draft in
            let resolvedProminence: TodayProminence
            if draft.item.surfaceZone == .flow {
                resolvedProminence = prominence(
                    surfaceZone: draft.item.surfaceZone,
                    flowRank: currentFlowRank,
                    flowCount: flowCount,
                    topFlowScore: topFlowScore,
                    blendedScore: draft.item.blendedScore,
                    urgency: draft.item.urgency,
                    currentOverrideIndex: draft.currentOverrideIndex,
                    priorityValue: draft.priorityValue,
                    manualBoost: draft.manualBoost
                )
                currentFlowRank += 1
            } else {
                resolvedProminence = .compact
            }

            return TodayItem(
                itemType: draft.item.itemType,
                itemId: draft.item.itemId,
                title: draft.item.title,
                categoryId: draft.item.categoryId,
                completed: draft.item.completed,
                sortBucket: draft.item.sortBucket,
                sortScore: draft.item.sortScore,
                subtitle: draft.item.subtitle,
                isPinned: draft.item.isPinned,
                priority: draft.item.priority,
                dueAt: draft.item.dueAt,
                preferredTime: draft.item.preferredTime,
                blendedScore: draft.item.blendedScore,
                prominence: resolvedProminence,
                surfaceZone: draft.item.surfaceZone,
                urgency: draft.item.urgency,
                timeBucket: draft.item.timeBucket,
                clusterKey: draft.item.clusterKey,
                learningConfidence: draft.item.learningConfidence,
                manualBoost: draft.item.manualBoost
            )
        }
    }
}

private struct TodayHistorySignal {
    let timeBucket: TodayTimeBucket
    let timeConfidence: Double
    let preferredWeekdays: Set<Int>
    let weekdayConfidence: Double
    let routineStrength: Double
    let observationCount: Int
}

private struct TodayManualSignal {
    let boost: Double
    let currentOverrideIndex: Int?
}

private struct TodayDueSignal {
    let pressure: Double
    let urgency: TodayUrgency
}

private struct TodayItemDraft {
    let item: TodayItem
    let currentOverrideIndex: Int?
    let recencyKey: Double
    let titleKey: String
    let duePressure: Double
    let manualBoost: Double
    let priorityValue: Double
    let zoneRank: Int
}

private extension TodayTimeBucket {
    static func bucket(for date: Date) -> TodayTimeBucket {
        let components = Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: date)
        let minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        return bucket(forMinutes: minutes)
    }

    static func bucket(forMinutes minutes: Int?) -> TodayTimeBucket {
        guard let minutes else {
            return .anytime
        }
        switch minutes {
        case ..<660:
            return .morning
        case ..<960:
            return .midday
        case ..<1320:
            return .evening
        default:
            return .late
        }
    }

    var phrase: String {
        switch self {
        case .anytime:
            return "anytime"
        case .morning:
            return "mornings"
        case .midday:
            return "midday"
        case .evening:
            return "evenings"
        case .late:
            return "late"
        }
    }
}

private func contextDate(for targetDate: String, timezoneID: String) -> Date {
    let now = Date()
    if OfflineDateCoding.localDateString(from: now, timezoneID: timezoneID) == targetDate {
        return now
    }
    guard let target = OfflineDateCoding.date(from: targetDate) else {
        return now
    }
    return OfflineDateCoding.canonicalCalendar.date(bySettingHour: 13, minute: 0, second: 0, of: target) ?? target
}

private func normalizedTitleSignature(_ title: String) -> String {
    let stopwords: Set<String> = ["a", "an", "and", "for", "from", "in", "of", "on", "the", "to", "with"]
    let tokens = title
        .lowercased()
        .components(separatedBy: CharacterSet.alphanumerics.inverted)
        .filter { !$0.isEmpty && !stopwords.contains($0) }
    if tokens.isEmpty {
        return "untitled"
    }
    return tokens.prefix(4).joined(separator: "-")
}

private func effortBand(title: String, notes: String) -> String {
    let quick: Set<String> = ["call", "email", "pay", "plan", "reply", "review", "send", "stretch", "tidy", "water"]
    let deep: Set<String> = ["assignment", "build", "clean", "deep", "design", "essay", "gym", "project", "study", "train", "workout", "write"]
    let tokens = Set(
        "\(title) \(notes)"
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    )
    if !tokens.intersection(deep).isEmpty {
        return "deep"
    }
    if !tokens.intersection(quick).isEmpty {
        return "quick"
    }
    return "steady"
}

private func defaultTimeSignal(
    itemType: ItemType,
    title: String,
    notes: String,
    categoryName: String,
    dueAt: Date?,
    preferredTime: String?,
    timezoneID: String
) -> (bucket: TodayTimeBucket, confidence: Double) {
    if let preferredTime,
       let minutes = OfflineDateCoding.minutesFromClock(preferredTime) {
        return (TodayTimeBucket.bucket(forMinutes: minutes), 0.76)
    }
    if let dueAt {
        let parts = OfflineDateCoding.localTimeString(from: dueAt, timezoneID: timezoneID).split(separator: ":")
        if parts.count >= 2,
           let hour = Int(parts[0]),
           let minute = Int(parts[1]) {
            return (TodayTimeBucket.bucket(forMinutes: hour * 60 + minute), 0.58)
        }
    }

    let text = "\(categoryName) \(title) \(notes)".lowercased()
    if ["workout", "gym", "pray", "journal", "run", "school", "study"].contains(where: text.contains) {
        return (.morning, 0.24)
    }
    if ["admin", "call", "email", "meeting", "pay", "reply", "send"].contains(where: text.contains) {
        return (.midday, 0.24)
    }
    if ["clean", "plan", "read", "review", "reset", "tidy"].contains(where: text.contains) {
        return (.evening, 0.24)
    }
    return itemType == .habit ? (.morning, 0.18) : (.anytime, 0.14)
}

private func todoHistorySignal(
    todo: Todo,
    todos: [Todo],
    timezoneID: String,
    fallback: (bucket: TodayTimeBucket, confidence: Double)
) -> TodayHistorySignal {
    let signature = normalizedTitleSignature(todo.title)
    let times = todos.compactMap { candidate -> Date? in
        guard candidate.status == .completed,
              candidate.categoryId == todo.categoryId,
              normalizedTitleSignature(candidate.title) == signature else {
            return nil
        }
        return candidate.completedAt
    }
    return historySignal(times: times, timezoneID: timezoneID, fallback: fallback)
}

private func habitHistorySignal(
    habit: Habit,
    completionLogs: [CompletionLog],
    timezoneID: String,
    fallback: (bucket: TodayTimeBucket, confidence: Double)
) -> TodayHistorySignal {
    let times = completionLogs.compactMap { log -> Date? in
        guard log.itemType == .habit,
              log.itemId == habit.id,
              log.state == .completed else {
            return nil
        }
        return log.completedAt
    }
    return historySignal(times: times, timezoneID: timezoneID, fallback: fallback)
}

private func historySignal(
    times: [Date?],
    timezoneID: String,
    fallback: (bucket: TodayTimeBucket, confidence: Double)
) -> TodayHistorySignal {
    let realizedTimes = times.compactMap { $0 }
    guard !realizedTimes.isEmpty else {
        return TodayHistorySignal(
            timeBucket: fallback.bucket,
            timeConfidence: fallback.confidence,
            preferredWeekdays: [],
            weekdayConfidence: 0,
            routineStrength: 0,
            observationCount: 0
        )
    }

    var bucketCounts: [TodayTimeBucket: Int] = [:]
    var weekdayCounts: [Int: Int] = [:]
    for time in realizedTimes {
        let local = Calendar.autoupdatingCurrent.dateComponents([.hour, .minute, .weekday], from: time)
        let minutes = (local.hour ?? 0) * 60 + (local.minute ?? 0)
        bucketCounts[TodayTimeBucket.bucket(forMinutes: minutes), default: 0] += 1
        weekdayCounts[(local.weekday ?? 1) - 1, default: 0] += 1
    }

    let dominantBucket = bucketCounts.max(by: { $0.value < $1.value })?.key ?? fallback.bucket
    let dominantBucketCount = bucketCounts[dominantBucket] ?? 0
    let dominantWeekdayCount = weekdayCounts.values.max() ?? 0
    let dominantBucketShare = Double(dominantBucketCount) / Double(realizedTimes.count)
    let preferredWeekdays = Set(
        weekdayCounts.compactMap { weekday, count in
            realizedTimes.count >= 5 && count >= 2 && Double(count) / Double(realizedTimes.count) >= 0.4 ? weekday : nil
        }
    )
    return TodayHistorySignal(
        timeBucket: realizedTimes.count >= 5 && dominantBucketShare >= 0.45 ? dominantBucket : fallback.bucket,
        timeConfidence: max(
            fallback.confidence,
            dominantBucketShare * min(1, Double(realizedTimes.count) / 7)
        ),
        preferredWeekdays: preferredWeekdays,
        weekdayConfidence: realizedTimes.count >= 5 ? (Double(dominantWeekdayCount) / Double(realizedTimes.count)) * min(1, Double(realizedTimes.count) / 7) : 0,
        routineStrength: min(1, Double(realizedTimes.count) / 10),
        observationCount: realizedTimes.count
    )
}

private func manualBoost(
    itemType: ItemType,
    itemID: String,
    signature: String,
    categoryID: String,
    targetDate: String,
    isPinned: Bool,
    currentOverrideLookup: [String: Int],
    overrides: [TodayOrderOverrideRecord],
    todoLookup: [String: Todo]
) -> TodayManualSignal {
    let key = "\(itemType.rawValue):\(itemID)"
    let currentOverrideIndex = currentOverrideLookup[key]
    var boost = 0.0
    if let currentOverrideIndex {
        switch currentOverrideIndex {
        case 0:
            boost += 0.24
        case ...2:
            boost += 0.15
        default:
            boost += 0.06
        }
    }
    if isPinned {
        boost += 0.14
    }

    var historyCount = 0
    for override in overrides where override.dateLocal < targetDate && override.orderIndex <= 2 && override.itemType == itemType {
        if itemType == .habit {
            if override.itemId == itemID {
                historyCount += 1
            }
            continue
        }
        guard let candidate = todoLookup[override.itemId] else {
            continue
        }
        if candidate.categoryId == categoryID && normalizedTitleSignature(candidate.title) == signature {
            historyCount += 1
        }
    }
    if historyCount >= 2 {
        boost += min(0.14, 0.04 + Double(historyCount - 2) * 0.025)
    }
    return TodayManualSignal(boost: boost, currentOverrideIndex: currentOverrideIndex)
}

private func todoDueSignal(_ todo: Todo, targetDate: String, timezoneID: String) -> TodayDueSignal {
    guard let dueAt = todo.dueAt,
          let target = OfflineDateCoding.date(from: targetDate),
          let dueDate = OfflineDateCoding.date(from: OfflineDateCoding.localDateString(from: dueAt, timezoneID: timezoneID)) else {
        return TodayDueSignal(pressure: 0, urgency: .none)
    }
    let delta = OfflineDateCoding.canonicalCalendar.dateComponents([.day], from: target, to: dueDate).day ?? 0
    if delta < 0 {
        return TodayDueSignal(pressure: min(1, 0.9 + Double(abs(delta)) * 0.06), urgency: .overdue)
    }
    if delta == 0 {
        return TodayDueSignal(pressure: 0.82, urgency: .dueToday)
    }
    if delta == 1 {
        return TodayDueSignal(pressure: 0.42, urgency: .soon)
    }
    if delta <= 3 {
        return TodayDueSignal(pressure: max(0.16, 0.28 - Double(delta) * 0.03), urgency: .soon)
    }
    return TodayDueSignal(pressure: 0, urgency: .none)
}

private func habitDuePressure(currentBucket: TodayTimeBucket, targetBucket: TodayTimeBucket, confidence: Double) -> Double {
    guard targetBucket != .anytime else {
        return 0
    }
    if currentBucket == targetBucket {
        return 0.1 * confidence
    }
    let order: [TodayTimeBucket: Int] = [.morning: 0, .midday: 1, .evening: 2, .late: 3, .anytime: 1]
    let currentOrder = order[currentBucket] ?? 1
    let targetOrder = order[targetBucket] ?? 1
    if currentOrder > targetOrder {
        return min(0.32, (0.14 + Double(currentOrder - targetOrder) * 0.07) * confidence)
    }
    return max(0, (0.05 - Double(targetOrder - currentOrder) * 0.02) * confidence)
}

private func timeMatchScore(currentBucket: TodayTimeBucket, targetBucket: TodayTimeBucket, confidence: Double) -> Double {
    guard targetBucket != .anytime else {
        return 0.03 * confidence
    }
    return max(0, (0.15 - bucketDistance(currentBucket, targetBucket) * 0.1) * confidence)
}

private func weekdayMatchScore(targetDate: String, preferredWeekdays: Set<Int>, confidence: Double) -> Double {
    guard let date = OfflineDateCoding.date(from: targetDate), !preferredWeekdays.isEmpty else {
        return 0
    }
    let weekday = (OfflineDateCoding.canonicalCalendar.component(.weekday, from: date) + 5) % 7
    return preferredWeekdays.contains(weekday) ? 0.07 * confidence : 0
}

private func bucketDistance(_ lhs: TodayTimeBucket, _ rhs: TodayTimeBucket) -> Double {
    let order: [TodayTimeBucket: Double] = [.morning: 0, .midday: 1, .evening: 2, .late: 3, .anytime: 1.5]
    return abs((order[lhs] ?? 1.5) - (order[rhs] ?? 1.5)) / 3
}

private func zone(
    itemType: ItemType,
    completed: Bool,
    priorityValue: Double,
    isPinned: Bool,
    history: TodayHistorySignal,
    manualBoost: Double
) -> TodaySurfaceZone {
    guard completed else {
        return .flow
    }
    let keepQuiet = (
        itemType == .habit &&
        (priorityValue >= 0.62 || history.routineStrength >= 0.5 || history.timeConfidence >= 0.6)
    ) || isPinned || manualBoost >= 0.18
    return keepQuiet ? .quiet : .hidden
}

private func prominence(
    surfaceZone: TodaySurfaceZone,
    flowRank: Int,
    flowCount: Int,
    topFlowScore: Double,
    blendedScore: Double,
    urgency: TodayUrgency,
    currentOverrideIndex: Int?,
    priorityValue: Double,
    manualBoost: Double
) -> TodayProminence {
    guard surfaceZone == .flow else {
        return .compact
    }
    if flowRank == 0 {
        return .featured
    }
    if flowRank == 1 &&
        flowCount >= 7 &&
        (
            urgency != .none ||
            currentOverrideIndex == 0 ||
            manualBoost >= 0.16 ||
            priorityValue >= 0.8 ||
            blendedScore >= topFlowScore * 0.88
        ) {
        return .featured
    }
    if flowCount >= 8 &&
        flowRank >= flowCount - 2 &&
        urgency == .none &&
        priorityValue < 0.45 &&
        manualBoost < 0.1 &&
        blendedScore < max(0.42, topFlowScore * 0.52) {
        return .compact
    }
    return .standard
}

private func supportingLine(
    itemType: ItemType,
    completed: Bool,
    surfaceZone: TodaySurfaceZone,
    urgency: TodayUrgency,
    manualBoost: Double,
    isPinned: Bool,
    history: TodayHistorySignal,
    categoryName: String,
    notes: String,
    recurrenceRule: String?,
    effortBand: String
) -> String {
    if completed {
        return surfaceZone == .quiet ? "Done, still visible" : "Completed"
    }
    switch urgency {
    case .overdue:
        return "Recovery first"
    case .dueToday:
        return "Needs attention"
    case .soon:
        return "Coming into view"
    default:
        break
    }
    if manualBoost >= 0.22 {
        return "Do first"
    }
    if isPinned {
        return "Pinned focus"
    }
    if history.observationCount >= 5 && history.weekdayConfidence >= 0.62 {
        return "Usual for today"
    }
    if history.observationCount >= 5 && history.routineStrength >= 0.55 {
        return itemType == .habit ? "Stable routine" : "Fits your rhythm"
    }
    if itemType == .habit {
        let rule = (recurrenceRule ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if rule.isEmpty || rule == "DAILY" {
            return "Daily anchor"
        }
        if rule.hasPrefix("WEEKLY:") {
            return "Weekly anchor"
        }
        return "Keeps the rhythm"
    }
    if !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return "Context ready"
    }
    switch effortBand {
    case "quick":
        return "Quick clear"
    case "deep":
        return "Longer block"
    default:
        return categoryName.isEmpty ? "Ready to move" : categoryName
    }
}

private func zoneRank(_ zone: TodaySurfaceZone) -> Int {
    switch zone {
    case .flow:
        return 0
    case .quiet:
        return 1
    case .hidden:
        return 2
    }
}

private func urgencySortBonus(_ urgency: TodayUrgency) -> Int {
    switch urgency {
    case .overdue:
        return 0
    case .dueToday:
        return 1
    case .soon:
        return 2
    default:
        return 3
    }
}

private func recentTodoBoost(_ todo: Todo, targetDate: String, timezoneID: String, referenceDate: Date) -> Double {
    let createdLocalDate = OfflineDateCoding.localDateString(from: todo.createdAt, timezoneID: timezoneID)
    guard let created = OfflineDateCoding.date(from: createdLocalDate),
          let target = OfflineDateCoding.date(from: targetDate) else {
        return 0
    }
    let dayGap = OfflineDateCoding.canonicalCalendar.dateComponents([.day], from: created, to: target).day ?? 0
    if dayGap < 0 {
        return 0
    }
    if dayGap == 0 {
        let ageHours = max(0, referenceDate.timeIntervalSince(todo.createdAt) / 3600)
        return ageHours <= 18 ? 0.04 : 0.025
    }
    if dayGap == 1 {
        return 0.015
    }
    return 0
}

private func effortContextScore(
    itemType: ItemType,
    effortBand: String,
    currentBucket: TodayTimeBucket,
    categoryName: String,
    title: String,
    notes: String
) -> Double {
    let text = "\(categoryName) \(title) \(notes)".lowercased()
    if ["admin", "call", "email", "meeting", "pay", "reply", "send"].contains(where: text.contains) {
        return (currentBucket == .midday || currentBucket == .evening) ? 0.03 : 0
    }
    if ["gym", "journal", "pray", "run", "study", "workout", "write"].contains(where: text.contains) {
        return (currentBucket == .morning || currentBucket == .midday) ? 0.04 : 0
    }
    if itemType == .habit && ["clean", "reset", "tidy"].contains(where: text.contains) {
        return (currentBucket == .evening || currentBucket == .late) ? 0.03 : 0
    }
    switch effortBand {
    case "deep":
        return (currentBucket == .morning || currentBucket == .midday) ? 0.04 : 0
    case "quick":
        return (currentBucket == .midday || currentBucket == .evening) ? 0.02 : 0
    default:
        return 0
    }
}

private func todoActionDate(for todo: Todo, timezoneID: String) -> String {
    if let dueAt = todo.dueAt {
        return OfflineDateCoding.localDateString(from: dueAt, timezoneID: timezoneID)
    }
    return OfflineDateCoding.localDateString(from: todo.createdAt, timezoneID: timezoneID)
}
