import SwiftUI

private enum TodayItemDestination: Hashable {
    case habit(String)
    case todo(String)
    case none
}

private struct TodayItemDestinationContent: View {
    let destination: TodayItemDestination
    @ObservedObject var tasksViewModel: TasksViewModel
    let anchorDate: String
    let onRefreshTasksContext: () async -> Void

    var body: some View {
        switch destination {
        case .habit(let habitID):
            HabitDetailView(
                habitId: habitID,
                tasksViewModel: tasksViewModel,
                anchorDate: anchorDate,
                onSave: {
                    await onRefreshTasksContext()
                }
            )
        case .todo(let todoID):
            TodoDetailView(
                todoId: todoID,
                tasksViewModel: tasksViewModel,
                onSave: {
                    await onRefreshTasksContext()
                }
            )
        case .none:
            EmptyView()
        }
    }
}

struct TodayOperationalSurfaceView: View {
    @ObservedObject var todayViewModel: TodayViewModel
    @ObservedObject var tasksViewModel: TasksViewModel
    let currentDateLocal: String
    let onOpenSheet: (OneAppShell.SheetRoute) -> Void
    let onOpenReview: (String) -> Void
    let onRefreshTasksContext: () async -> Void
    let onRefreshAnalytics: () async -> Void

    @State private var expandedItemID: String?
    @State private var busyItemIDs: Set<String> = []
    @State private var showsReorderSheet = false
    @Environment(\.colorScheme) private var colorScheme

    private var appPalette: OneTheme.Palette {
        OneTheme.palette(for: colorScheme)
    }

    private var sheetPalette: OneTheme.Palette { appPalette }

    private var palette: TodaySurfacePalette {
        TodaySurfacePalette(colorScheme: colorScheme)
    }

    private var dateLocal: String {
        todayViewModel.dateLocal.isEmpty ? currentDateLocal : todayViewModel.dateLocal
    }

    private var activeItems: [TodayItem] {
        todayViewModel.items.filter { !$0.completed && $0.surfaceZone == .flow }
    }

    private var quietCompletedItems: [TodayItem] {
        todayViewModel.items.filter { $0.completed && $0.surfaceZone == .quiet }
    }

    private var activeItemsByID: [String: TodayItem] {
        Dictionary(uniqueKeysWithValues: activeItems.map { ($0.id, $0) })
    }

    private var categoriesByID: [String: Category] {
        Dictionary(uniqueKeysWithValues: tasksViewModel.categories.map { ($0.id, $0) })
    }

    private var habitNotesByID: [String: String] {
        Dictionary(
            uniqueKeysWithValues: tasksViewModel.habits.map {
                ($0.id, trimmedNotes($0.notes))
            }
        )
    }

    private var todoNotesByID: [String: String] {
        Dictionary(
            uniqueKeysWithValues: tasksViewModel.todos.map {
                ($0.id, trimmedNotes($0.notes))
            }
        )
    }

    private var hiddenCompletedCount: Int {
        max(todayViewModel.completedCount - quietCompletedItems.count, 0)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OneScreenBackground(palette: appPalette)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        TodaySurfaceHeader(
                            palette: palette,
                            dateTitle: OneDate.longDate(from: dateLocal),
                            activeCount: activeItems.count,
                            completedCount: todayViewModel.completedCount,
                            completionRatio: todayViewModel.completionRatio,
                            nextTitle: activeItems.first?.title
                        )

                        if todayViewModel.items.isEmpty {
                            TodayInfoCard(
                                palette: palette,
                                title: "Nothing is planned for today",
                                message: "Add a habit or task to start shaping the day."
                            )
                        } else if activeItems.isEmpty {
                            TodayInfoCard(
                                palette: palette,
                                title: "Operational flow is clear",
                                message: "Completed work has moved out of the way. Review the quieter anchors below or leave the rest settled."
                            )
                        } else {
                            TodayMosaicBoard(
                                palette: palette,
                                itemOrder: activeItems.map(\.id),
                                itemsByID: activeItemsByID,
                                expandedItemID: expandedItemID,
                                isBusy: isBusy(_:),
                                categoryIcon: categoryIcon(for:),
                                notePreview: notePreview(for:),
                                detailDestination: detailDestination(for:),
                                onExpandToggle: toggleExpanded(_:),
                                onComplete: toggleItem(_:),
                                onDoFirst: moveToFront(_:),
                                onTogglePin: { item in
                                    togglePin(item)
                                },
                                onReschedule: runQuickAction(item:action:)
                            )
                        }

                        if !quietCompletedItems.isEmpty || hiddenCompletedCount > 0 {
                            TodayQuietZone(
                                palette: palette,
                                items: quietCompletedItems,
                                hiddenCompletedCount: hiddenCompletedCount,
                                iconForCategory: categoryIcon(for:)
                            )
                        }

                        if let message = tasksViewModel.errorMessage ?? todayViewModel.errorMessage {
                            TodayInfoCard(
                                palette: palette,
                                title: "Something needs attention",
                                message: message
                            )
                        }

                        Color.clear
                            .frame(height: OneDockLayout.listBottomSpacerHeight + 24)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 32)
                }
                .oneKeyboardDismissible()
            }
        }
        .navigationTitle("Today")
        .oneNavigationBarDisplayMode(.large)
#if os(iOS)
        .toolbarColorScheme(appPalette.isDark ? .dark : .light, for: .navigationBar)
#endif
        .toolbar {
            ToolbarItem(placement: .oneNavigationLeading) {
                Button("Review") {
                    onOpenReview(dateLocal)
                }
                .accessibilityHint("Opens the review tab for this date.")
                .accessibilityIdentifier("one.today.open-review")
            }
            ToolbarItem(placement: .oneNavigationTrailing) {
                Button("Arrange") {
                    showsReorderSheet = true
                }
                .accessibilityHint("Reorders the visible Today items.")
                .accessibilityIdentifier("one.today.arrange")
            }
        }
        .sheet(isPresented: $showsReorderSheet) {
            TodayReorderSheet(
                palette: sheetPalette,
                items: activeItems,
                categoryName: categoryName(for:),
                onDismiss: {
                    showsReorderSheet = false
                },
                onSave: { reordered in
                    await todayViewModel.reorder(items: reordered, dateLocal: dateLocal)
                }
            )
        }
    }

    private func toggleExpanded(_ item: TodayItem) {
        OneHaptics.shared.trigger(.selectionChanged)
        withAnimation(OneMotion.animation(.expand)) {
            expandedItemID = expandedItemID == item.id ? nil : item.id
        }
    }

    private func categoryName(for categoryID: String) -> String {
        categoriesByID[categoryID]?.name ?? "Category"
    }

    private func categoryIcon(for categoryID: String) -> OneIconKey {
        let category = categoriesByID[categoryID]
        return OneIconKey.taskCategory(name: category?.name ?? "Category", storedIcon: category?.icon)
    }

    private func notePreview(for item: TodayItem) -> String {
        switch item.itemType {
        case .habit:
            return habitNotesByID[item.itemId] ?? ""
        case .todo:
            return todoNotesByID[item.itemId] ?? ""
        case .reflection:
            return ""
        }
    }

    private func detailDestination(for item: TodayItem) -> TodayItemDestinationContent {
        TodayItemDestinationContent(
            destination: detailRoute(for: item),
            tasksViewModel: tasksViewModel,
            anchorDate: dateLocal,
            onRefreshTasksContext: onRefreshTasksContext
        )
    }

    private func detailRoute(for item: TodayItem) -> TodayItemDestination {
        switch item.itemType {
        case .habit:
            return .habit(item.itemId)
        case .todo:
            return .todo(item.itemId)
        case .reflection:
            return .none
        }
    }

    private func trimmedNotes(_ notes: String?) -> String {
        (notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isBusy(_ item: TodayItem) -> Bool {
        busyItemIDs.contains(item.id)
    }

    private func performItemAction(for item: TodayItem, action: @escaping () async -> Void) {
        guard !busyItemIDs.contains(item.id) else {
            return
        }
        busyItemIDs.insert(item.id)
        Task { @MainActor in
            defer { busyItemIDs.remove(item.id) }
            await action()
        }
    }

    private func toggleItem(_ item: TodayItem) {
        performItemAction(for: item) {
            await todayViewModel.toggle(item: item, dateLocal: dateLocal)
            await onRefreshTasksContext()
            withAnimation(OneMotion.animation(.dismiss)) {
                if expandedItemID == item.id {
                    expandedItemID = nil
                }
            }
        }
    }

    private func moveToFront(_ item: TodayItem) {
        var reordered = activeItems
        reordered.removeAll { $0.id == item.id }
        reordered.insert(item, at: 0)
        performItemAction(for: item) {
            await todayViewModel.reorder(items: reordered, dateLocal: dateLocal)
            await onRefreshTasksContext()
            withAnimation(OneMotion.animation(.expand)) {
                expandedItemID = item.id
            }
        }
    }

    private func togglePin(_ item: TodayItem) {
        guard item.itemType == .todo else {
            return
        }
        performItemAction(for: item) {
            _ = await tasksViewModel.updateTodo(
                id: item.itemId,
                input: TodoUpdateInput(isPinned: !(item.isPinned ?? false))
            )
            await onRefreshTasksContext()
        }
    }

    private func runQuickAction(item: TodayItem, action: TodayQuickAction) {
        performItemAction(for: item) {
            switch action {
            case .todayEvening:
                if item.itemType == .todo {
                    _ = await tasksViewModel.updateTodo(id: item.itemId, input: TodoUpdateInput(dueAt: quickScheduleDate(hour: 19)))
                } else {
                    _ = await tasksViewModel.updateHabit(id: item.itemId, input: HabitUpdateInput(preferredTime: "19:00:00"))
                }
            case .tomorrowMorning:
                if item.itemType == .todo {
                    _ = await tasksViewModel.updateTodo(id: item.itemId, input: TodoUpdateInput(dueAt: quickScheduleDate(dayOffset: 1, hour: 9)))
                } else {
                    _ = await tasksViewModel.updateHabit(id: item.itemId, input: HabitUpdateInput(preferredTime: "08:00:00"))
                }
            case .nextWindow:
                if item.itemType == .todo {
                    _ = await tasksViewModel.updateTodo(id: item.itemId, input: TodoUpdateInput(dueAt: quickScheduleDate(dayOffset: 3, hour: 10)))
                } else {
                    _ = await tasksViewModel.updateHabit(id: item.itemId, input: HabitUpdateInput(preferredTime: "12:00:00"))
                }
            case .morning:
                _ = await tasksViewModel.updateHabit(id: item.itemId, input: HabitUpdateInput(preferredTime: "08:00:00"))
            case .midday:
                _ = await tasksViewModel.updateHabit(id: item.itemId, input: HabitUpdateInput(preferredTime: "12:00:00"))
            case .evening:
                _ = await tasksViewModel.updateHabit(id: item.itemId, input: HabitUpdateInput(preferredTime: "19:00:00"))
            }
            await onRefreshTasksContext()
        }
    }

    private func quickScheduleDate(dayOffset: Int = 0, hour: Int) -> Date {
        let calendar = Calendar.autoupdatingCurrent
        let base = calendar.startOfDay(for: Date())
        let shifted = calendar.date(byAdding: .day, value: dayOffset, to: base) ?? base
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: shifted) ?? shifted
    }
}

private struct TodayMosaicBoardLayout {
    let width: CGFloat
    let itemOrder: [String]
    let expandedItemID: String?
    let snapshot: TodayMosaicSnapshot
    let height: CGFloat

    static func make(
        itemOrder: [String],
        itemsByID: [String: TodayItem],
        expandedItemID: String?,
        width: CGFloat
    ) -> TodayMosaicBoardLayout {
        let resolvedWidth = max(width, 320)
        let resolvedItems = itemOrder.compactMap { itemsByID[$0] }
        let snapshot = TodayMosaicPlanner.plan(items: resolvedItems, width: resolvedWidth)
        let overflow = expandedOverflow(for: snapshot, expandedItemID: expandedItemID)
        return TodayMosaicBoardLayout(
            width: resolvedWidth,
            itemOrder: itemOrder,
            expandedItemID: expandedItemID,
            snapshot: snapshot,
            height: OneLayoutMath.nonNegative(snapshot.height + overflow)
        )
    }

    func matches(itemOrder: [String], expandedItemID: String?, width: CGFloat) -> Bool {
        self.itemOrder == itemOrder &&
        self.expandedItemID == expandedItemID &&
        abs(self.width - width) < 0.5
    }

    private static func expandedOverflow(for snapshot: TodayMosaicSnapshot, expandedItemID: String?) -> CGFloat {
        guard let expandedItemID,
              let placement = snapshot.placements.first(where: { $0.itemID == expandedItemID }) else {
            return 0
        }
        return placement.expansionHeight + 8
    }
}

private struct TodayMosaicBoard: View {
    let palette: TodaySurfacePalette
    let itemOrder: [String]
    let itemsByID: [String: TodayItem]
    let expandedItemID: String?
    let isBusy: (TodayItem) -> Bool
    let categoryIcon: (String) -> OneIconKey
    let notePreview: (TodayItem) -> String
    let detailDestination: (TodayItem) -> TodayItemDestinationContent
    let onExpandToggle: (TodayItem) -> Void
    let onComplete: (TodayItem) -> Void
    let onDoFirst: (TodayItem) -> Void
    let onTogglePin: (TodayItem) -> Void
    let onReschedule: (TodayItem, TodayQuickAction) -> Void

    @State private var cachedLayout: TodayMosaicBoardLayout

    init(
        palette: TodaySurfacePalette,
        itemOrder: [String],
        itemsByID: [String: TodayItem],
        expandedItemID: String?,
        isBusy: @escaping (TodayItem) -> Bool,
        categoryIcon: @escaping (String) -> OneIconKey,
        notePreview: @escaping (TodayItem) -> String,
        detailDestination: @escaping (TodayItem) -> TodayItemDestinationContent,
        onExpandToggle: @escaping (TodayItem) -> Void,
        onComplete: @escaping (TodayItem) -> Void,
        onDoFirst: @escaping (TodayItem) -> Void,
        onTogglePin: @escaping (TodayItem) -> Void,
        onReschedule: @escaping (TodayItem, TodayQuickAction) -> Void
    ) {
        self.palette = palette
        self.itemOrder = itemOrder
        self.itemsByID = itemsByID
        self.expandedItemID = expandedItemID
        self.isBusy = isBusy
        self.categoryIcon = categoryIcon
        self.notePreview = notePreview
        self.detailDestination = detailDestination
        self.onExpandToggle = onExpandToggle
        self.onComplete = onComplete
        self.onDoFirst = onDoFirst
        self.onTogglePin = onTogglePin
        self.onReschedule = onReschedule
        _cachedLayout = State(
            initialValue: TodayMosaicBoardLayout.make(
                itemOrder: itemOrder,
                itemsByID: itemsByID,
                expandedItemID: expandedItemID,
                width: 320
            )
        )
    }

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 320)
            let layout = resolvedLayout(for: width)
            ZStack(alignment: .topLeading) {
                ForEach(layout.snapshot.placements) { placement in
                    if let item = itemsByID[placement.itemID] {
                        let isExpanded = expandedItemID == item.id
                        TodayMosaicTile(
                            palette: palette,
                            item: item,
                            placement: placement,
                            categoryIcon: categoryIcon(item.categoryId),
                            notePreview: notePreview(item),
                            isExpanded: isExpanded,
                            isBusy: isBusy(item),
                            detailDestination: detailDestination(item),
                            onExpandToggle: {
                                onExpandToggle(item)
                            },
                            onComplete: {
                                onComplete(item)
                            },
                            onDoFirst: {
                                onDoFirst(item)
                            },
                            onTogglePin: item.itemType == .todo ? {
                                onTogglePin(item)
                            } : nil,
                            onReschedule: { action in
                                onReschedule(item, action)
                            }
                        )
                        .frame(
                            width: OneLayoutMath.nonNegative(placement.frame.width),
                            height: OneLayoutMath.nonNegative(
                                placement.frame.height + (isExpanded ? placement.expansionHeight : 0)
                            )
                        )
                        .offset(x: placement.frame.minX, y: placement.frame.minY)
                        .zIndex(isExpanded ? 3 : 0)
                    }
                }
            }
            .frame(height: layout.height, alignment: .top)
            .onAppear {
                updateCachedLayout(width: width)
            }
            .onChange(of: width) { _, newValue in
                updateCachedLayout(width: newValue)
            }
            .onChange(of: layoutCacheKey) { _, _ in
                updateCachedLayout(width: width)
            }
        }
        .frame(height: cachedLayout.height)
    }

    private var layoutCacheKey: [String] {
        itemOrder + [expandedItemID ?? ""]
    }

    private func resolvedLayout(for width: CGFloat) -> TodayMosaicBoardLayout {
        if cachedLayout.matches(itemOrder: itemOrder, expandedItemID: expandedItemID, width: width) {
            return cachedLayout
        }
        return TodayMosaicBoardLayout.make(
            itemOrder: itemOrder,
            itemsByID: itemsByID,
            expandedItemID: expandedItemID,
            width: width
        )
    }

    private func updateCachedLayout(width: CGFloat) {
        cachedLayout = TodayMosaicBoardLayout.make(
            itemOrder: itemOrder,
            itemsByID: itemsByID,
            expandedItemID: expandedItemID,
            width: width
        )
    }
}

private struct TodaySurfaceHeader: View {
    let palette: TodaySurfacePalette
    let dateTitle: String
    let activeCount: Int
    let completedCount: Int
    let completionRatio: Double
    let nextTitle: String?

    private var statusTitle: String {
        if activeCount == 0 {
            return completedCount == 0 ? "Quiet start" : "Surface clear"
        }
        if activeCount == 1 {
            return "1 focus item"
        }
        return "\(activeCount) in motion"
    }

    private var summaryLine: String {
        if let nextTitle, activeCount > 0 {
            return activeCount == 1 ? "Start with \(nextTitle)" : "Lead with \(nextTitle)"
        }
        if completedCount > 0 {
            return "\(completedCount) settled below"
        }
        return "Nothing planned yet"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(dateTitle)
                .font(OneType.label)
                .foregroundStyle(palette.headerMeta)
            HStack(alignment: .bottom, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(statusTitle)
                        .font(.system(size: 25, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.headerTitle)
                    Text(summaryLine)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(palette.headerBody)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                TodayProgressPill(palette: palette, progress: completionRatio)
            }
        }
    }
}

private struct TodayMetricPill: View {
    let palette: TodaySurfacePalette
    let title: String

    var body: some View {
        Text(title)
            .font(OneType.caption.weight(.semibold))
            .foregroundStyle(palette.headerTitle)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(palette.panelFillStrong)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(palette.panelStroke, lineWidth: 1)
            )
    }
}

private struct TodayProgressPill: View {
    let palette: TodaySurfacePalette
    let progress: Double

    var body: some View {
        let clampedProgress = OneLayoutMath.unitInterval(progress)
        HStack(spacing: 8) {
            Capsule(style: .continuous)
                .fill(palette.progressTrack)
                .frame(width: 56, height: 8)
                .overlay(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(palette.progressFill)
                        .frame(
                            width: OneLayoutMath.filledWidth(
                                containerWidth: 56,
                                fraction: clampedProgress,
                                minimumWhenVisible: 10
                            ),
                            height: 8
                        )
                }
            Text("\(OneLayoutMath.percent(clampedProgress))%")
                .font(OneType.caption.weight(.semibold))
                .foregroundStyle(palette.progressText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(palette.panelFill)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(palette.panelStroke, lineWidth: 1)
        )
    }
}

private struct TodayInfoCard: View {
    let palette: TodaySurfacePalette
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(OneType.sectionTitle)
                .foregroundStyle(palette.headerTitle)
            Text(message)
                .font(OneType.secondary)
                .foregroundStyle(palette.headerBody)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: OneTheme.radiusLarge, style: .continuous)
                .fill(palette.panelFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: OneTheme.radiusLarge, style: .continuous)
                .stroke(palette.panelStroke, lineWidth: 1)
        )
        .shadow(color: palette.shadowColor.opacity(0.18), radius: 10, x: 0, y: 6)
    }
}

private struct TodayQuietZone: View {
    let palette: TodaySurfacePalette
    let items: [TodayItem]
    let hiddenCompletedCount: Int
    let iconForCategory: (String) -> OneIconKey

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LinearGradient(
                colors: [palette.quietStroke.opacity(0), palette.quietStroke, palette.quietStroke.opacity(0)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 1)
            .padding(.bottom, 4)

            HStack(spacing: 8) {
                Text("Settled")
                    .font(OneType.label)
                    .foregroundStyle(palette.headerMeta)
                if hiddenCompletedCount > 0 {
                    TodayMetricPill(palette: palette, title: "+\(hiddenCompletedCount) cleared")
                }
            }

            VStack(spacing: 8) {
                ForEach(items) { item in
                    HStack(alignment: .top, spacing: 10) {
                        OneIcon(
                            key: iconForCategory(item.categoryId),
                            palette: OneTheme.palette(for: .dark),
                            size: 15,
                            tint: palette.quietSupporting
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            TodayQuietRowTitle(text: item.title, palette: palette)
                            TodayQuietRowSubtitle(text: item.subtitle ?? "Completed", palette: palette)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        Capsule(style: .continuous)
                            .fill(palette.quietFill)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(palette.quietStroke, lineWidth: 1)
                    )
                }
            }
        }
        .opacity(0.9)
    }
}

private struct TodayAtmosphericBackground: View {
    let palette: TodaySurfacePalette
    let bucket: TodayTimeBucket

    private var warmColor: Color {
        switch bucket {
        case .morning:
            return palette.amande.opacity(0.12)
        case .midday:
            return palette.backgroundWarmHalo
        case .evening:
            return palette.orange.opacity(0.1)
        case .late:
            return palette.orangeDeep.opacity(0.08)
        case .anytime:
            return palette.backgroundWarmHalo
        }
    }

    var body: some View {
        LinearGradient(
            colors: [palette.backgroundTop, palette.backgroundMid, palette.backgroundBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topLeading) {
            Circle()
                .fill(palette.backgroundCoolGlow)
                .frame(width: 280, height: 280)
                .blur(radius: 82)
                .offset(x: -76, y: -54)
        }
        .overlay(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 84, style: .continuous)
                .fill(palette.backgroundWarmGlow)
                .frame(width: 250, height: 220)
                .blur(radius: 92)
                .offset(x: 58, y: -34)
        }
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(warmColor)
                .frame(width: 180, height: 180)
                .blur(radius: 96)
                .offset(x: 38, y: -80)
        }
        .ignoresSafeArea()
    }
}

struct TodayMosaicPlacement: Identifiable {
    enum ShapeStyle {
        case asymmetricLeading
        case asymmetricTrailing
        case pill
        case clipped
    }

    enum Footprint {
        case lead
        case leadTall
        case body
        case compact
        case ribbon
    }

    let itemID: String
    let frame: CGRect
    let shapeStyle: ShapeStyle
    let footprint: Footprint

    var expansionHeight: CGFloat {
        switch footprint {
        case .lead:
            return 96
        case .leadTall:
            return 104
        case .body:
            return 112
        case .compact:
            return 124
        case .ribbon:
            return 96
        }
    }

    var id: String { itemID }
}

struct TodayMosaicSnapshot {
    let placements: [TodayMosaicPlacement]
    let height: CGFloat
}

private enum TodayQuickAction: Hashable, Identifiable {
    case todayEvening
    case tomorrowMorning
    case nextWindow
    case morning
    case midday
    case evening

    var id: String { label }

    var label: String {
        switch self {
        case .todayEvening:
            return "This evening"
        case .tomorrowMorning:
            return "Tomorrow"
        case .nextWindow:
            return "Next window"
        case .morning:
            return "Morning"
        case .midday:
            return "Midday"
        case .evening:
            return "Evening"
        }
    }
}

private enum TodaySurfaceDensity {
    case airy
    case balanced
    case packed
}

// Thresholds are intentionally stepped so swipe feedback reads as staged, not binary.
private enum TodaySwipeThresholds {
    static let rightHint: CGFloat = 16
    static let rightPreview: CGFloat = 44
    static let rightCommitArm: CGFloat = 84
    static let rightCommit: CGFloat = 122
    static let rightSettled: CGFloat = 68

    static let leftHint: CGFloat = -16
    static let leftActionsReveal: CGFloat = -42
    static let leftExpandArm: CGFloat = -94
    static let leftCommit: CGFloat = -132
    static let leftSettled: CGFloat = -96

    static let maxLeft: CGFloat = -148
    static let maxRight: CGFloat = 136

    static func clamped(_ value: CGFloat) -> CGFloat {
        min(max(value, maxLeft), maxRight)
    }
}

private enum TodaySwipeStage {
    case resting
    case completeHint
    case completePreview
    case completeReady
    case actionsHint
    case actionsReveal
    case expandReady

    static func resolve(offset: CGFloat) -> TodaySwipeStage {
        if offset <= TodaySwipeThresholds.leftExpandArm {
            return .expandReady
        }
        if offset <= TodaySwipeThresholds.leftActionsReveal {
            return .actionsReveal
        }
        if offset <= TodaySwipeThresholds.leftHint {
            return .actionsHint
        }
        if offset >= TodaySwipeThresholds.rightCommitArm {
            return .completeReady
        }
        if offset >= TodaySwipeThresholds.rightPreview {
            return .completePreview
        }
        if offset >= TodaySwipeThresholds.rightHint {
            return .completeHint
        }
        return .resting
    }
}

private enum TodayCompletionVisualState {
    case idle
    case committing
}

private enum TodayTileFamily {
    case oxfordAnchor
    case oxfordQuiet
    case vistaCalm
    case orangeSignal
    case completed
}

private enum TodayUrgencyIntensity {
    case none
    case hint
    case elevated
    case critical
}

private struct TodayTileAppearance {
    let family: TodayTileFamily
    let fillColors: [Color]
    let titleColor: Color
    let supportingColor: Color
    let iconTint: Color
    let iconFill: Color
    let iconStroke: Color
    let borderColor: Color
    let shadowColor: Color
    let actionTint: Color
    let actionFill: Color
    let actionStroke: Color
    let noteFill: Color
    let noteText: Color
    let progressTint: Color
    let progressTrack: Color
    let urgencyTint: Color
    let urgencyFill: Color
    let pinTint: Color
    let accentRibbonColors: [Color]
    let accentRibbonOpacity: Double
    let accentRibbonStroke: Color
    let completionOverlay: Color
}

private struct TodaySurfacePalette {
    let oxfordBlue = Color(hex: 0x0B0829)
    let oxfordMid = Color(hex: 0x16103A)
    let oxfordLift = Color(hex: 0x231957)
    let oxfordDeep = Color(hex: 0x050317)
    let oxfordInk = Color(hex: 0x140D34)
    let vistaBlue = Color(hex: 0x8FA0D8)
    let vistaLift = Color(hex: 0xA9B7E7)
    let vistaDeep = Color(hex: 0x6F84C7)
    let orange = Color(hex: 0xFF8400)
    let orangeAmber = Color(hex: 0xE76B00)
    let orangeDeep = Color(hex: 0xA84500)
    let amande = Color(hex: 0xF9DFC6)
    let amandeGlow = Color(hex: 0xFFF4EA)

    let backgroundTop: Color
    let backgroundMid: Color
    let backgroundBottom: Color
    let backgroundCoolGlow: Color
    let backgroundWarmGlow: Color
    let backgroundWarmHalo: Color
    let headerTitle: Color
    let headerBody: Color
    let headerMeta: Color
    let panelFill: Color
    let panelFillStrong: Color
    let panelStroke: Color
    let quietFill: Color
    let quietStroke: Color
    let quietTitle: Color
    let quietSupporting: Color
    let progressFill: Color
    let progressTrack: Color
    let progressText: Color
    let accent: Color
    let highlight: Color
    let warning: Color
    let danger: Color
    let shadowColor: Color

    init(colorScheme: ColorScheme) {
        let appPalette = OneTheme.palette(for: colorScheme)
        backgroundTop = appPalette.backgroundTop
        backgroundMid = appPalette.background
        backgroundBottom = appPalette.background
        backgroundCoolGlow = appPalette.accentSoft.opacity(appPalette.isDark ? 0.2 : 0.12)
        backgroundWarmGlow = appPalette.accentSoft.opacity(appPalette.isDark ? 0.12 : 0.08)
        backgroundWarmHalo = appPalette.accentSoft.opacity(appPalette.isDark ? 0.08 : 0.05)
        headerTitle = appPalette.text
        headerBody = appPalette.subtext
        headerMeta = appPalette.accent
        panelFill = appPalette.surface
        panelFillStrong = appPalette.surfaceStrong
        panelStroke = appPalette.border
        quietFill = appPalette.surfaceMuted
        quietStroke = appPalette.border
        quietTitle = appPalette.text.opacity(appPalette.isDark ? 0.76 : 0.84)
        quietSupporting = appPalette.subtext.opacity(appPalette.isDark ? 0.72 : 0.84)
        progressFill = appPalette.accent
        progressTrack = appPalette.surfaceStrong
        progressText = appPalette.text
        accent = appPalette.accent
        highlight = appPalette.highlight
        warning = appPalette.warning
        danger = appPalette.danger
        shadowColor = appPalette.shadowColor
    }

    func appearance(for item: TodayItem, isExpanded: Bool, isCompleting: Bool) -> TodayTileAppearance {
        if isCompleting {
            return TodayTileAppearance(
                family: .completed,
                fillColors: [
                    oxfordLift.opacity(0.9),
                    oxfordMid.opacity(0.96),
                    oxfordDeep
                ],
                titleColor: amandeGlow,
                supportingColor: amande.opacity(0.78),
                iconTint: amande,
                iconFill: amande.opacity(0.14),
                iconStroke: amande.opacity(0.16),
                borderColor: amande.opacity(0.2),
                shadowColor: shadowColor,
                actionTint: amandeGlow,
                actionFill: oxfordLift.opacity(0.78),
                actionStroke: amande.opacity(0.16),
                noteFill: oxfordLift.opacity(0.64),
                noteText: amande.opacity(0.82),
                progressTint: amande,
                progressTrack: oxfordBlue.opacity(0.7),
                urgencyTint: oxfordBlue,
                urgencyFill: amande.opacity(0.24),
                pinTint: amande,
                accentRibbonColors: [amande, vistaLift],
                accentRibbonOpacity: 0,
                accentRibbonStroke: amande.opacity(0.14),
                completionOverlay: amande.opacity(0.22)
            )
        }

        let intensity = urgencyIntensity(for: item)
        let family = tileFamily(for: item, intensity: intensity)
        let ribbonOpacity = accentRibbonOpacity(for: intensity, family: family)
        let ribbonColors = [orange.opacity(0.96), orangeAmber.opacity(0.92), amande.opacity(0.88)]

        switch family {
        case .oxfordAnchor:
            return TodayTileAppearance(
                family: family,
                fillColors: [
                    (isExpanded ? oxfordLift.opacity(0.98) : oxfordLift.opacity(0.94)),
                    oxfordMid.opacity(0.96),
                    oxfordDeep
                ],
                titleColor: amandeGlow,
                supportingColor: amande.opacity(isExpanded ? 0.82 : 0.72),
                iconTint: vistaLift,
                iconFill: vistaBlue.opacity(0.14),
                iconStroke: amande.opacity(0.12),
                borderColor: ribbonOpacity > 0.01 ? orange.opacity(0.24) : vistaBlue.opacity(0.18),
                shadowColor: oxfordDeep.opacity(isExpanded ? 0.54 : 0.42),
                actionTint: amandeGlow,
                actionFill: oxfordLift.opacity(0.88),
                actionStroke: vistaBlue.opacity(0.18),
                noteFill: oxfordLift.opacity(0.82),
                noteText: amande.opacity(0.82),
                progressTint: ribbonOpacity > 0.01 ? amande : vistaLift,
                progressTrack: oxfordBlue.opacity(0.72),
                urgencyTint: amande,
                urgencyFill: orange.opacity(0.22),
                pinTint: amande,
                accentRibbonColors: ribbonColors,
                accentRibbonOpacity: ribbonOpacity,
                accentRibbonStroke: amande.opacity(0.12),
                completionOverlay: amande.opacity(0.18)
            )
        case .oxfordQuiet:
            return TodayTileAppearance(
                family: family,
                fillColors: [
                    oxfordMid.opacity(0.88),
                    oxfordBlue.opacity(0.96),
                    oxfordDeep
                ],
                titleColor: amande.opacity(0.88),
                supportingColor: vistaBlue.opacity(0.66),
                iconTint: vistaBlue.opacity(0.78),
                iconFill: oxfordLift.opacity(0.7),
                iconStroke: vistaBlue.opacity(0.14),
                borderColor: oxfordLift.opacity(0.26),
                shadowColor: oxfordDeep.opacity(0.34),
                actionTint: amande.opacity(0.86),
                actionFill: oxfordLift.opacity(0.72),
                actionStroke: vistaBlue.opacity(0.14),
                noteFill: oxfordLift.opacity(0.6),
                noteText: amande.opacity(0.74),
                progressTint: vistaBlue.opacity(0.84),
                progressTrack: oxfordBlue.opacity(0.74),
                urgencyTint: amande,
                urgencyFill: orange.opacity(0.18),
                pinTint: amande.opacity(0.9),
                accentRibbonColors: ribbonColors,
                accentRibbonOpacity: ribbonOpacity * 0.9,
                accentRibbonStroke: vistaBlue.opacity(0.12),
                completionOverlay: amande.opacity(0.14)
            )
        case .vistaCalm:
            return TodayTileAppearance(
                family: family,
                fillColors: [
                    (isExpanded ? vistaLift.opacity(0.98) : vistaLift.opacity(0.94)),
                    vistaBlue.opacity(0.96),
                    vistaDeep.opacity(0.96)
                ],
                titleColor: oxfordInk,
                supportingColor: oxfordInk.opacity(0.72),
                iconTint: oxfordBlue,
                iconFill: amande.opacity(0.28),
                iconStroke: oxfordBlue.opacity(0.12),
                borderColor: oxfordBlue.opacity(0.16),
                shadowColor: vistaDeep.opacity(0.22),
                actionTint: oxfordInk,
                actionFill: amande.opacity(0.34),
                actionStroke: oxfordBlue.opacity(0.12),
                noteFill: amande.opacity(0.28),
                noteText: oxfordInk.opacity(0.74),
                progressTint: oxfordBlue.opacity(0.88),
                progressTrack: vistaDeep.opacity(0.24),
                urgencyTint: oxfordBlue,
                urgencyFill: orange.opacity(0.18),
                pinTint: oxfordBlue,
                accentRibbonColors: ribbonColors,
                accentRibbonOpacity: ribbonOpacity,
                accentRibbonStroke: oxfordBlue.opacity(0.12),
                completionOverlay: amande.opacity(0.14)
            )
        case .orangeSignal:
            return TodayTileAppearance(
                family: family,
                fillColors: [
                    orange.opacity(0.98),
                    orangeAmber.opacity(0.96),
                    orangeDeep.opacity(0.98)
                ],
                titleColor: oxfordBlue,
                supportingColor: oxfordBlue.opacity(0.78),
                iconTint: amandeGlow,
                iconFill: oxfordBlue.opacity(0.16),
                iconStroke: amande.opacity(0.18),
                borderColor: amande.opacity(0.18),
                shadowColor: orangeDeep.opacity(0.3),
                actionTint: oxfordBlue,
                actionFill: amande.opacity(0.28),
                actionStroke: oxfordBlue.opacity(0.12),
                noteFill: amande.opacity(0.2),
                noteText: oxfordBlue.opacity(0.76),
                progressTint: oxfordBlue,
                progressTrack: amande.opacity(0.26),
                urgencyTint: amandeGlow,
                urgencyFill: oxfordBlue.opacity(0.2),
                pinTint: amandeGlow,
                accentRibbonColors: ribbonColors,
                accentRibbonOpacity: 0,
                accentRibbonStroke: amande.opacity(0.14),
                completionOverlay: amande.opacity(0.18)
            )
        case .completed:
            return TodayTileAppearance(
                family: family,
                fillColors: [
                    oxfordMid.opacity(0.76),
                    oxfordBlue.opacity(0.9),
                    oxfordDeep
                ],
                titleColor: amande.opacity(0.62),
                supportingColor: vistaBlue.opacity(0.46),
                iconTint: vistaBlue.opacity(0.58),
                iconFill: oxfordLift.opacity(0.46),
                iconStroke: vistaBlue.opacity(0.08),
                borderColor: vistaBlue.opacity(0.1),
                shadowColor: oxfordDeep.opacity(0.2),
                actionTint: amande.opacity(0.66),
                actionFill: oxfordLift.opacity(0.42),
                actionStroke: vistaBlue.opacity(0.08),
                noteFill: oxfordLift.opacity(0.38),
                noteText: amande.opacity(0.66),
                progressTint: vistaBlue.opacity(0.58),
                progressTrack: oxfordBlue.opacity(0.68),
                urgencyTint: amande.opacity(0.74),
                urgencyFill: orange.opacity(0.14),
                pinTint: amande.opacity(0.74),
                accentRibbonColors: ribbonColors,
                accentRibbonOpacity: 0,
                accentRibbonStroke: vistaBlue.opacity(0.08),
                completionOverlay: amande.opacity(0.12)
            )
        }
    }

    private func urgencyIntensity(for item: TodayItem) -> TodayUrgencyIntensity {
        guard !item.completed else {
            return .none
        }
        switch item.urgency {
        case .overdue:
            if item.priorityTier == .urgent ||
                item.manualBoost >= 0.28 ||
                (item.prominence == .featured && item.manualBoost >= 0.12) {
                return .critical
            }
            return .elevated
        case .dueToday:
            return item.priorityTier == .urgent || item.manualBoost >= 0.22 ? .elevated : .hint
        case .soon:
            return .hint
        case .none:
            return .none
        }
    }

    private func tileFamily(for item: TodayItem, intensity: TodayUrgencyIntensity) -> TodayTileFamily {
        if item.completed {
            return .completed
        }
        if intensity == .critical {
            return .orangeSignal
        }
        if (item.prominence == .featured && intensity != .none) ||
            item.isPinned == true ||
            item.manualBoost >= 0.22 ||
            (item.itemType == .habit && item.learningConfidence >= 0.72) {
            return .oxfordAnchor
        }
        if item.priorityTier == .low && intensity == .none {
            return .oxfordQuiet
        }
        return .vistaCalm
    }

    private func accentRibbonOpacity(for intensity: TodayUrgencyIntensity, family: TodayTileFamily) -> Double {
        guard family != .orangeSignal && family != .completed else {
            return 0
        }
        switch intensity {
        case .none:
            return 0
        case .hint:
            return 0.3
        case .elevated:
            return 0.5
        case .critical:
            return 0.72
        }
    }
}

enum TodayMosaicPlanner {
    private struct TileSpec {
        let columnSpan: Int
        let height: CGFloat
        let shape: TodayMosaicPlacement.ShapeStyle
        let footprint: TodayMosaicPlacement.Footprint
    }

    private struct ClusterAnchor {
        var sum: Double = 0
        var count: Int = 0
        var lastBottom: CGFloat = 0
    }

    static func plan(items: [TodayItem], width: CGFloat) -> TodayMosaicSnapshot {
        let density = density(for: items.count)
        let columns = 10
        let horizontalGap: CGFloat = 8
        let verticalGap: CGFloat = density == .airy ? 14 : 12
        let minimumColumnWidth: CGFloat = 24
        let minimumBoardWidth = (CGFloat(columns) * minimumColumnWidth) + (CGFloat(columns - 1) * horizontalGap)
        let resolvedWidth = max(OneLayoutMath.nonNegative(width), minimumBoardWidth)
        let columnWidth = (resolvedWidth - (CGFloat(columns - 1) * horizontalGap)) / CGFloat(columns)
        var columnHeights = Array(repeating: CGFloat(0), count: columns)
        var clusterAnchors: [String: ClusterAnchor] = [:]
        var recentShapes: [TodayMosaicPlacement.ShapeStyle] = []
        var placements: [TodayMosaicPlacement] = []
        let heroItemID = featuredHeroID(for: items)

        for item in items {
            let isHero = item.id == heroItemID
            let spec = tileSpec(for: item, density: density, isHero: isHero)
            let maxStart = max(0, columns - spec.columnSpan)
            let desiredColumn = targetColumn(for: item, maxStart: maxStart)
            var bestColumn = 0
            var bestY: CGFloat = 0
            var bestScore = Double.greatestFiniteMagnitude

            for column in 0...maxStart {
                let slice = columnHeights[column..<(column + spec.columnSpan)]
                let y = slice.max() ?? 0
                var score = Double(y) * (isHero ? 0.82 : 1.0)
                score += Double(abs(column - desiredColumn)) * 18

                if let anchor = clusterAnchors[item.clusterKey], anchor.count > 0 {
                    let averageColumn = anchor.sum / Double(anchor.count)
                    score += abs(Double(column) - averageColumn) * 7
                    score += max(0, Double(y - anchor.lastBottom)) * 0.04
                }

                if recentShapes.suffix(2).allSatisfy({ $0 == spec.shape }) {
                    score += 8
                }
                if item.urgency == .overdue {
                    score -= 24
                } else if item.urgency == .dueToday {
                    score -= 14
                }
                if item.manualBoost >= 0.22 {
                    score -= 18
                }
                if isHero {
                    score -= 10
                }
                if column == 0 && (isHero || item.urgency != .none || item.manualBoost >= 0.14) {
                    score -= 6
                }
                if column >= max(0, maxStart - 1) && item.priorityTier == .low && item.urgency == .none {
                    score -= 4
                }

                if score < bestScore {
                    bestScore = score
                    bestColumn = column
                    bestY = y
                }
            }

            let frame = CGRect(
                x: CGFloat(bestColumn) * (columnWidth + horizontalGap),
                y: bestY,
                width: CGFloat(spec.columnSpan) * columnWidth + CGFloat(spec.columnSpan - 1) * horizontalGap,
                height: spec.height
            )
            for column in bestColumn..<(bestColumn + spec.columnSpan) {
                columnHeights[column] = frame.maxY + verticalGap
            }

            var anchor = clusterAnchors[item.clusterKey, default: ClusterAnchor()]
            anchor.sum += Double(bestColumn)
            anchor.count += 1
            anchor.lastBottom = frame.maxY
            clusterAnchors[item.clusterKey] = anchor

            recentShapes.append(spec.shape)
            if recentShapes.count > 4 {
                recentShapes.removeFirst()
            }

            placements.append(
                TodayMosaicPlacement(
                    itemID: item.id,
                    frame: frame,
                    shapeStyle: spec.shape,
                    footprint: spec.footprint
                )
            )
        }

        let height = max(0, (columnHeights.max() ?? 0) - verticalGap)
        return TodayMosaicSnapshot(placements: placements, height: height)
    }

    private static func density(for count: Int) -> TodaySurfaceDensity {
        switch count {
        case ..<5:
            return .airy
        case ..<9:
            return .balanced
        default:
            return .packed
        }
    }

    private static func featuredHeroID(for items: [TodayItem]) -> String? {
        items.first(where: {
            $0.prominence == .featured ||
            $0.urgency == .overdue ||
            $0.manualBoost >= 0.18 ||
            $0.isPinned == true
        })?.id ?? items.first?.id
    }

    private static func tileSpec(for item: TodayItem, density: TodaySurfaceDensity, isHero: Bool) -> TileSpec {
        let seed = stableSeed(item.id)
        if isHero {
            if density == .airy && seed.isMultiple(of: 3) {
                return TileSpec(
                    columnSpan: 5,
                    height: 120,
                    shape: seed.isMultiple(of: 2) ? .asymmetricLeading : .clipped,
                    footprint: .leadTall
                )
            }
            return TileSpec(
                columnSpan: 6,
                height: density == .packed ? 96 : density == .balanced ? 104 : 112,
                shape: seed.isMultiple(of: 4) ? .clipped : .asymmetricLeading,
                footprint: .lead
            )
        }

        switch item.prominence {
        case .featured, .standard:
            if density == .airy && seed.isMultiple(of: 7) {
                return TileSpec(columnSpan: 6, height: 76, shape: .pill, footprint: .ribbon)
            }
            if seed.isMultiple(of: 3) {
                return TileSpec(
                    columnSpan: 4,
                    height: density == .packed ? 74 : density == .balanced ? 80 : 86,
                    shape: seed.isMultiple(of: 5) ? .pill : .asymmetricTrailing,
                    footprint: .compact
                )
            }
            return TileSpec(
                columnSpan: 5,
                height: density == .packed ? 80 : density == .balanced ? 88 : 94,
                shape: seed.isMultiple(of: 4) ? .clipped : .asymmetricLeading,
                footprint: .body
            )
        case .compact:
            if density == .airy && seed.isMultiple(of: 5) {
                return TileSpec(columnSpan: 5, height: 72, shape: .pill, footprint: .ribbon)
            }
            return TileSpec(
                columnSpan: 4,
                height: density == .packed ? 68 : density == .balanced ? 72 : 78,
                shape: seed.isMultiple(of: 6) ? .pill : .asymmetricTrailing,
                footprint: .compact
            )
        }
    }

    private static func targetColumn(for item: TodayItem, maxStart: Int) -> Int {
        let proposal: Int
        switch item.timeBucket {
        case .morning:
            proposal = 0
        case .midday:
            proposal = max(1, Int(round(Double(maxStart) * 0.25)))
        case .evening:
            proposal = Int(round(Double(maxStart) * 0.55))
        case .late:
            proposal = maxStart
        case .anytime:
            proposal = stableSeed(item.clusterKey) % max(1, maxStart + 1)
        }

        var adjusted = proposal
        if item.urgency == .overdue || item.manualBoost >= 0.22 {
            adjusted -= 1
        } else if item.priorityTier == .low && item.urgency == .none {
            adjusted += 1
        }
        return min(max(adjusted, 0), maxStart)
    }

    private static func stableSeed(_ value: String) -> Int {
        value.unicodeScalars.reduce(0) { partial, scalar in
            ((partial * 31) + Int(scalar.value)) & 0x7fffffff
        }
    }
}

private struct TodayMosaicTile: View {
    let palette: TodaySurfacePalette
    let item: TodayItem
    let placement: TodayMosaicPlacement
    let categoryIcon: OneIconKey
    let notePreview: String
    let isExpanded: Bool
    let isBusy: Bool
    let detailDestination: TodayItemDestinationContent
    let onExpandToggle: () -> Void
    let onComplete: () -> Void
    let onDoFirst: () -> Void
    let onTogglePin: (() -> Void)?
    let onReschedule: (TodayQuickAction) -> Void

    @State private var settledOffset: CGFloat = 0
    @State private var liveOffset: CGFloat = 0
    @State private var dragOriginOffset: CGFloat?
    @State private var completionVisualState: TodayCompletionVisualState = .idle
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var tileOffset: CGFloat {
        dragOriginOffset == nil ? settledOffset : liveOffset
    }

    private var forwardSwipeProgress: CGFloat {
        max(0, min(1, tileOffset / max(TodaySwipeThresholds.rightCommit, 1)))
    }

    private var backwardSwipeProgress: CGFloat {
        max(0, min(1, abs(min(0, tileOffset)) / abs(TodaySwipeThresholds.leftCommit)))
    }

    private var swipeStage: TodaySwipeStage {
        TodaySwipeStage.resolve(offset: tileOffset)
    }

    private var urgencyLabel: String? {
        switch item.urgency {
        case .overdue:
            return "Overdue"
        case .dueToday:
            return "Due"
        case .soon:
            return "Soon"
        case .none:
            return nil
        }
    }

    private var quickActions: [TodayQuickAction] {
        if item.itemType == .habit {
            return [.morning, .midday, .evening]
        }
        return [.todayEvening, .tomorrowMorning, .nextWindow]
    }

    private var outerHeight: CGFloat {
        OneLayoutMath.nonNegative(placement.frame.height + (isExpanded ? placement.expansionHeight : 0))
    }

    private var contentPadding: CGFloat {
        switch placement.footprint {
        case .lead, .leadTall:
            return 16
        case .ribbon:
            return 12
        default:
            return 15
        }
    }

    private var titleLineLimit: Int {
        isExpanded ? 3 : placement.frame.width > 220 || placement.footprint == .leadTall ? 3 : 2
    }

    private var titleFontSize: CGFloat {
        if placement.footprint == .lead || placement.footprint == .leadTall || placement.frame.width > 220 {
            return 19
        }
        if placement.frame.width > 170 {
            return 17
        }
        return 15
    }

    private var quickActionColumns: [GridItem] {
        [GridItem(.adaptive(minimum: placement.frame.width > 210 ? 90 : 82), spacing: 6, alignment: .leading)]
    }

    private var appearance: TodayTileAppearance {
        palette.appearance(
            for: item,
            isExpanded: isExpanded,
            isCompleting: completionVisualState == .committing
        )
    }

    private var completionRailLabel: String {
        switch swipeStage {
        case .completeHint:
            return "Complete"
        case .completePreview:
            return "Ready to finish"
        case .completeReady:
            return "Release to finish"
        default:
            return "Complete"
        }
    }

    private var actionRailLabel: String {
        switch swipeStage {
        case .actionsHint:
            return "More"
        case .actionsReveal:
            return "Actions ready"
        case .expandReady:
            return "Release to open"
        default:
            return "Actions"
        }
    }

    var body: some View {
        ZStack {
            swipeBackground

            tileSurface
                .offset(x: tileOffset)
                .scaleEffect(completionVisualState == .committing ? 0.84 : (1 - forwardSwipeProgress * 0.035))
                .opacity(completionVisualState == .committing ? 0.08 : (isBusy ? 0.76 : 1) - forwardSwipeProgress * 0.12)
                .overlay {
                    completionConfirmationOverlay
                }
                .gesture(dragGesture)
                .animation(OneMotion.animation(.stateChange, reduceMotion: reduceMotion), value: tileOffset)
                .animation(OneMotion.animation(.milestone, reduceMotion: reduceMotion), value: completionVisualState == .committing)
        }
        .frame(
            width: OneLayoutMath.nonNegative(placement.frame.width),
            height: outerHeight,
            alignment: .topLeading
        )
        .onChange(of: isExpanded) { _, expanded in
            if expanded {
                resetSwipeRail(animated: true)
            }
        }
        .onChange(of: isBusy) { _, busy in
            guard !busy, completionVisualState == .committing else {
                return
            }
            withAnimation(OneMotion.animation(.dismiss, reduceMotion: reduceMotion)) {
                completionVisualState = .idle
                settledOffset = 0
                liveOffset = 0
            }
        }
    }

    private var swipeBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(palette.panelFillStrong)
            .overlay(alignment: .leading) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(appearance.actionFill.opacity(forwardSwipeProgress > 0.7 ? 0.98 : 0.82))
                            .frame(width: 34, height: 34)
                        OneAppIcon(
                            key: .ui(swipeStage == .completeReady ? .completed : .completedOutline),
                            size: 18,
                            tint: appearance.progressTint
                        )
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(completionRailLabel)
                            .font(OneType.caption.weight(.semibold))
                            .foregroundStyle(swipeStage == .completeReady ? appearance.progressTint : palette.headerTitle)
                        TodaySwipeProgressBar(
                            palette: palette,
                            progress: forwardSwipeProgress,
                            tint: appearance.progressTint,
                            track: appearance.progressTrack,
                            isArmed: swipeStage == .completeReady
                        )
                    }
                }
                .padding(.leading, 16)
                .opacity(forwardSwipeProgress)
                .scaleEffect(0.96 + forwardSwipeProgress * 0.04, anchor: .leading)
            }
            .overlay(alignment: .trailing) {
                VStack(alignment: .trailing, spacing: 8) {
                    Text(actionRailLabel)
                        .font(OneType.caption.weight(.semibold))
                        .foregroundStyle(swipeStage == .expandReady ? palette.amande : palette.headerTitle)

                    VStack(alignment: .trailing, spacing: 6) {
                        TodayRailButton(
                            palette: palette,
                            title: swipeStage == .expandReady ? "Release to open" : "Open",
                            tint: palette.amande,
                            fill: appearance.actionFill,
                            stroke: appearance.actionStroke
                        ) {
                            expandFromSwipe()
                        }
                        TodayRailButton(
                            palette: palette,
                            title: "Do first",
                            tint: appearance.actionTint,
                            fill: appearance.actionFill,
                            stroke: appearance.actionStroke
                        ) {
                            onDoFirst()
                            resetSwipeRail(animated: true)
                        }
                        if let onTogglePin {
                            TodayRailButton(
                                palette: palette,
                                title: item.isPinned == true ? "Unpin" : "Pin",
                                tint: appearance.pinTint,
                                fill: appearance.actionFill,
                                stroke: appearance.actionStroke
                            ) {
                                onTogglePin()
                                resetSwipeRail(animated: true)
                            }
                        }
                    }
                }
                .padding(.trailing, 14)
                .opacity(backwardSwipeProgress)
                .scaleEffect(0.96 + backwardSwipeProgress * 0.04, anchor: .trailing)
            }
    }

    private var tileSurface: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                TodayCategoryStamp(appearance: appearance, icon: categoryIcon)
                Spacer(minLength: 6)
                if let urgencyLabel {
                    TodayUrgencyBadge(appearance: appearance, title: urgencyLabel)
                }
                if item.isPinned == true {
                    OneAppIcon(
                        key: .ui(.pin),
                        size: 12,
                        tint: appearance.pinTint
                    )
                }
            }

            TodayTileTitleText(
                text: item.title,
                color: appearance.titleColor,
                baseSize: titleFontSize,
                preferredLineLimit: titleLineLimit
            )

            TodayTileSupportingText(
                text: item.subtitle ?? "Ready when you are",
                color: appearance.supportingColor
            )

            Spacer(minLength: 0)

            if isExpanded {
                TodayExpandedPanel(
                    palette: palette,
                    appearance: appearance,
                    quickActions: quickActions,
                    quickActionColumns: quickActionColumns,
                    notePreview: notePreview,
                    isPinned: item.isPinned == true,
                    detailDestination: detailDestination,
                    onReschedule: { action in
                        onReschedule(action)
                    },
                    onDoFirst: {
                        onDoFirst()
                    },
                    onTogglePin: onTogglePin
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(contentPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(tileBackground)
        .overlay(alignment: .topTrailing) {
            TodayTileAccentRibbon(appearance: appearance)
                .padding(.top, 9)
                .padding(.trailing, 10)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(
                    appearance.borderColor,
                    lineWidth: 1
                )
        )
        .shadow(
            color: appearance.shadowColor.opacity(item.prominence == .featured ? 0.5 : 0.32),
            radius: item.prominence == .featured ? 18 : 12,
            x: 0,
            y: item.prominence == .featured ? 10 : 7
        )
        .contentShape(Rectangle())
        .onTapGesture {
            guard completionVisualState == .idle else {
                return
            }
            resetSwipeRail(animated: true)
            onExpandToggle()
        }
    }

    private var completionConfirmationOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(appearance.completionOverlay.opacity(completionVisualState == .committing ? 1 : 0))

            VStack(spacing: 8) {
                Circle()
                    .fill(palette.oxfordLift.opacity(0.94))
                    .frame(width: 64, height: 64)
                    .overlay(
                        OneAppIcon(
                            key: .ui(.check),
                            size: 28,
                            tint: palette.amande
                        )
                    )
                Text("Completed")
                    .font(OneType.caption.weight(.semibold))
                    .foregroundStyle(palette.amandeGlow)
            }
            .scaleEffect(completionVisualState == .committing ? 1 : 0.82)
            .opacity(completionVisualState == .committing ? 1 : 0)
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var tileBackground: some View {
        switch placement.shapeStyle {
        case .asymmetricLeading:
            UnevenRoundedRectangle(
                cornerRadii: .init(
                    topLeading: 28,
                    bottomLeading: 20,
                    bottomTrailing: 28,
                    topTrailing: 18
                ),
                style: .continuous
            )
            .fill(backgroundFill)
        case .asymmetricTrailing:
            UnevenRoundedRectangle(
                cornerRadii: .init(
                    topLeading: 24,
                    bottomLeading: 30,
                    bottomTrailing: 18,
                    topTrailing: 30
                ),
                style: .continuous
            )
            .fill(backgroundFill)
        case .pill:
            Capsule(style: .continuous)
                .fill(backgroundFill)
        case .clipped:
            UnevenRoundedRectangle(
                cornerRadii: .init(
                    topLeading: 20,
                    bottomLeading: 28,
                    bottomTrailing: 18,
                    topTrailing: 30
                ),
                style: .continuous
            )
            .fill(backgroundFill)
        }
    }

    private var backgroundFill: some ShapeStyle {
        LinearGradient(
            colors: appearance.fillColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard completionVisualState == .idle, !isBusy else {
                    return
                }
                guard abs(value.translation.width) > abs(value.translation.height) else {
                    return
                }
                if dragOriginOffset == nil {
                    dragOriginOffset = settledOffset
                    liveOffset = settledOffset
                }
                let origin = dragOriginOffset ?? settledOffset
                liveOffset = TodaySwipeThresholds.clamped(origin + value.translation.width)
            }
            .onEnded { value in
                guard completionVisualState == .idle, !isBusy else {
                    return
                }
                defer {
                    dragOriginOffset = nil
                }
                guard let dragOriginOffset else {
                    return
                }
                guard abs(value.translation.width) > abs(value.translation.height) else {
                    resetSwipeRail(animated: true)
                    return
                }
                let measured = TodaySwipeThresholds.clamped(dragOriginOffset + value.translation.width)
                let projected = TodaySwipeThresholds.clamped(dragOriginOffset + value.predictedEndTranslation.width)
                let resolved = abs(projected - dragOriginOffset) > abs(measured - dragOriginOffset) ? projected : measured

                if resolved >= TodaySwipeThresholds.rightCommit {
                    completeFromSwipe()
                    return
                }

                if resolved <= TodaySwipeThresholds.leftCommit {
                    expandFromSwipe()
                    return
                }

                withAnimation(OneMotion.animation(.expand, reduceMotion: reduceMotion)) {
                    if resolved >= TodaySwipeThresholds.rightPreview {
                        settledOffset = TodaySwipeThresholds.rightSettled
                    } else if resolved <= TodaySwipeThresholds.leftActionsReveal {
                        settledOffset = TodaySwipeThresholds.leftSettled
                    } else {
                        settledOffset = 0
                    }
                    liveOffset = settledOffset
                }
            }
    }

    private func resetSwipeRail(animated: Bool) {
        let updates = {
            settledOffset = 0
            liveOffset = 0
            dragOriginOffset = nil
        }
        if animated {
            withAnimation(OneMotion.animation(.dismiss, reduceMotion: reduceMotion)) {
                updates()
            }
        } else {
            updates()
        }
    }

    private func completeFromSwipe() {
        guard completionVisualState == .idle else {
            return
        }
        withAnimation(OneMotion.animation(.milestone, reduceMotion: reduceMotion)) {
            completionVisualState = .committing
            settledOffset = min(placement.frame.width * 0.18, 38)
            liveOffset = settledOffset
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 50 : 120))
            onComplete()
        }
    }

    private func expandFromSwipe() {
        guard !isExpanded else {
            resetSwipeRail(animated: true)
            return
        }
        withAnimation(OneMotion.animation(.expand, reduceMotion: reduceMotion)) {
            settledOffset = TodaySwipeThresholds.leftSettled - 16
            liveOffset = settledOffset
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 40 : 90))
            resetSwipeRail(animated: true)
            onExpandToggle()
        }
    }
}

private struct TodayTileAccentRibbon: View {
    let appearance: TodayTileAppearance

    var body: some View {
        if appearance.accentRibbonOpacity > 0.01 {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: appearance.accentRibbonColors,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 18, height: 74)
                .opacity(appearance.accentRibbonOpacity)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(appearance.accentRibbonStroke, lineWidth: 0.5)
                )
        }
    }
}

private struct TodayCategoryStamp: View {
    let appearance: TodayTileAppearance
    let icon: OneIconKey

    var body: some View {
        OneIcon(
            key: icon,
            palette: OneTheme.palette(for: .dark),
            size: 15,
            tint: appearance.iconTint
        )
        .frame(width: 26, height: 26)
        .background(
            Circle()
                .fill(appearance.iconFill)
        )
        .overlay(
            Circle()
                .stroke(appearance.iconStroke, lineWidth: 1)
        )
    }
}

private struct TodayUrgencyBadge: View {
    let appearance: TodayTileAppearance
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(appearance.urgencyTint)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(appearance.urgencyFill)
            )
    }
}

private struct TodayQuickActionButton: View {
    let palette: TodaySurfacePalette
    let appearance: TodayTileAppearance
    let action: TodayQuickAction
    let onPress: () -> Void

    var body: some View {
        Button(action.label, action: onPress)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(appearance.actionTint)
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(appearance.actionFill)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(appearance.actionStroke, lineWidth: 1)
            )
            .buttonStyle(.plain)
            .onePressable(scale: 0.98)
            .accessibilityIdentifier("one.today.quick-action.\(action.id)")
    }
}

private struct TodayExpandedPanel: View {
    let palette: TodaySurfacePalette
    let appearance: TodayTileAppearance
    let quickActions: [TodayQuickAction]
    let quickActionColumns: [GridItem]
    let notePreview: String
    let isPinned: Bool
    let detailDestination: TodayItemDestinationContent
    let onReschedule: (TodayQuickAction) -> Void
    let onDoFirst: () -> Void
    let onTogglePin: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TodayExpandedSectionLabel(text: "Shift", palette: palette)

            LazyVGrid(columns: quickActionColumns, alignment: .leading, spacing: 6) {
                ForEach(quickActions) { action in
                    TodayQuickActionButton(palette: palette, appearance: appearance, action: action) {
                        onReschedule(action)
                    }
                }
            }

            TodayExpandedSectionLabel(text: "Notes", palette: palette)

            Text(notePreview.isEmpty ? "No notes attached yet." : notePreview)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(appearance.noteText)
                .lineLimit(3)
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(appearance.noteFill)
                )

            HStack(spacing: 8) {
                Button(action: onDoFirst) {
                    TodayExpandedUtilityLabel(
                        appearance: appearance,
                        title: "Do first",
                        icon: .ui(.doFirst),
                        tint: appearance.actionTint
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("one.today.expanded.do-first")

                if let onTogglePin {
                    Button(action: onTogglePin) {
                        TodayExpandedUtilityLabel(
                            appearance: appearance,
                            title: isPinned ? "Unpin" : "Pin",
                            icon: .ui(isPinned ? .unpin : .pin),
                            tint: appearance.pinTint
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("one.today.expanded.pin-toggle")
                }

                NavigationLink {
                    detailDestination
                } label: {
                    TodayExpandedUtilityLabel(
                        appearance: appearance,
                        title: "Details",
                        icon: .ui(.details),
                        tint: appearance.titleColor
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("one.today.expanded.details")
            }
        }
    }
}

private struct TodayRailButton: View {
    let palette: TodaySurfacePalette
    let title: String
    let tint: Color
    let fill: Color
    let stroke: Color
    let action: () -> Void

    private var accessibilityID: String {
        let slug = title.lowercased().replacingOccurrences(of: " ", with: "-")
        return "one.today.rail.\(slug)"
    }

    var body: some View {
        Button(title, action: action)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(fill)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(stroke, lineWidth: 1)
            )
            .buttonStyle(.plain)
            .accessibilityIdentifier(accessibilityID)
    }
}

private struct TodaySwipeProgressBar: View {
    let palette: TodaySurfacePalette
    let progress: CGFloat
    let tint: Color
    let track: Color
    let isArmed: Bool

    var body: some View {
        let clampedProgress = OneLayoutMath.unitInterval(progress)
        Capsule(style: .continuous)
            .fill(track)
            .frame(width: 80, height: 6)
            .overlay(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(tint.opacity(isArmed ? 1 : 0.82))
                    .frame(
                        width: OneLayoutMath.filledWidth(
                            containerWidth: 80,
                            fraction: clampedProgress,
                            minimumWhenVisible: 8
                        ),
                        height: 6
                    )
            }
            .overlay(
                Capsule(style: .continuous)
                    .stroke(tint.opacity(isArmed ? 0.48 : 0.2), lineWidth: 1)
            )
    }
}

private struct TodayExpandedSectionLabel: View {
    let text: String
    let palette: TodaySurfacePalette

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .tracking(0.7)
            .foregroundStyle(palette.headerMeta)
            .textCase(.uppercase)
    }
}

private struct TodayExpandedUtilityLabel: View {
    let appearance: TodayTileAppearance
    let title: String
    let icon: OneAppIconKey
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            OneAppIcon(
                key: icon,
                size: 11,
                tint: tint
            )
            Text(title)
                .font(OneType.caption.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(appearance.actionFill)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(appearance.actionStroke, lineWidth: 1)
        )
    }
}

private struct TodayTileTitleText: View {
    let text: String
    let color: Color
    let baseSize: CGFloat
    let preferredLineLimit: Int

    var body: some View {
        ViewThatFits(in: .vertical) {
            candidate(size: baseSize, lineLimit: preferredLineLimit)
            candidate(size: max(14, baseSize - 1.5), lineLimit: max(preferredLineLimit, 2))
            candidate(size: max(13, baseSize - 3), lineLimit: max(preferredLineLimit, 3))
        }
    }

    private func candidate(size: CGFloat, lineLimit: Int) -> some View {
        Text(text)
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .foregroundStyle(color)
            .lineLimit(lineLimit)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .minimumScaleFactor(0.85)
            .allowsTightening(false)
    }
}

private struct TodayTileSupportingText: View {
    let text: String
    let color: Color

    var body: some View {
        ViewThatFits(in: .vertical) {
            candidate(size: 12, lineLimit: 2)
            candidate(size: 11, lineLimit: 2)
            candidate(size: 10, lineLimit: 2)
        }
    }

    private func candidate(size: CGFloat, lineLimit: Int) -> some View {
        Text(text)
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(color)
            .lineLimit(lineLimit)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .minimumScaleFactor(0.88)
            .allowsTightening(false)
    }
}

private struct TodayQuietRowTitle: View {
    let text: String
    let palette: TodaySurfacePalette

    var body: some View {
        ViewThatFits(in: .vertical) {
            candidate(size: 14, lineLimit: 2)
            candidate(size: 13, lineLimit: 2)
            candidate(size: 12, lineLimit: 3)
        }
    }

    private func candidate(size: CGFloat, lineLimit: Int) -> some View {
        Text(text)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(palette.quietTitle)
            .lineLimit(lineLimit)
            .fixedSize(horizontal: false, vertical: true)
            .minimumScaleFactor(0.9)
            .allowsTightening(false)
    }
}

private struct TodayQuietRowSubtitle: View {
    let text: String
    let palette: TodaySurfacePalette

    var body: some View {
        ViewThatFits(in: .vertical) {
            candidate(size: 12, lineLimit: 2)
            candidate(size: 11, lineLimit: 2)
        }
    }

    private func candidate(size: CGFloat, lineLimit: Int) -> some View {
        Text(text)
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(palette.quietSupporting)
            .lineLimit(lineLimit)
            .fixedSize(horizontal: false, vertical: true)
            .minimumScaleFactor(0.9)
            .allowsTightening(false)
    }
}

private struct TodayReorderSheet: View {
    let palette: OneTheme.Palette
    let items: [TodayItem]
    let categoryName: (String) -> String
    let onDismiss: () -> Void
    let onSave: ([TodayItem]) async -> Void

    @State private var reorderedItems: [TodayItem]
    @Environment(\.dismiss) private var dismiss

    init(
        palette: OneTheme.Palette,
        items: [TodayItem],
        categoryName: @escaping (String) -> String,
        onDismiss: @escaping () -> Void,
        onSave: @escaping ([TodayItem]) async -> Void
    ) {
        self.palette = palette
        self.items = items
        self.categoryName = categoryName
        self.onDismiss = onDismiss
        self.onSave = onSave
        _reorderedItems = State(initialValue: items)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(reorderedItems) { item in
                    HStack(spacing: 12) {
                        OneAppIcon(
                            key: .ui(.dragHandle),
                            size: 14,
                            tint: palette.subtext
                        )
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.system(size: 15, weight: .semibold))
                            Text(categoryName(item.categoryId))
                                .font(OneType.caption)
                                .foregroundStyle(palette.subtext)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .onMove { source, destination in
                    reorderedItems.move(fromOffsets: source, toOffset: destination)
                }
            }
#if os(iOS)
            .environment(\.editMode, .constant(.active))
#endif
            .navigationTitle("Arrange Today")
            .toolbar {
                ToolbarItem(placement: .oneNavigationLeading) {
                    Button("Cancel") {
                        dismiss()
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .oneNavigationTrailing) {
                    Button("Save") {
                        Task {
                            await onSave(reorderedItems)
                            dismiss()
                            onDismiss()
                        }
                    }
                }
            }
        }
    }
}
