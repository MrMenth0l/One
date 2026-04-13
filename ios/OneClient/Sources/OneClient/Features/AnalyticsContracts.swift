#if canImport(SwiftUI)
import SwiftUI

public enum AnalyticsActivityFilter: String, CaseIterable, Sendable {
    case all
    case habits
    case todos

    public var title: String {
        switch self {
        case .all:
            return "All"
        case .habits:
            return "Habits"
        case .todos:
            return "Tasks"
        }
    }
}

public struct AnalyticsChartSeries: Sendable, Equatable {
    public let values: [Double]
    public let labels: [String]

    public init(values: [Double] = [], labels: [String] = []) {
        self.values = values
        self.labels = labels
    }
}

public struct AnalyticsContributionDayCell: Sendable, Equatable, Identifiable {
    public let dateLocal: String
    public let dayNumber: Int
    public let completionRate: Double
    public let hasSummary: Bool

    public var id: String { dateLocal }
}

public struct AnalyticsContributionMonthSection: Sendable, Equatable, Identifiable {
    public let month: Int
    public let label: String
    public let completedItems: Int
    public let expectedItems: Int
    public let leadingPlaceholders: Int
    public let days: [AnalyticsContributionDayCell]

    public var id: Int { month }
}

public struct AnalyticsSentimentDistributionItem: Sendable, Equatable, Identifiable {
    public let sentiment: ReflectionSentiment
    public let count: Int

    public var id: ReflectionSentiment { sentiment }
}

public struct AnalyticsSentimentTrendPoint: Sendable, Equatable, Identifiable {
    public let label: String
    public let sentiment: ReflectionSentiment?
    public let dateLocal: String?

    public var id: String { dateLocal ?? label }
}

public struct AnalyticsSentimentOverview: Sendable, Equatable {
    public let dominant: ReflectionSentiment?
    public let distribution: [AnalyticsSentimentDistributionItem]
    public let trend: [AnalyticsSentimentTrendPoint]
}

public struct AnalyticsMonthWeekBucket: Sendable, Equatable, Identifiable {
    public let week: Int
    public let title: String
    public let shortLabel: String
    public let completionRate: Double
    public let startDate: String
    public let endDate: String

    public var id: Int { week }
}

public struct AnalyticsExecutionSplitRow: Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let completedItems: Int
    public let expectedItems: Int
    public let completionRate: Double

    public init(id: String, title: String, completedItems: Int, expectedItems: Int, completionRate: Double) {
        self.id = id
        self.title = title
        self.completedItems = completedItems
        self.expectedItems = expectedItems
        self.completionRate = completionRate
    }
}

public struct AnalyticsRecoveryRow: Sendable, Equatable, Identifiable {
    public let id: String
    public let label: String
    public let completedItems: Int
    public let expectedItems: Int
    public let gap: Int
    public let completionRate: Double

    public init(
        id: String,
        label: String,
        completedItems: Int,
        expectedItems: Int,
        gap: Int,
        completionRate: Double
    ) {
        self.id = id
        self.label = label
        self.completedItems = completedItems
        self.expectedItems = expectedItems
        self.gap = gap
        self.completionRate = completionRate
    }
}

struct ReflectionSentimentVoteSummary: Sendable, Equatable {
    let dominant: ReflectionSentiment?
    let distribution: [AnalyticsSentimentDistributionItem]
}

func reflectionNoteSort(lhs: ReflectionNote, rhs: ReflectionNote) -> Bool {
    let lhsDate = lhs.updatedAt ?? lhs.createdAt ?? .distantPast
    let rhsDate = rhs.updatedAt ?? rhs.createdAt ?? .distantPast
    if lhsDate != rhsDate {
        return lhsDate > rhsDate
    }
    return lhs.id > rhs.id
}

func reflectionSentimentSummary(for notes: [ReflectionNote]) -> ReflectionSentimentVoteSummary {
    guard !notes.isEmpty else {
        return ReflectionSentimentVoteSummary(dominant: nil, distribution: [])
    }

    let sortedNotes = notes.sorted(by: reflectionNoteSort(lhs:rhs:))
    let counts = sortedNotes.reduce(into: [ReflectionSentiment: Int]()) { partial, note in
        partial[note.sentiment, default: 0] += 1
    }
    let maxCount = counts.values.max() ?? 0
    let tiedSentiments = Set(
        counts.compactMap { sentiment, count in
            count == maxCount ? sentiment : nil
        }
    )
    let dominant = sortedNotes.first(where: { tiedSentiments.contains($0.sentiment) })?.sentiment
    let distribution: [AnalyticsSentimentDistributionItem] = ReflectionSentiment.allCases.compactMap { sentiment -> AnalyticsSentimentDistributionItem? in
        let count = counts[sentiment, default: 0]
        guard count > 0 else {
            return nil
        }
        return AnalyticsSentimentDistributionItem(sentiment: sentiment, count: count)
    }

    return ReflectionSentimentVoteSummary(
        dominant: dominant,
        distribution: distribution
    )
}
#endif
