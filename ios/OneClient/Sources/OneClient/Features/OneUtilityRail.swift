#if canImport(SwiftUI)
import SwiftUI

struct OneUtilityRailItem<ID: Hashable & Sendable>: Identifiable, Hashable, Sendable {
    let id: ID
    let title: String
    let systemImage: String
}

struct OneUtilityRailAnchor<ID: Hashable & Sendable>: Hashable, Sendable {
    let sectionID: ID
}

struct OneUtilityRailSectionObservation<ID: Hashable & Sendable>: Equatable, Sendable {
    let id: ID
    let minY: CGFloat
    let maxY: CGFloat
}

enum OneUtilityRailSectionResolver {
    static func resolve<ID: Hashable & Sendable>(
        current: ID?,
        sections: [OneUtilityRailSectionObservation<ID>],
        activationY: CGFloat,
        hysteresis: CGFloat
    ) -> ID? {
        guard !sections.isEmpty else {
            return current
        }

        if let current,
           let currentSection = sections.first(where: { $0.id == current }) {
            let expandedLowerBound = currentSection.minY - hysteresis
            let expandedUpperBound = currentSection.maxY + hysteresis
            if activationY >= expandedLowerBound, activationY < expandedUpperBound {
                return current
            }
        }

        let ordered = sections.sorted { lhs, rhs in
            if lhs.minY == rhs.minY {
                return lhs.maxY < rhs.maxY
            }
            return lhs.minY < rhs.minY
        }

        for section in ordered {
            if activationY >= section.minY, activationY < section.maxY {
                return section.id
            }
        }

        if let firstVisible = ordered.last(where: { $0.minY <= activationY }) {
            return firstVisible.id
        }

        return ordered.first?.id ?? current
    }
}

enum OneUtilityRailMetrics {
    static let stickyTopPadding: CGFloat = 8
    static let stickyHorizontalInset: CGFloat = 18
    static let persistentTopInset: CGFloat = 60
    static let stickyActivationThreshold: CGFloat = 12
    static let stickyFadeDistance: CGFloat = 20
    static let activationY: CGFloat = 60
    static let hysteresis: CGFloat = 24
    static let anchorOffset: CGFloat = 58
}

enum ReviewUtilityRailSection: String, CaseIterable, Sendable {
    case review
    case notes
    case coach
    case trend
    case split
    case recovery

    var railItem: OneUtilityRailItem<Self> {
        switch self {
        case .review:
            return OneUtilityRailItem(id: self, title: "Review", systemImage: "doc.text.magnifyingglass")
        case .notes:
            return OneUtilityRailItem(id: self, title: "Notes", systemImage: "note.text")
        case .coach:
            return OneUtilityRailItem(id: self, title: "Coach", systemImage: "bubble.left.and.text.bubble.right")
        case .trend:
            return OneUtilityRailItem(id: self, title: "Trend", systemImage: "chart.line.uptrend.xyaxis")
        case .split:
            return OneUtilityRailItem(id: self, title: "Split", systemImage: "rectangle.split.3x1")
        case .recovery:
            return OneUtilityRailItem(id: self, title: "Recovery", systemImage: "arrow.counterclockwise.circle")
        }
    }

    static var railItems: [OneUtilityRailItem<Self>] {
        Self.allCases.map(\.railItem)
    }
}

enum FinanceUtilityRailSection: String, CaseIterable, Sendable {
    case home
    case transactions
    case reports
    case recurring
    case categories

    var railItem: OneUtilityRailItem<Self> {
        switch self {
        case .home:
            return OneUtilityRailItem(id: self, title: "Home", systemImage: "creditcard")
        case .transactions:
            return OneUtilityRailItem(id: self, title: "Transactions", systemImage: "list.bullet.rectangle.portrait")
        case .reports:
            return OneUtilityRailItem(id: self, title: "Reports", systemImage: "chart.bar.xaxis")
        case .recurring:
            return OneUtilityRailItem(id: self, title: "Recurring", systemImage: "repeat.circle")
        case .categories:
            return OneUtilityRailItem(id: self, title: "Categories", systemImage: "square.grid.2x2.fill")
        }
    }

    static var railItems: [OneUtilityRailItem<Self>] {
        Self.allCases.map(\.railItem)
    }
}

struct OneUtilityRail<ID: Hashable & Sendable>: View {
    let palette: OneTheme.Palette
    let items: [OneUtilityRailItem<ID>]
    let activeID: ID?
    let isSticky: Bool
    let onSelect: (ID) -> Void

    @State private var chipFrames: [AnyHashable: CGRect] = [:]
    @State private var viewportFrame: CGRect = .zero
    @State private var pendingTapSelection: ID?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(items) { item in
                        Button {
                            pendingTapSelection = item.id
                            onSelect(item.id)
                        } label: {
                            chip(for: item, isActive: activeID == item.id)
                        }
                        .buttonStyle(.plain)
                        .id(item.id)
                        .background(
                            GeometryReader { proxy in
                                Color.clear.preference(
                                    key: OneUtilityRailChipFramePreferenceKey.self,
                                    value: [AnyHashable(item.id): proxy.frame(in: .named(OneUtilityRailChipViewportPreferenceKey.coordinateSpaceName))]
                                )
                            }
                        )
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 6)
                .padding(.vertical, isSticky ? 5 : 6)
            }
            .coordinateSpace(name: OneUtilityRailChipViewportPreferenceKey.coordinateSpaceName)
            .scrollTargetBehavior(.viewAligned)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: OneUtilityRailChipViewportPreferenceKey.self,
                        value: proxy.frame(in: .named(OneUtilityRailChipViewportPreferenceKey.coordinateSpaceName))
                    )
                }
            )
            .background(containerBackground)
            .clipShape(RoundedRectangle(cornerRadius: OneTheme.radiusLarge, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: OneTheme.radiusLarge, style: .continuous)
                    .stroke(isSticky ? palette.glassStroke : palette.border, lineWidth: 1)
            )
            .shadow(color: palette.shadowColor.opacity(isSticky ? 1 : 0.75), radius: isSticky ? 12 : 6, x: 0, y: isSticky ? 5 : 2)
            .scaleEffect(isSticky ? 0.985 : 1)
            .onPreferenceChange(OneUtilityRailChipFramePreferenceKey.self) { chipFrames = $0 }
            .onPreferenceChange(OneUtilityRailChipViewportPreferenceKey.self) { viewportFrame = $0 }
            .onChange(of: activeID) { _, next in
                guard let next else {
                    return
                }
                let tapped = pendingTapSelection == next
                pendingTapSelection = nil

                guard tapped || isChipOffscreen(next) else {
                    return
                }

                withAnimation(OneMotion.animation(.stateChange, reduceMotion: reduceMotion)) {
                    proxy.scrollTo(next, anchor: .center)
                }
            }
        }
        .frame(height: isSticky ? 42 : 44)
        .animation(
            OneMotion.animation(.stateChange, reduceMotion: reduceMotion),
            value: activeID
        )
    }

    private var containerBackground: some View {
        RoundedRectangle(cornerRadius: OneTheme.radiusLarge, style: .continuous)
            .fill(isSticky ? palette.glass : palette.surface.opacity(palette.isDark ? 0.92 : 0.96))
    }

    private func chip(for item: OneUtilityRailItem<ID>, isActive: Bool) -> some View {
        HStack(spacing: 7) {
            Image(systemName: item.systemImage)
                .font(.system(size: 13, weight: isActive ? .semibold : .medium))
            Text(item.title)
                .font(.system(size: 12, weight: isActive ? .semibold : .medium))
                .lineLimit(1)
        }
        .foregroundStyle(isActive ? palette.text : palette.subtext)
        .padding(.horizontal, 11)
        .padding(.vertical, isSticky ? 7 : 8)
        .background(
            RoundedRectangle(cornerRadius: OneTheme.radiusMedium, style: .continuous)
                .fill(isActive ? palette.surfaceStrong.opacity(palette.isDark ? 0.8 : 0.85) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: OneTheme.radiusMedium, style: .continuous)
                .stroke(isActive ? palette.border.opacity(0.85) : Color.clear, lineWidth: 1)
        )
        .shadow(
            color: isActive ? palette.shadowColor.opacity(palette.isDark ? 0.6 : 0.14) : .clear,
            radius: isActive ? 4 : 0,
            x: 0,
            y: isActive ? 2 : 0
        )
        .contentShape(RoundedRectangle(cornerRadius: OneTheme.radiusMedium, style: .continuous))
    }

    private func isChipOffscreen(_ id: ID) -> Bool {
        let key = AnyHashable(id)
        guard let frame = chipFrames[key], viewportFrame != .zero else {
            return false
        }
        return frame.minX < viewportFrame.minX || frame.maxX > viewportFrame.maxX
    }
}

private struct OneUtilityRailChipFramePreferenceKey: PreferenceKey {
    static var defaultValue: [AnyHashable: CGRect] { [:] }

    static func reduce(value: inout [AnyHashable: CGRect], nextValue: () -> [AnyHashable: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}

private struct OneUtilityRailChipViewportPreferenceKey: PreferenceKey {
    static let coordinateSpaceName = "one-utility-rail-chip-space"
    static var defaultValue: CGRect { .zero }

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

struct OneUtilityRailSectionFramePreferenceKey: PreferenceKey {
    static var defaultValue: [AnyHashable: CGRect] { [:] }

    static func reduce(value: inout [AnyHashable: CGRect], nextValue: () -> [AnyHashable: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}

struct OneUtilityRailInlineFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat { .greatestFiniteMagnitude }

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension View {
    func oneUtilityRailMeasuredSection<ID: Hashable & Sendable>(_ id: ID) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: OneUtilityRailSectionFramePreferenceKey.self,
                    value: [AnyHashable(id): proxy.frame(in: .named("one-scroll-screen"))]
                )
            }
        )
    }

    func oneUtilityRailInlineTrigger() -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: OneUtilityRailInlineFramePreferenceKey.self,
                    value: proxy.frame(in: .named("one-scroll-screen")).minY
                )
            }
        )
    }
}

#endif
