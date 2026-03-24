import XCTest
import CoreGraphics
@testable import OneClient

final class UtilityRailTests: XCTestCase {
    func testReviewRailItemsMatchPlannedOrder() {
        XCTAssertEqual(
            ReviewUtilityRailSection.railItems.map(\.title),
            ["Review", "Notes", "Coach", "Trend", "Split", "Recovery"]
        )
        XCTAssertEqual(
            ReviewUtilityRailSection.railItems.map(\.id),
            [.review, .notes, .coach, .trend, .split, .recovery]
        )
    }

    func testFinanceRailItemsMatchPlannedOrder() {
        XCTAssertEqual(
            FinanceUtilityRailSection.railItems.map(\.title),
            ["Home", "Transactions", "Reports", "Recurring", "Categories"]
        )
        XCTAssertEqual(
            FinanceUtilityRailSection.railItems.map(\.id),
            [.home, .transactions, .reports, .recurring, .categories]
        )
    }

    func testUtilityRailResolverDefaultsToFirstSection() {
        let sections = [
            OneUtilityRailSectionObservation(id: ReviewUtilityRailSection.review, minY: 0, maxY: 240),
            OneUtilityRailSectionObservation(id: ReviewUtilityRailSection.notes, minY: 260, maxY: 520),
            OneUtilityRailSectionObservation(id: ReviewUtilityRailSection.coach, minY: 540, maxY: 760),
        ]

        let resolved = OneUtilityRailSectionResolver.resolve(
            current: nil as ReviewUtilityRailSection?,
            sections: sections,
            activationY: OneUtilityRailMetrics.activationY,
            hysteresis: OneUtilityRailMetrics.hysteresis
        )

        XCTAssertEqual(resolved, .review)
    }

    func testUtilityRailResolverKeepsCurrentSectionInsideHysteresisBand() {
        let sections = [
            OneUtilityRailSectionObservation(id: ReviewUtilityRailSection.review, minY: 0, maxY: 220),
            OneUtilityRailSectionObservation(id: ReviewUtilityRailSection.notes, minY: 240, maxY: 460),
            OneUtilityRailSectionObservation(id: ReviewUtilityRailSection.coach, minY: 480, maxY: 720),
        ]

        let resolved = OneUtilityRailSectionResolver.resolve(
            current: .notes,
            sections: sections,
            activationY: 225,
            hysteresis: OneUtilityRailMetrics.hysteresis
        )

        XCTAssertEqual(resolved, .notes)
    }

    func testUtilityRailResolverAdvancesAfterCrossingIntoNextSection() {
        let sections = [
            OneUtilityRailSectionObservation(id: FinanceUtilityRailSection.home, minY: 0, maxY: 210),
            OneUtilityRailSectionObservation(id: FinanceUtilityRailSection.transactions, minY: 230, maxY: 480),
            OneUtilityRailSectionObservation(id: FinanceUtilityRailSection.reports, minY: 500, maxY: 820),
        ]

        let resolved = OneUtilityRailSectionResolver.resolve(
            current: .transactions,
            sections: sections,
            activationY: 540,
            hysteresis: OneUtilityRailMetrics.hysteresis
        )

        XCTAssertEqual(resolved, .reports)
    }
}
