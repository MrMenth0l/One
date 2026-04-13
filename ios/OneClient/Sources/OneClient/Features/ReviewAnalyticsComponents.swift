#if canImport(SwiftUI)
import SwiftUI

struct SummaryMetricTile: View {
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

struct ReviewEquationStrip: View {
    let palette: OneTheme.Palette
    let title: String
    let equation: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(OneType.caption.weight(.semibold))
                .foregroundStyle(palette.subtext)
            Text(equation)
                .font(OneType.secondary.weight(.semibold))
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

struct ReviewTableHeader: View {
    let palette: OneTheme.Palette
    let columns: [String]

    var body: some View {
        HStack(spacing: OneSpacing.sm) {
            ForEach(columns, id: \.self) { column in
                Text(column)
                    .font(OneType.caption.weight(.semibold))
                    .foregroundStyle(palette.subtext)
                    .frame(maxWidth: .infinity, alignment: column == columns.first ? .leading : .trailing)
            }
        }
    }
}

struct ReviewExecutionRow: View {
    let palette: OneTheme.Palette
    let row: AnalyticsExecutionSplitRow

    var body: some View {
        HStack(spacing: OneSpacing.sm) {
            Text(row.title)
                .font(OneType.body.weight(.semibold))
                .foregroundStyle(palette.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(row.completedItems)")
                .font(OneType.secondary)
                .foregroundStyle(palette.text)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text("\(row.expectedItems)")
                .font(OneType.secondary)
                .foregroundStyle(palette.text)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text("\(Int((row.completionRate * 100).rounded()))%")
                .font(OneType.secondary.weight(.semibold))
                .foregroundStyle(palette.subtext)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }
}

struct ReviewRecoveryRow: View {
    let palette: OneTheme.Palette
    let row: AnalyticsRecoveryRow

    var body: some View {
        HStack(spacing: OneSpacing.sm) {
            Text(row.label)
                .font(OneType.body.weight(.semibold))
                .foregroundStyle(palette.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(row.gap)")
                .font(OneType.secondary.weight(.semibold))
                .foregroundStyle(row.gap > 0 ? palette.warning : palette.subtext)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text("\(row.completedItems)/\(row.expectedItems)")
                .font(OneType.secondary)
                .foregroundStyle(palette.text)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text("\(Int((row.completionRate * 100).rounded()))%")
                .font(OneType.secondary.weight(.semibold))
                .foregroundStyle(palette.subtext)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }
}

struct AnalyticsYearContributionView: View {
    let palette: OneTheme.Palette
    let sections: [AnalyticsContributionMonthSection]
    let onSelectDate: (String) -> Void
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(sections) { section in
                    AnalyticsMonthContributionSection(
                        palette: palette,
                        section: section,
                        onSelectDate: onSelectDate
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct AnalyticsMonthContributionSection: View {
    let palette: OneTheme.Palette
    let section: AnalyticsContributionMonthSection
    let onSelectDate: (String) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(section.label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.text)
                Spacer()
                Text("\(section.completedItems)/\(section.expectedItems)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(palette.subtext)
            }

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(palette.subtext)
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(0..<section.leadingPlaceholders).map { "placeholder-\($0)" }, id: \.self) { _ in
                    Color.clear
                        .frame(height: 16)
                }

                ForEach(section.days) { day in
                    Button {
                        onSelectDate(day.dateLocal)
                    } label: {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(contributionFill(for: day.completionRate, palette: palette))
                            .frame(height: 16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(palette.border.opacity(0.55), lineWidth: 0.5)
                            )
                            .overlay {
                                Text("\(day.dayNumber)")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundStyle(palette.text.opacity(day.hasSummary ? 0.78 : 0.45))
                            }
                    }
                    .onePressable(scale: 0.96, opacity: 0.92)
                }
            }
        }
        .padding(10)
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

struct AnalyticsContributionGrid: View {
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

struct AnalyticsSentimentOverviewView: View {
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
            OneAppIcon(
                key: point.sentiment.map { .ui($0.iconKey) } ?? .ui(.placeholder),
                size: 15,
                tint: point.sentiment?.tint(in: palette) ?? palette.subtext
            )
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

func contributionFill(for rate: Double, palette: OneTheme.Palette) -> Color {
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
#endif
