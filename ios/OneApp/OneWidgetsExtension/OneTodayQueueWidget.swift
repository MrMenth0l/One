import SwiftUI
import WidgetKit
import OneClient

private struct OneWidgetPalette {
    let background: Color
    let surface: Color
    let border: Color
    let text: Color
    let subtext: Color
    let accent: Color
    let accentSoft: Color
    let taskTint: Color
    let habitTint: Color
    let warningTint: Color
    let dangerTint: Color
    let usesAccentRendering: Bool

    static func resolve(colorScheme: ColorScheme, renderingMode: WidgetRenderingMode) -> OneWidgetPalette {
        if renderingMode != .fullColor {
            let surface = colorScheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.72)
            let border = colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
            let text = colorScheme == .dark ? Color.white : Color.black.opacity(0.88)
            let subtext = colorScheme == .dark ? Color.white.opacity(0.74) : Color.black.opacity(0.62)
            let accent = colorScheme == .dark ? Color.white : Color.black.opacity(0.84)
            return OneWidgetPalette(
                background: colorScheme == .dark ? Color.black.opacity(0.28) : Color.white.opacity(0.22),
                surface: surface,
                border: border,
                text: text,
                subtext: subtext,
                accent: accent,
                accentSoft: surface,
                taskTint: accent,
                habitTint: accent,
                warningTint: accent,
                dangerTint: accent,
                usesAccentRendering: true
            )
        }

        if colorScheme == .dark {
            return OneWidgetPalette(
                background: Color(hex: 0x11161D),
                surface: Color(hex: 0x1A222D),
                border: Color.white.opacity(0.08),
                text: Color(hex: 0xF3F6FA),
                subtext: Color(hex: 0xA5B0BD),
                accent: Color(hex: 0x8FB0CC),
                accentSoft: Color(hex: 0x8FB0CC, alpha: 0.18),
                taskTint: Color(hex: 0x8FB0CC),
                habitTint: Color(hex: 0xA4BC77),
                warningTint: Color(hex: 0xE0B170),
                dangerTint: Color(hex: 0xDD8D80),
                usesAccentRendering: false
            )
        }

        return OneWidgetPalette(
            background: Color(hex: 0xF4F6F8),
            surface: Color.white,
            border: Color(hex: 0x111827, alpha: 0.08),
            text: Color(hex: 0x18202A),
            subtext: Color(hex: 0x667485),
            accent: Color(hex: 0x4D6F8C),
            accentSoft: Color(hex: 0x4D6F8C, alpha: 0.12),
            taskTint: Color(hex: 0x4D6F8C),
            habitTint: Color(hex: 0x7B8E58),
            warningTint: Color(hex: 0xB78545),
            dangerTint: Color(hex: 0xC0675A),
            usesAccentRendering: false
        )
    }
}

struct OneTodayQueueEntry: TimelineEntry {
    let date: Date
    let payload: OneWidgetSnapshotPayload
}

struct OneTodayQueueProvider: TimelineProvider {
    private let reader = OneWidgetSnapshotReader()

    func placeholder(in context: Context) -> OneTodayQueueEntry {
        OneTodayQueueEntry(
            date: Date(),
            payload: .ready(
                todayQueue: OneWidgetQueueSnapshot(
                    dateLocal: "2026-01-01",
                    items: [
                        OneWidgetQueueItem(
                            itemType: .todo,
                            itemId: "placeholder-task",
                            dateLocal: "2026-01-01",
                            title: "Submit project draft",
                            subtitle: "Due today",
                            categoryName: "School",
                            categoryIcon: .categorySchool,
                            urgency: .dueToday,
                            timeBucket: .midday,
                            isPinned: true
                        ),
                        OneWidgetQueueItem(
                            itemType: .habit,
                            itemId: "placeholder-habit",
                            dateLocal: "2026-01-01",
                            title: "Morning workout",
                            subtitle: "Mornings",
                            categoryName: "Gym",
                            categoryIcon: .categoryGym,
                            urgency: .soon,
                            timeBucket: .morning,
                            isPinned: false
                        ),
                    ],
                    completedCount: 2,
                    totalCount: 4,
                    isConfigured: true
                )
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (OneTodayQueueEntry) -> Void) {
        completion(
            OneTodayQueueEntry(
                date: Date(),
                payload: context.isPreview ? placeholder(in: context).payload : reader.load()
            )
        )
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<OneTodayQueueEntry>) -> Void) {
        let now = Date()
        let entry = OneTodayQueueEntry(
            date: now,
            payload: reader.load()
        )
        completion(
            Timeline(
                entries: [entry],
                policy: .after(OneTodayQueueRefreshSchedule.nextRefreshDate(after: now))
            )
        )
    }
}

private enum OneTodayQueueRefreshSchedule {
    static func nextRefreshDate(after referenceDate: Date) -> Date {
        let calendar = Calendar.autoupdatingCurrent
        let boundaries = [(11, 0), (16, 0), (22, 0)]
        for (hour, minute) in boundaries {
            if let candidate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: referenceDate),
               candidate > referenceDate {
                return candidate
            }
        }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: referenceDate) ?? referenceDate
        return calendar.date(bySettingHour: 6, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }
}

struct OneTodayQueueWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: OneWidgetKind.todayQueue, provider: OneTodayQueueProvider()) { entry in
            OneTodayQueueWidgetView(entry: entry)
        }
        .configurationDisplayName("Today Queue")
        .description("A ranked operational queue of today's tasks and habits.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

private struct OneTodayQueueWidgetView: View {
    let entry: OneTodayQueueEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var palette: OneWidgetPalette {
        OneWidgetPalette.resolve(colorScheme: colorScheme, renderingMode: renderingMode)
    }

    private var visibleItems: [OneWidgetQueueItem] {
        Array(entry.payload.todayQueue.items.prefix(itemLimit))
    }

    private var itemLimit: Int {
        switch family {
        case .systemSmall:
            return 2
        case .systemLarge:
            return 6
        default:
            return 4
        }
    }

    private var remainingCount: Int {
        entry.payload.todayQueue.items.count
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(palette.background)

            VStack(alignment: .leading, spacing: 12) {
                header

                switch entry.payload.configurationState {
                case .needsAppLaunch:
                    emptyState(
                        title: "Open One",
                        detail: "Launch the app once to restore your local profile and queue."
                    )
                case .signedOut:
                    emptyState(
                        title: "Signed out",
                        detail: "Open One to continue with your local queue."
                    )
                case .ready:
                    if visibleItems.isEmpty {
                        emptyState(
                            title: "Flow is clear",
                            detail: entry.payload.todayQueue.totalCount == 0
                                ? "Nothing is scheduled for today."
                                : "\(entry.payload.todayQueue.completedCount) cleared. The rest is quiet."
                        )
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(visibleItems) { item in
                                Link(destination: item.routeURL) {
                                    OneTodayQueueRow(item: item, palette: palette)
                                }
                            }
                        }
                    }
                }

                Spacer(minLength: 0)

                footer
            }
            .padding(16)
        }
        .containerBackground(palette.background, for: .widget)
        .widgetURL(defaultRouteURL)
    }

    private var defaultRouteURL: URL {
        visibleItems.first?.routeURL ?? OneSystemRoute.addNote(anchorDate: nil).url()
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("One")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.subtext)
                Text("Today Queue")
                    .font(.system(size: family == .systemSmall ? 15 : 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.text)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text("\(remainingCount)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(palette.accentSoft)
                )
                .widgetAccentable(palette.usesAccentRendering)
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Text(footerLeadText)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(palette.subtext)
            Circle()
                .fill(palette.border)
                .frame(width: 3, height: 3)
            Text(footerDetailText)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(palette.subtext)
                .lineLimit(1)
        }
    }

    private var footerLeadText: String {
        switch entry.payload.configurationState {
        case .ready:
            return entry.payload.todayQueue.completedCount == 0
                ? "Operational"
                : "\(entry.payload.todayQueue.completedCount) cleared"
        case .needsAppLaunch:
            return "Needs setup"
        case .signedOut:
            return "Signed out"
        }
    }

    private var footerDetailText: String {
        switch entry.payload.configurationState {
        case .ready:
            return "Tap to confirm in One"
        case .needsAppLaunch, .signedOut:
            return "Open One to refresh"
        }
    }

    private func emptyState(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.text)
            Text(detail)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(palette.subtext)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        )
    }
}

private struct OneTodayQueueRow: View {
    let item: OneWidgetQueueItem
    let palette: OneWidgetPalette

    private var symbolName: String {
        switch item.itemType {
        case .todo:
            return "checklist"
        case .habit:
            return "repeat.circle.fill"
        case .reflection:
            return "square.and.pencil"
        }
    }

    private var iconTint: Color {
        switch item.itemType {
        case .todo:
            return palette.taskTint
        case .habit:
            return palette.habitTint
        case .reflection:
            return palette.accent
        }
    }

    private var urgencyText: String? {
        switch item.urgency {
        case .none:
            return item.isPinned ? "Pinned" : nil
        case .soon:
            return "Soon"
        case .dueToday:
            return "Today"
        case .overdue:
            return "Overdue"
        }
    }

    private var urgencyTint: Color {
        switch item.urgency {
        case .none:
            return palette.accent
        case .soon:
            return palette.warningTint
        case .dueToday:
            return palette.warningTint
        case .overdue:
            return palette.dangerTint
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(iconTint.opacity(0.14))
                Image(systemName: symbolName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconTint)
                    .widgetAccentable(palette.usesAccentRendering)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.text)
                    .lineLimit(1)

                Text(secondaryLine)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(palette.subtext)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if let urgencyText {
                Text(urgencyText)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(urgencyTint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(urgencyTint.opacity(0.13))
                    )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        )
    }

    private var secondaryLine: String {
        if let subtitle = item.subtitle, !subtitle.isEmpty {
            return subtitle
        }
        return item.categoryName
    }
}
