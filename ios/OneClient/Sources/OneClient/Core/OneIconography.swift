import Foundation

public enum OneIconKey: String, CaseIterable, Codable, Sendable, Hashable {
    case brandMark = "brand.mark"
    case today = "nav.today"
    case review = "nav.review"
    case finance = "nav.finance"
    case settings = "nav.settings"

    case task = "product.task"
    case habit = "product.habit"
    case note = "product.note"
    case reflection = "product.reflection"
    case coach = "product.coach"
    case bibleVerse = "product.bible-verse"
    case analytics = "product.analytics"
    case progress = "product.progress"
    case streak = "product.streak"
    case dailyReview = "review.daily"
    case weeklyReview = "review.weekly"
    case monthlyReview = "review.monthly"
    case yearlyReview = "review.yearly"
    case notifications = "support.notifications"
    case profile = "support.profile"

    case categoryGeneric = "category.generic"
    case categoryGym = "category.gym"
    case categorySchool = "category.school"
    case categoryProjects = "category.projects"
    case categoryWellbeing = "category.wellbeing"
    case categoryLifeAdmin = "category.life-admin"
    case categoryFaith = "category.faith"
    case categoryFinance = "category.finance"

    case financeCategory = "finance.category"
    case financeFood = "finance.food"
    case financeTransport = "finance.transport"
    case financeShopping = "finance.shopping"
    case financeEntertainment = "finance.entertainment"
    case financeSubscriptions = "finance.subscriptions"
    case financeBills = "finance.bills"
    case financeHealth = "finance.health"
    case financeEducation = "finance.education"
    case financeGifts = "finance.gifts"
    case financeSavings = "finance.savings"
    case financeMisc = "finance.misc"
    case income = "finance.income"
    case expense = "finance.expense"
    case transfer = "finance.transfer"
    case transaction = "finance.transaction"

    case completedDay = "state.completed-day"
    case incompleteDay = "state.incomplete-day"
    case milestone = "state.milestone"
    case streakMaintained = "state.streak-maintained"
    case streakBroken = "state.streak-broken"
    case noteAdded = "state.note-added"
    case reflectionCompleted = "state.reflection-completed"
    case noData = "state.no-data"
    case noNotes = "state.no-notes"
    case noHabits = "state.no-habits"
    case noTransactions = "state.no-transactions"
    case coachInsight = "state.coach-insight"
    case reminder = "state.reminder"
    case success = "state.success"
    case warning = "state.warning"
    case error = "state.error"
    case offline = "state.offline"
    case sync = "state.sync"
    case archive = "state.archive"
}

public extension OneIconKey {
    static let financeCategoryPickerKeys: [Self] = [
        .financeCategory,
        .financeFood,
        .financeTransport,
        .financeShopping,
        .financeEntertainment,
        .financeSubscriptions,
        .financeBills,
        .financeHealth,
        .financeEducation,
        .financeGifts,
        .financeSavings,
        .financeMisc
    ]

    var accessibilityLabel: String {
        switch self {
        case .brandMark:
            return "ONE brand mark"
        case .today:
            return "Today"
        case .review:
            return "Review"
        case .finance:
            return "Finance"
        case .settings:
            return "Settings"
        case .task:
            return "Task"
        case .habit:
            return "Habit"
        case .note:
            return "Note"
        case .reflection:
            return "Reflection"
        case .coach:
            return "Coach"
        case .bibleVerse:
            return "Bible verse"
        case .analytics:
            return "Analytics"
        case .progress:
            return "Progress"
        case .streak:
            return "Streak"
        case .dailyReview:
            return "Daily review"
        case .weeklyReview:
            return "Weekly review"
        case .monthlyReview:
            return "Monthly review"
        case .yearlyReview:
            return "Yearly review"
        case .notifications:
            return "Notifications"
        case .profile:
            return "Profile"
        case .categoryGeneric:
            return "Category"
        case .categoryGym:
            return "Gym"
        case .categorySchool:
            return "School"
        case .categoryProjects:
            return "Personal projects"
        case .categoryWellbeing:
            return "Wellbeing"
        case .categoryLifeAdmin:
            return "Life admin"
        case .categoryFaith:
            return "Faith"
        case .categoryFinance:
            return "Finance category"
        case .financeCategory:
            return "Finance category"
        case .financeFood:
            return "Food"
        case .financeTransport:
            return "Transport"
        case .financeShopping:
            return "Shopping"
        case .financeEntertainment:
            return "Entertainment"
        case .financeSubscriptions:
            return "Subscriptions"
        case .financeBills:
            return "Bills"
        case .financeHealth:
            return "Health"
        case .financeEducation:
            return "Education"
        case .financeGifts:
            return "Gifts"
        case .financeSavings:
            return "Savings"
        case .financeMisc:
            return "Miscellaneous"
        case .income:
            return "Income"
        case .expense:
            return "Expense"
        case .transfer:
            return "Transfer"
        case .transaction:
            return "Transaction"
        case .completedDay:
            return "Completed day"
        case .incompleteDay:
            return "Incomplete day"
        case .milestone:
            return "Milestone"
        case .streakMaintained:
            return "Streak maintained"
        case .streakBroken:
            return "Streak broken"
        case .noteAdded:
            return "Note added"
        case .reflectionCompleted:
            return "Reflection completed"
        case .noData:
            return "No data"
        case .noNotes:
            return "No notes"
        case .noHabits:
            return "No habits"
        case .noTransactions:
            return "No transactions"
        case .coachInsight:
            return "Coach insight"
        case .reminder:
            return "Reminder"
        case .success:
            return "Success"
        case .warning:
            return "Warning"
        case .error:
            return "Error"
        case .offline:
            return "Offline"
        case .sync:
            return "Sync"
        case .archive:
            return "Archive"
        }
    }

    var tabBarFallbackSystemName: String {
        switch self {
        case .today:
            return "checklist"
        case .review:
            return "chart.line.uptrend.xyaxis"
        case .finance:
            return "creditcard"
        case .settings:
            return "gearshape"
        default:
            return "circle"
        }
    }

    static func defaultTaskCategory(for name: String) -> Self {
        switch normalizedName(name) {
        case "gym":
            return .categoryGym
        case "school":
            return .categorySchool
        case "personal projects", "projects", "personal project":
            return .categoryProjects
        case "wellbeing", "well-being", "health":
            return .categoryWellbeing
        case "life admin", "admin":
            return .categoryLifeAdmin
        case "faith", "faith / spiritual", "spiritual":
            return .categoryFaith
        case "finance":
            return .categoryFinance
        default:
            return .categoryGeneric
        }
    }

    static func defaultFinanceCategory(for name: String?) -> Self {
        switch normalizedName(name ?? "") {
        case "food":
            return .financeFood
        case "gas / transport", "transport", "gas", "travel":
            return .financeTransport
        case "shopping":
            return .financeShopping
        case "entertainment":
            return .financeEntertainment
        case "subscriptions", "subscription":
            return .financeSubscriptions
        case "bills", "utilities":
            return .financeBills
        case "health":
            return .financeHealth
        case "school", "education":
            return .financeEducation
        case "gifts", "gift":
            return .financeGifts
        case "savings":
            return .financeSavings
        case "income":
            return .income
        case "expense":
            return .expense
        case "transfer":
            return .transfer
        default:
            return .financeCategory
        }
    }

    static func taskCategory(name: String, storedIcon: String?) -> Self {
        if let stored = normalizedStoredKey(storedIcon) {
            return stored
        }
        if let storedIcon, let mapped = legacyTaskCategoryKey(storedIcon) {
            return mapped
        }
        return defaultTaskCategory(for: name)
    }

    static func financeCategory(name: String?, storedIcon: String?) -> Self {
        if let stored = normalizedStoredKey(storedIcon) {
            return stored
        }
        if let storedIcon, let mapped = legacyFinanceCategoryKey(storedIcon, categoryName: name) {
            return mapped
        }
        return defaultFinanceCategory(for: name)
    }

    static func normalizedTaskCategoryID(name: String, storedIcon: String?) -> String {
        taskCategory(name: name, storedIcon: storedIcon).rawValue
    }

    static func normalizedFinanceCategoryID(name: String?, storedIcon: String?) -> String {
        financeCategory(name: name, storedIcon: storedIcon).rawValue
    }
}

private extension OneIconKey {
    static func normalizedStoredKey(_ rawValue: String?) -> Self? {
        guard let rawValue else {
            return nil
        }
        let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else {
            return nil
        }
        return OneIconKey(rawValue: normalized)
    }

    static func legacyTaskCategoryKey(_ rawValue: String) -> Self? {
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "🏋️", "🏋️‍♂️", "🏋️‍♀️":
            return .categoryGym
        case "🎓":
            return .categorySchool
        case "💡":
            return .categoryProjects
        case "🌿":
            return .categoryWellbeing
        case "🧾":
            return .categoryLifeAdmin
        case "circle", "circle.fill", "square.grid.2x2.fill", "tag.fill", "tag":
            return nil
        default:
            return nil
        }
    }

    static func legacyFinanceCategoryKey(_ rawValue: String, categoryName: String?) -> Self? {
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "fork.knife":
            return .financeFood
        case "car.fill":
            return .financeTransport
        case "bag.fill":
            return .financeShopping
        case "popcorn.fill":
            return .financeEntertainment
        case "repeat.circle", "repeat.circle.fill":
            return .financeSubscriptions
        case "doc.text.fill":
            return .financeBills
        case "heart.text.square.fill":
            return .financeHealth
        case "book.closed.fill":
            return .financeEducation
        case "gift.fill":
            return .financeGifts
        case "archivebox.fill":
            return .financeSavings
        case "ellipsis.circle.fill", "questionmark.circle", "questionmark.circle.fill":
            return .financeMisc
        case "tag.fill", "tag", "circle":
            return defaultFinanceCategory(for: categoryName)
        case "arrow.down.left.circle", "arrow.down.left.circle.fill":
            return .income
        case "arrow.up.right.circle", "arrow.up.right.circle.fill":
            return .expense
        case "arrow.left.arrow.right.circle", "arrow.left.arrow.right.circle.fill":
            return .transfer
        default:
            return nil
        }
    }

    static func normalizedName(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

public extension Category {
    var oneIconKey: OneIconKey {
        OneIconKey.taskCategory(name: name, storedIcon: icon)
    }

    var normalizedIconID: String {
        oneIconKey.rawValue
    }
}

public extension FinanceCategory {
    var oneIconKey: OneIconKey {
        OneIconKey.financeCategory(name: name, storedIcon: iconName)
    }

    var normalizedIconName: String {
        oneIconKey.rawValue
    }
}

public extension FinanceCategoryTotal {
    var oneIconKey: OneIconKey {
        OneIconKey.financeCategory(name: categoryName, storedIcon: iconName)
    }
}

private protocol OneAssetCatalogKey {
    var assetName: String { get }
    var assetAccessibilityLabel: String { get }
}

extension OneIconKey: OneAssetCatalogKey {
    var assetName: String {
        rawValue.replacingOccurrences(of: ".", with: "-")
    }

    var assetAccessibilityLabel: String {
        accessibilityLabel
    }
}

enum OneUIIconKey: String, CaseIterable, Sendable, Hashable, OneAssetCatalogKey {
    case quickAddOpen = "ui.quick-add-open"
    case quickAddClose = "ui.quick-add-close"
    case railSplit = "ui.rail-split"
    case railRecovery = "ui.rail-recovery"
    case railRecurring = "ui.rail-recurring"
    case doFirst = "ui.do-first"
    case pin = "ui.pin"
    case unpin = "ui.unpin"
    case details = "ui.details"
    case disclosureRight = "ui.disclosure-right"
    case pagerPrevious = "ui.pager-previous"
    case pagerNext = "ui.pager-next"
    case expand = "ui.expand"
    case collapse = "ui.collapse"
    case notePresent = "ui.note-present"
    case placeholder = "ui.placeholder"
    case completed = "ui.completed"
    case completedOutline = "ui.completed-outline"
    case dragHandle = "ui.drag-handle"
    case delete = "ui.delete"
    case duplicate = "ui.duplicate"
    case close = "ui.close"
    case microphone = "ui.microphone"
    case more = "ui.more"
    case check = "ui.check"
    case sentimentGreat = "ui.sentiment-great"
    case sentimentFocused = "ui.sentiment-focused"
    case sentimentOkay = "ui.sentiment-okay"
    case sentimentTired = "ui.sentiment-tired"
    case sentimentStressed = "ui.sentiment-stressed"

    var assetName: String {
        rawValue.replacingOccurrences(of: ".", with: "-")
    }

    var assetAccessibilityLabel: String {
        switch self {
        case .quickAddOpen:
            return "Open quick add"
        case .quickAddClose:
            return "Close quick add"
        case .railSplit:
            return "Split"
        case .railRecovery:
            return "Recovery"
        case .railRecurring:
            return "Recurring"
        case .doFirst:
            return "Do first"
        case .pin:
            return "Pin"
        case .unpin:
            return "Unpin"
        case .details:
            return "Details"
        case .disclosureRight:
            return "Open details"
        case .pagerPrevious:
            return "Previous"
        case .pagerNext:
            return "Next"
        case .expand:
            return "Expand"
        case .collapse:
            return "Collapse"
        case .notePresent:
            return "Has note"
        case .placeholder:
            return "Pending"
        case .completed:
            return "Completed"
        case .completedOutline:
            return "Ready to complete"
        case .dragHandle:
            return "Reorder"
        case .delete:
            return "Delete"
        case .duplicate:
            return "Duplicate"
        case .close:
            return "Close"
        case .microphone:
            return "Voice entry"
        case .more:
            return "More actions"
        case .check:
            return "Confirmed"
        case .sentimentGreat:
            return "Great"
        case .sentimentFocused:
            return "Focused"
        case .sentimentOkay:
            return "Okay"
        case .sentimentTired:
            return "Tired"
        case .sentimentStressed:
            return "Stressed"
        }
    }
}

enum OneAppIconKey: Sendable, Hashable, OneAssetCatalogKey {
    case semantic(OneIconKey)
    case ui(OneUIIconKey)

    var assetName: String {
        switch self {
        case .semantic(let key):
            return key.assetName
        case .ui(let key):
            return key.assetName
        }
    }

    var assetAccessibilityLabel: String {
        switch self {
        case .semantic(let key):
            return key.assetAccessibilityLabel
        case .ui(let key):
            return key.assetAccessibilityLabel
        }
    }
}

#if canImport(SwiftUI)
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public enum OneIconBadgeShape {
    case circle
    case roundedSquare
    case capsule
}

enum OneIconAssetCatalog {
    static let scopedKeys: [OneIconKey] = OneIconKey.allCases
    static let uiKeys: [OneUIIconKey] = OneUIIconKey.allCases

    static func assetName(for key: OneIconKey) -> String {
        key.assetName
    }

    static func assetName(for key: OneUIIconKey) -> String {
        key.assetName
    }

    static func assetName(for key: OneAppIconKey) -> String {
        key.assetName
    }
}

#if canImport(UIKit)
@MainActor
enum OnePlatformImageLoader {
    static func image(for key: OneAppIconKey) -> UIImage? {
        UIImage(named: key.assetName, in: .module, compatibleWith: nil)
    }

    static func image(for key: OneIconKey) -> UIImage? {
        image(for: .semantic(key))
    }

    static func image(for key: OneUIIconKey) -> UIImage? {
        image(for: .ui(key))
    }
}
#elseif canImport(AppKit)
enum OnePlatformImageLoader {
    static func image(for key: OneAppIconKey) -> NSImage? {
        Bundle.module.image(forResource: NSImage.Name(key.assetName))
    }

    static func image(for key: OneIconKey) -> NSImage? {
        image(for: .semantic(key))
    }

    static func image(for key: OneUIIconKey) -> NSImage? {
        image(for: .ui(key))
    }
}
#endif

public enum OneIconImageFactory {
    @MainActor
    public static func tabBarImage(for key: OneIconKey) -> Image {
        #if canImport(UIKit)
        if let image = OnePlatformImageLoader.image(for: key)?.withRenderingMode(.alwaysTemplate) {
            return Image(uiImage: image)
        }
        if let image = OneTabBarIconRasterCache.image(for: key) {
            return Image(uiImage: image)
        }
        return Image(uiImage: UIImage())
        #elseif canImport(AppKit)
        if let image = OnePlatformImageLoader.image(for: key) {
            return Image(nsImage: image)
        }
        return Image(nsImage: NSImage(size: NSSize(width: 1, height: 1)))
        #else
        return Image(decorative: "")
        #endif
    }
}

public struct OneIcon: View {
    public let key: OneIconKey
    public let palette: OneTheme.Palette
    public var size: CGFloat
    public var tint: Color?
    public var lineWidth: CGFloat?

    public init(
        key: OneIconKey,
        palette: OneTheme.Palette,
        size: CGFloat = 18,
        tint: Color? = nil,
        lineWidth: CGFloat? = nil
    ) {
        self.key = key
        self.palette = palette
        self.size = size
        self.tint = tint
        self.lineWidth = lineWidth
    }

    public var body: some View {
        Group {
            if OnePlatformImageLoader.image(for: key) != nil {
                OneAppIconAssetView(
                    key: .semantic(key),
                    tint: tint ?? palette.symbol
                )
            } else {
                OneIconGlyph(
                    key: key,
                    tint: tint ?? palette.symbol,
                    lineWidth: lineWidth ?? max(1.8, size * 0.095)
                )
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(key.accessibilityLabel)
    }
}

struct OneAppIcon: View {
    let key: OneAppIconKey
    var size: CGFloat
    var tint: Color?

    init(
        key: OneAppIconKey,
        size: CGFloat = 18,
        tint: Color? = nil
    ) {
        self.key = key
        self.size = size
        self.tint = tint
    }

    var body: some View {
        Group {
            if OnePlatformImageLoader.image(for: key) != nil {
                OneAppIconAssetView(
                    key: key,
                    tint: tint
                )
            } else {
                switch key {
                case .semantic(let semanticKey):
                    OneIconGlyph(
                        key: semanticKey,
                        tint: tint ?? .primary,
                        lineWidth: max(1.8, size * 0.095)
                    )
                case .ui:
                    OneUIIconFallbackView(
                        tint: tint ?? .secondary
                    )
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(key.assetAccessibilityLabel)
    }
}

public struct OneIconBadge: View {
    public let key: OneIconKey
    public let palette: OneTheme.Palette
    public var size: CGFloat
    public var tint: Color?
    public var background: Color?
    public var border: Color?
    public var shape: OneIconBadgeShape
    public var iconScale: CGFloat

    public init(
        key: OneIconKey,
        palette: OneTheme.Palette,
        size: CGFloat = 30,
        tint: Color? = nil,
        background: Color? = nil,
        border: Color? = nil,
        shape: OneIconBadgeShape = .roundedSquare,
        iconScale: CGFloat = 0.5
    ) {
        self.key = key
        self.palette = palette
        self.size = size
        self.tint = tint
        self.background = background
        self.border = border
        self.shape = shape
        self.iconScale = iconScale
    }

    public var body: some View {
        ZStack {
            switch shape {
            case .circle:
                Circle()
                    .fill(background ?? palette.surfaceMuted)
                Circle()
                    .stroke(border ?? palette.border, lineWidth: 1)
            case .roundedSquare:
                RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                    .fill(background ?? palette.surfaceMuted)
                RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                    .stroke(border ?? palette.border, lineWidth: 1)
            case .capsule:
                Capsule(style: .continuous)
                    .fill(background ?? palette.surfaceMuted)
                Capsule(style: .continuous)
                    .stroke(border ?? palette.border, lineWidth: 1)
            }

            OneIcon(
                key: key,
                palette: palette,
                size: size * iconScale,
                tint: tint ?? palette.symbol
            )
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(key.accessibilityLabel)
    }
}

public struct OneBrandMark: View {
    public var size: CGFloat

    public init(size: CGFloat = 54) {
        self.size = size
    }

    public var body: some View {
        Group {
            if OneBrandMarkAssetView.isAvailable {
                OneBrandMarkAssetView()
            } else {
                OneBrandMarkFallback(size: size)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(OneIconKey.brandMark.accessibilityLabel)
    }
}

#if canImport(UIKit)
@MainActor
private enum OneTabBarIconRasterCache {
    static var cache: [OneIconKey: UIImage] = [:]

    static func image(for key: OneIconKey) -> UIImage? {
        if let cached = cache[key] {
            return cached
        }

        if let image = OnePlatformImageLoader.image(for: key)?.withRenderingMode(.alwaysTemplate) {
            cache[key] = image
            return image
        }

        let renderer = ImageRenderer(
            content: OneIcon(
                key: key,
                palette: OneTheme.palette(for: .light),
                size: 22,
                tint: .black
            )
            .frame(width: 24, height: 24)
        )
        renderer.scale = UIScreen.main.scale

        guard let image = renderer.uiImage?.withRenderingMode(.alwaysTemplate) else {
            return nil
        }

        cache[key] = image
        return image
    }
}
#endif

private struct OneIconAssetView: View {
    let key: OneIconKey
    let tint: Color

    static func isAvailable(for key: OneIconKey) -> Bool {
        #if canImport(UIKit) || canImport(AppKit)
        OnePlatformImageLoader.image(for: key) != nil
        #else
        false
        #endif
    }

    @ViewBuilder
    var body: some View {
        #if canImport(UIKit)
        if let image = OnePlatformImageLoader.image(for: key) {
            Image(uiImage: image)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(tint)
        }
        #elseif canImport(AppKit)
        if let image = OnePlatformImageLoader.image(for: key) {
            Image(nsImage: image)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(tint)
        }
        #endif
    }
}

private struct OneAppIconAssetView: View {
    let key: OneAppIconKey
    let tint: Color?

    @ViewBuilder
    private func rendered(_ image: Image) -> some View {
        if let tint {
            image
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(tint)
        } else {
            image
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
        }
    }

    @ViewBuilder
    var body: some View {
        #if canImport(UIKit)
        if let image = OnePlatformImageLoader.image(for: key) {
            rendered(Image(uiImage: image))
        }
        #elseif canImport(AppKit)
        if let image = OnePlatformImageLoader.image(for: key) {
            rendered(Image(nsImage: image))
        }
        #endif
    }
}

private struct OneUIIconFallbackView: View {
    let tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .stroke(tint.opacity(0.8), lineWidth: 1.8)
            .padding(2)
    }
}

private struct OneBrandMarkAssetView: View {
    static var isAvailable: Bool {
        OnePlatformImageLoader.image(for: .brandMark) != nil
    }

    @ViewBuilder
    var body: some View {
        #if canImport(UIKit)
        if let image = OnePlatformImageLoader.image(for: .brandMark) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        }
        #elseif canImport(AppKit)
        if let image = OnePlatformImageLoader.image(for: .brandMark) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
        }
        #endif
    }
}

private struct OneBrandMarkFallback: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x091322), Color(hex: 0x1B2A44)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: max(1, size * 0.02))

            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color(hex: 0x3E82D6), Color(hex: 0x98C0F4)],
                        startPoint: .bottomLeading,
                        endPoint: .topTrailing
                    ),
                    lineWidth: size * 0.065
                )
                .frame(width: size * 0.56, height: size * 0.56)
                .offset(y: -size * 0.06)

            OneCheckShape()
                .stroke(
                    LinearGradient(
                        colors: [Color(hex: 0x6EA8FF), .white],
                        startPoint: .bottomLeading,
                        endPoint: .topTrailing
                    ),
                    style: StrokeStyle(
                        lineWidth: size * 0.12,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .frame(width: size * 0.28, height: size * 0.24)
                .offset(y: -size * 0.055)

            Circle()
                .fill(Color(hex: 0x69A1FF))
                .frame(width: size * 0.08, height: size * 0.08)
                .offset(x: -size * 0.01, y: size * 0.035)

            RoundedRectangle(cornerRadius: size * 0.1, style: .continuous)
                .fill(Color(hex: 0x15253B))
                .frame(width: size * 0.36, height: size * 0.16)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.1, style: .continuous)
                        .stroke(Color(hex: 0x3A5485), lineWidth: max(1, size * 0.018))
                )
                .overlay(
                    Text("1")
                        .font(.system(size: size * 0.15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white)
                )
                .offset(y: size * 0.25)
        }
    }
}

private struct OneIconGlyph: View {
    let key: OneIconKey
    let tint: Color
    let lineWidth: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)

            ZStack {
                switch key {
                case .brandMark:
                    ringCheckGlyph(side)
                case .today:
                    documentChecklistGlyph(side)
                case .review:
                    reviewGlyph(side, bars: 3)
                case .finance:
                    walletGlyph(side)
                case .settings:
                    slidersGlyph(side)
                case .task:
                    taskGlyph(side)
                case .habit:
                    habitGlyph(side)
                case .note:
                    noteGlyph(side)
                case .reflection:
                    reflectionGlyph(side)
                case .coach:
                    coachGlyph(side)
                case .bibleVerse:
                    bibleGlyph(side)
                case .analytics:
                    analyticsGlyph(side)
                case .progress:
                    progressGlyph(side)
                case .streak:
                    streakGlyph(side)
                case .dailyReview:
                    reviewGlyph(side, bars: 1)
                case .weeklyReview:
                    reviewGlyph(side, bars: 2)
                case .monthlyReview:
                    reviewGlyph(side, bars: 3)
                case .yearlyReview:
                    reviewGlyph(side, bars: 4)
                case .notifications:
                    bellGlyph(side)
                case .profile:
                    profileGlyph(side)
                case .categoryGeneric:
                    tagGlyph(side)
                case .categoryGym:
                    dumbbellGlyph(side)
                case .categorySchool:
                    bookGlyph(side)
                case .categoryProjects:
                    projectsGlyph(side)
                case .categoryWellbeing:
                    leafGlyph(side)
                case .categoryLifeAdmin:
                    clipboardGlyph(side)
                case .categoryFaith:
                    bibleGlyph(side)
                case .categoryFinance:
                    walletGlyph(side)
                case .financeCategory:
                    tagGlyph(side)
                case .financeFood:
                    bowlGlyph(side)
                case .financeTransport:
                    transportGlyph(side)
                case .financeShopping:
                    bagGlyph(side)
                case .financeEntertainment:
                    ticketGlyph(side)
                case .financeSubscriptions:
                    repeatGlyph(side)
                case .financeBills:
                    receiptGlyph(side)
                case .financeHealth:
                    heartGlyph(side)
                case .financeEducation:
                    bookGlyph(side)
                case .financeGifts:
                    giftGlyph(side)
                case .financeSavings:
                    archiveGlyph(side)
                case .financeMisc:
                    miscGlyph(side)
                case .income:
                    arrowGlyph(side, direction: .inbound)
                case .expense:
                    arrowGlyph(side, direction: .outbound)
                case .transfer:
                    arrowGlyph(side, direction: .transfer)
                case .transaction:
                    receiptGlyph(side)
                case .completedDay, .success:
                    successGlyph(side)
                case .incompleteDay:
                    incompleteGlyph(side)
                case .milestone:
                    milestoneGlyph(side)
                case .streakMaintained:
                    streakGlyph(side, indicator: .check)
                case .streakBroken:
                    streakGlyph(side, indicator: .slash)
                case .noteAdded:
                    noteGlyph(side, indicator: .plus)
                case .reflectionCompleted:
                    reflectionGlyph(side, indicator: .check)
                case .noData:
                    analyticsGlyph(side, indicator: .slash)
                case .noNotes:
                    noteGlyph(side, indicator: .slash)
                case .noHabits:
                    habitGlyph(side, indicator: .slash)
                case .noTransactions:
                    walletGlyph(side, indicator: .slash)
                case .coachInsight:
                    coachGlyph(side, indicator: .spark)
                case .reminder:
                    bellGlyph(side, indicator: .dot)
                case .warning:
                    warningGlyph(side)
                case .error:
                    errorGlyph(side)
                case .offline:
                    offlineGlyph(side)
                case .sync:
                    syncGlyph(side)
                case .archive:
                    archiveGlyph(side)
                }
            }
            .frame(width: side, height: side)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
    }

    private enum Indicator {
        case plus
        case check
        case slash
        case spark
        case dot
    }

    private enum ArrowDirection {
        case inbound
        case outbound
        case transfer
    }

    @ViewBuilder
    private func ringCheckGlyph(_ size: CGFloat) -> some View {
        Circle()
            .stroke(tint, lineWidth: lineWidth)
            .frame(width: size * 0.8, height: size * 0.8)

        OneCheckShape()
            .stroke(
                tint,
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )
            .frame(width: size * 0.34, height: size * 0.28)
    }

    @ViewBuilder
    private func documentChecklistGlyph(_ size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
            .stroke(tint, lineWidth: lineWidth)
            .frame(width: size * 0.72, height: size * 0.82)

        OneCheckShape()
            .stroke(tint, style: StrokeStyle(lineWidth: lineWidth * 0.82, lineCap: .round, lineJoin: .round))
            .frame(width: size * 0.18, height: size * 0.14)
            .offset(x: -size * 0.12, y: -size * 0.14)

        line(length: size * 0.2)
            .offset(x: size * 0.12, y: -size * 0.14)
        line(length: size * 0.38)
            .offset(y: 0)
        line(length: size * 0.3)
            .offset(y: size * 0.16)
    }

    @ViewBuilder
    private func reviewGlyph(_ size: CGFloat, bars: Int) -> some View {
        RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
            .stroke(tint, lineWidth: lineWidth)
            .frame(width: size * 0.78, height: size * 0.72)

        HStack(alignment: .bottom, spacing: size * 0.06) {
            ForEach(0..<bars, id: \.self) { index in
                RoundedRectangle(cornerRadius: size * 0.04, style: .continuous)
                    .fill(tint)
                    .frame(width: size * 0.09, height: size * (0.15 + (CGFloat(index) * 0.08)))
            }
        }
        .offset(y: size * 0.03)

        line(length: size * 0.42)
            .offset(y: size * 0.22)
    }

    @ViewBuilder
    private func walletGlyph(_ size: CGFloat, indicator: Indicator? = nil) -> some View {
        RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
            .stroke(tint, lineWidth: lineWidth)
            .frame(width: size * 0.8, height: size * 0.58)
            .offset(y: size * 0.02)

        RoundedRectangle(cornerRadius: size * 0.08, style: .continuous)
            .stroke(tint, lineWidth: lineWidth * 0.85)
            .frame(width: size * 0.26, height: size * 0.16)
            .offset(x: size * 0.13, y: 0)

        Circle()
            .fill(tint)
            .frame(width: size * 0.045, height: size * 0.045)
            .offset(x: size * 0.18)

        if let indicator {
            indicatorView(indicator, size: size)
        }
    }

    @ViewBuilder
    private func slidersGlyph(_ size: CGFloat) -> some View {
        line(length: size * 0.62)
            .offset(y: -size * 0.16)
        line(length: size * 0.62)
        line(length: size * 0.62)
            .offset(y: size * 0.16)

        Circle()
            .stroke(tint, lineWidth: lineWidth)
            .frame(width: size * 0.14, height: size * 0.14)
            .offset(x: -size * 0.12, y: -size * 0.16)
        Circle()
            .stroke(tint, lineWidth: lineWidth)
            .frame(width: size * 0.14, height: size * 0.14)
            .offset(x: size * 0.16)
        Circle()
            .stroke(tint, lineWidth: lineWidth)
            .frame(width: size * 0.14, height: size * 0.14)
            .offset(x: -size * 0.02, y: size * 0.16)
    }

    @ViewBuilder
    private func taskGlyph(_ size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
            .stroke(tint, lineWidth: lineWidth)
            .frame(width: size * 0.72, height: size * 0.72)
        OneCheckShape()
            .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .frame(width: size * 0.28, height: size * 0.22)
    }

    @ViewBuilder
    private func habitGlyph(_ size: CGFloat, indicator: Indicator? = nil) -> some View {
        Circle()
            .trim(from: 0.14, to: 0.92)
            .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .frame(width: size * 0.78, height: size * 0.78)
            .rotationEffect(.degrees(-22))

        polyline([(0.72, 0.17), (0.85, 0.14), (0.8, 0.28)], in: size)
            .stroke(tint, style: StrokeStyle(lineWidth: lineWidth * 0.9, lineCap: .round, lineJoin: .round))

        Circle()
            .fill(tint)
            .frame(width: size * 0.08, height: size * 0.08)
            .offset(x: -size * 0.18, y: size * 0.22)

        if let indicator {
            indicatorView(indicator, size: size)
        }
    }

    @ViewBuilder
    private func noteGlyph(_ size: CGFloat, indicator: Indicator? = nil) -> some View {
        RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
            .stroke(tint, lineWidth: lineWidth)
            .frame(width: size * 0.7, height: size * 0.8)
        line(length: size * 0.34)
            .offset(y: -size * 0.12)
        line(length: size * 0.34)
        line(length: size * 0.22)
            .offset(y: size * 0.12)

        if let indicator {
            indicatorView(indicator, size: size)
        }
    }

    @ViewBuilder
    private func reflectionGlyph(_ size: CGFloat, indicator: Indicator? = nil) -> some View {
        Circle()
            .stroke(tint, lineWidth: lineWidth)
            .frame(width: size * 0.74, height: size * 0.74)
        Circle()
            .fill(tint)
            .frame(width: size * 0.07, height: size * 0.07)
            .offset(y: -size * 0.06)
        line(length: size * 0.28)
            .offset(y: size * 0.18)

        if let indicator {
            indicatorView(indicator, size: size)
        }
    }

    @ViewBuilder
    private func coachGlyph(_ size: CGFloat, indicator: Indicator? = nil) -> some View {
        Circle()
            .stroke(tint, lineWidth: lineWidth)
            .frame(width: size * 0.78, height: size * 0.78)
        polyline([(0.48, 0.58), (0.58, 0.44), (0.72, 0.32)], in: size)
            .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        polyline([(0.56, 0.32), (0.73, 0.31), (0.64, 0.47)], in: size)
            .stroke(tint, style: StrokeStyle(lineWidth: lineWidth * 0.82, lineCap: .round, lineJoin: .round))
        Circle()
            .fill(tint)
            .frame(width: size * 0.08, height: size * 0.08)
            .offset(x: -size * 0.1, y: size * 0.12)

        if let indicator {
            indicatorView(indicator, size: size)
        }
    }

    @ViewBuilder
    private func bibleGlyph(_ size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: size * 0.12, style: .continuous)
            .stroke(tint, lineWidth: lineWidth)
            .frame(width: size * 0.72, height: size * 0.76)
        Rectangle()
            .fill(tint)
            .frame(width: lineWidth * 0.8, height: size * 0.52)
        line(length: size * 0.18)
            .offset(x: -size * 0.12, y: -size * 0.08)
        line(length: size * 0.18)
            .offset(x: size * 0.12, y: -size * 0.08)
        line(length: size * 0.14)
            .offset(x: -size * 0.12, y: size * 0.08)
        line(length: size * 0.14)
            .offset(x: size * 0.12, y: size * 0.08)
    }

    @ViewBuilder
    private func analyticsGlyph(_ size: CGFloat, indicator: Indicator? = nil) -> some View {
        HStack(alignment: .bottom, spacing: size * 0.08) {
            RoundedRectangle(cornerRadius: size * 0.04, style: .continuous)
                .fill(tint)
                .frame(width: size * 0.12, height: size * 0.22)
            RoundedRectangle(cornerRadius: size * 0.04, style: .continuous)
                .fill(tint)
                .frame(width: size * 0.12, height: size * 0.34)
            RoundedRectangle(cornerRadius: size * 0.04, style: .continuous)
                .fill(tint)
                .frame(width: size * 0.12, height: size * 0.48)
        }
        .offset(y: size * 0.04)

        line(length: size * 0.56)
            .offset(y: size * 0.28)

        if let indicator {
            indicatorView(indicator, size: size)
        }
    }

    @ViewBuilder
    private func progressGlyph(_ size: CGFloat) -> some View {
        polyline([(0.2, 0.72), (0.42, 0.52), (0.56, 0.58), (0.78, 0.3)], in: size)
            .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        polyline([(0.66, 0.3), (0.78, 0.3), (0.78, 0.42)], in: size)
            .stroke(tint, style: StrokeStyle(lineWidth: lineWidth * 0.86, lineCap: .round, lineJoin: .round))
    }

    @ViewBuilder
    private func streakGlyph(_ size: CGFloat, indicator: Indicator? = nil) -> some View {
        VStack(spacing: size * 0.1) {
            streakDot(size)
            streakDot(size)
            streakDot(size)
        }

        Rectangle()
            .fill(tint)
            .frame(width: lineWidth * 0.82, height: size * 0.36)

        if let indicator {
            indicatorView(indicator, size: size)
        }
    }

    @ViewBuilder
    private func bellGlyph(_ size: CGFloat, indicator: Indicator? = nil) -> some View {
        OneBellShape()
            .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .frame(width: size * 0.62, height: size * 0.72)
        Circle()
            .fill(tint)
            .frame(width: size * 0.06, height: size * 0.06)
            .offset(y: size * 0.23)

        if let indicator {
            indicatorView(indicator, size: size)
        }
    }

    @ViewBuilder
    private func profileGlyph(_ size: CGFloat) -> some View {
        Circle()
            .stroke(tint, lineWidth: lineWidth)
            .frame(width: size * 0.26, height: size * 0.26)
            .offset(y: -size * 0.18)
        OneArcShape(startAngle: .degrees(205), endAngle: .degrees(335))
            .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .frame(width: size * 0.68, height: size * 0.42)
            .offset(y: size * 0.14)
    }

    @ViewBuilder
    private func tagGlyph(_ size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: size * 0.14, style: .continuous)
            .stroke(tint, lineWidth: lineWidth)
            .frame(width: size * 0.72, height: size * 0.58)
            .rotationEffect(.degrees(-12))
        Circle()
            .stroke(tint, lineWidth: lineWidth * 0.9)
            .frame(width: size * 0.09, height: size * 0.09)
            .offset(x: -size * 0.17, y: -size * 0.04)
    }

    @ViewBuilder
    private func dumbbellGlyph(_ size: CGFloat) -> some View {
        Rectangle()
            .fill(tint)
            .frame(width: size * 0.34, height: lineWidth * 0.9)
        HStack(spacing: size * 0.16) {
            weightStack(size)
            weightStack(size)
        }
    }

    @ViewBuilder
    private func projectsGlyph(_ size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: size * 0.12, style: .continuous)
            .stroke(tint, lineWidth: lineWidth)
            .frame(width: size * 0.5, height: size * 0.5)
            .offset(x: -size * 0.08, y: size * 0.04)
        RoundedRectangle(cornerRadius: size * 0.12, style: .continuous)
            .stroke(tint, lineWidth: lineWidth)
            .frame(width: size * 0.5, height: size * 0.5)
            .offset(x: size * 0.08, y: -size * 0.06)
        polyline([(0.74, 0.58), (0.74, 0.76)], in: size)
            .stroke(tint, style: StrokeStyle(lineWidth: lineWidth * 0.82, lineCap: .round))
        polyline([(0.65, 0.67), (0.83, 0.67)], in: size)
            .stroke(tint, style: StrokeStyle(lineWidth: lineWidth * 0.82, lineCap: .round))
    }

    @ViewBuilder
    private func leafGlyph(_ size: CGFloat) -> some View {
        OneLeafShape()
            .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .frame(width: size * 0.64, height: size * 0.76)
        polyline([(0.34, 0.68), (0.56, 0.38)], in: size)
            .stroke(tint, style: StrokeStyle(lineWidth: lineWidth * 0.82, lineCap: .round, lineJoin: .round))
    }

    @ViewBuilder
    private func clipboardGlyph(_ size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: size * 0.14, style: .continuous)
            .stroke(tint, lineWidth: lineWidth)
            .frame(width: size * 0.66, height: size * 0.78)
        RoundedRectangle(cornerRadius: size * 0.1, style: .continuous)
            .stroke(tint, lineWidth: lineWidth * 0.82)
            .frame(width: size * 0.24, height: size * 0.14)
            .offset(y: -size * 0.28)
        OneCheckShape()
            .stroke(tint, style: StrokeStyle(lineWidth: lineWidth * 0.82, lineCap: .round, lineJoin: .round))
            .frame(width: size * 0.16, height: size * 0.12)
            .offset(x: -size * 0.12, y: -size * 0.04)
        line(length: size * 0.22)
            .offset(x: size * 0.1, y: -size * 0.04)
        line(length: size * 0.3)
            .offset(y: size * 0.12)
    }

    @ViewBuilder
    private func bowlGlyph(_ size: CGFloat) -> some View {
        OneArcShape(startAngle: .degrees(200), endAngle: .degrees(340))
            .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .frame(width: size * 0.56, height: size * 0.3)
            .offset(y: size * 0.12)
        line(length: size * 0.44)
            .offset(y: size * 0.24)
        polyline([(0.42, 0.26), (0.38, 0.38)], in: size)
            .stroke(tint, style: StrokeStyle(lineWidth: lineWidth * 0.75, lineCap: .round))
        polyline([(0.56, 0.24), (0.52, 0.36)], in: size)
            .stroke(tint, style: StrokeStyle(lineWidth: lineWidth * 0.75, lineCap: .round))
    }

    @ViewBuilder
    private func transportGlyph(_ size: CGFloat) -> some View {
        OneCarShape()
            .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .frame(width: size * 0.78, height: size * 0.56)
        HStack(spacing: size * 0.24) {
            Circle()
                .stroke(tint, lineWidth: lineWidth * 0.85)
                .frame(width: size * 0.12, height: size * 0.12)
            Circle()
                .stroke(tint, lineWidth: lineWidth * 0.85)
                .frame(width: size * 0.12, height: size * 0.12)
        }
        .offset(y: size * 0.18)
    }

    @ViewBuilder
    private func bagGlyph(_ size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
            .stroke(tint, lineWidth: lineWidth)
            .frame(width: size * 0.66, height: size * 0.62)
            .offset(y: size * 0.08)
        OneArcShape(startAngle: .degrees(200), endAngle: .degrees(340))
            .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .frame(width: size * 0.34, height: size * 0.18)
            .offset(y: -size * 0.08)
    }

    @ViewBuilder
    private func ticketGlyph(_ size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: size * 0.14, style: .continuous)
            .stroke(tint, lineWidth: lineWidth)
            .frame(width: size * 0.74, height: size * 0.46)
            .rotationEffect(.degrees(-12))
        Circle()
            .fill(Color.clear)
            .frame(width: size * 0.1, height: size * 0.1)
            .overlay(Circle().stroke(tint, lineWidth: lineWidth * 0.82))
            .offset(x: -size * 0.12)
        Circle()
            .fill(Color.clear)
            .frame(width: size * 0.1, height: size * 0.1)
            .overlay(Circle().stroke(tint, lineWidth: lineWidth * 0.82))
            .offset(x: size * 0.12)
    }

    @ViewBuilder
    private func repeatGlyph(_ size: CGFloat) -> some View {
        OneArcShape(startAngle: .degrees(120), endAngle: .degrees(330))
            .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .frame(width: size * 0.72, height: size * 0.72)
        OneArcShape(startAngle: .degrees(300), endAngle: .degrees(150))
            .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .frame(width: size * 0.52, height: size * 0.52)
        polyline([(0.76, 0.34), (0.84, 0.28), (0.82, 0.4)], in: size)
            .stroke(tint, style: StrokeStyle(lineWidth: lineWidth * 0.82, lineCap: .round, lineJoin: .round))
        polyline([(0.24, 0.66), (0.16, 0.72), (0.18, 0.6)], in: size)
            .stroke(tint, style: StrokeStyle(lineWidth: lineWidth * 0.82, lineCap: .round, lineJoin: .round))
    }

    @ViewBuilder
    private func receiptGlyph(_ size: CGFloat) -> some View {
        OneReceiptShape()
            .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .frame(width: size * 0.62, height: size * 0.78)
        line(length: size * 0.24)
            .offset(y: -size * 0.1)
        line(length: size * 0.24)
            .offset(y: size * 0.02)
        line(length: size * 0.16)
            .offset(y: size * 0.14)
    }

    @ViewBuilder
    private func heartGlyph(_ size: CGFloat) -> some View {
        OneHeartShape()
            .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .frame(width: size * 0.64, height: size * 0.62)
    }

    @ViewBuilder
    private func bookGlyph(_ size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: size * 0.12, style: .continuous)
            .stroke(tint, lineWidth: lineWidth)
            .frame(width: size * 0.68, height: size * 0.74)
        Rectangle()
            .fill(tint)
            .frame(width: lineWidth * 0.82, height: size * 0.5)
            .offset(x: -size * 0.1)
        line(length: size * 0.18)
            .offset(x: size * 0.1, y: -size * 0.1)
        line(length: size * 0.18)
            .offset(x: size * 0.1, y: size * 0.04)
    }

    @ViewBuilder
    private func giftGlyph(_ size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: size * 0.14, style: .continuous)
            .stroke(tint, lineWidth: lineWidth)
            .frame(width: size * 0.68, height: size * 0.54)
            .offset(y: size * 0.12)
        RoundedRectangle(cornerRadius: size * 0.12, style: .continuous)
            .stroke(tint, lineWidth: lineWidth)
            .frame(width: size * 0.72, height: size * 0.18)
            .offset(y: -size * 0.08)
        Rectangle()
            .fill(tint)
            .frame(width: lineWidth * 0.82, height: size * 0.5)
            .offset(y: size * 0.1)
        OneArcShape(startAngle: .degrees(190), endAngle: .degrees(340))
            .stroke(tint, style: StrokeStyle(lineWidth: lineWidth * 0.82, lineCap: .round))
            .frame(width: size * 0.18, height: size * 0.16)
            .offset(x: -size * 0.08, y: -size * 0.22)
        OneArcShape(startAngle: .degrees(200), endAngle: .degrees(350))
            .stroke(tint, style: StrokeStyle(lineWidth: lineWidth * 0.82, lineCap: .round))
            .frame(width: size * 0.18, height: size * 0.16)
            .offset(x: size * 0.08, y: -size * 0.22)
    }

    @ViewBuilder
    private func archiveGlyph(_ size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: size * 0.14, style: .continuous)
            .stroke(tint, lineWidth: lineWidth)
            .frame(width: size * 0.74, height: size * 0.5)
            .offset(y: size * 0.12)
        RoundedRectangle(cornerRadius: size * 0.12, style: .continuous)
            .stroke(tint, lineWidth: lineWidth)
            .frame(width: size * 0.78, height: size * 0.18)
            .offset(y: -size * 0.12)
        line(length: size * 0.18)
            .offset(y: size * 0.12)
    }

    @ViewBuilder
    private func miscGlyph(_ size: CGFloat) -> some View {
        Circle()
            .stroke(tint, lineWidth: lineWidth)
            .frame(width: size * 0.72, height: size * 0.72)
        HStack(spacing: size * 0.08) {
            Circle().fill(tint).frame(width: size * 0.07, height: size * 0.07)
            Circle().fill(tint).frame(width: size * 0.07, height: size * 0.07)
            Circle().fill(tint).frame(width: size * 0.07, height: size * 0.07)
        }
    }

    @ViewBuilder
    private func arrowGlyph(_ size: CGFloat, direction: ArrowDirection) -> some View {
        Circle()
            .stroke(tint, lineWidth: lineWidth)
            .frame(width: size * 0.74, height: size * 0.74)

        switch direction {
        case .inbound:
            polyline([(0.72, 0.32), (0.44, 0.58), (0.28, 0.58)], in: size)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            polyline([(0.32, 0.46), (0.28, 0.58), (0.4, 0.62)], in: size)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth * 0.82, lineCap: .round, lineJoin: .round))
        case .outbound:
            polyline([(0.28, 0.68), (0.56, 0.42), (0.72, 0.42)], in: size)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            polyline([(0.6, 0.3), (0.72, 0.42), (0.6, 0.54)], in: size)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth * 0.82, lineCap: .round, lineJoin: .round))
        case .transfer:
            polyline([(0.24, 0.4), (0.72, 0.4)], in: size)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            polyline([(0.64, 0.3), (0.76, 0.4), (0.64, 0.5)], in: size)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth * 0.82, lineCap: .round, lineJoin: .round))
            polyline([(0.76, 0.6), (0.28, 0.6)], in: size)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            polyline([(0.36, 0.5), (0.24, 0.6), (0.36, 0.7)], in: size)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth * 0.82, lineCap: .round, lineJoin: .round))
        }
    }

    @ViewBuilder
    private func successGlyph(_ size: CGFloat) -> some View {
        Circle()
            .stroke(tint, lineWidth: lineWidth)
            .frame(width: size * 0.74, height: size * 0.74)
        OneCheckShape()
            .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .frame(width: size * 0.3, height: size * 0.22)
    }

    @ViewBuilder
    private func incompleteGlyph(_ size: CGFloat) -> some View {
        Circle()
            .trim(from: 0.04, to: 0.96)
            .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .frame(width: size * 0.74, height: size * 0.74)
        line(length: size * 0.24)
    }

    @ViewBuilder
    private func milestoneGlyph(_ size: CGFloat) -> some View {
        Circle()
            .stroke(tint, lineWidth: lineWidth)
            .frame(width: size * 0.72, height: size * 0.72)
        OneStarShape()
            .stroke(tint, style: StrokeStyle(lineWidth: lineWidth * 0.86, lineCap: .round, lineJoin: .round))
            .frame(width: size * 0.28, height: size * 0.28)
    }

    @ViewBuilder
    private func warningGlyph(_ size: CGFloat) -> some View {
        OneTriangleShape()
            .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .frame(width: size * 0.72, height: size * 0.68)
        Rectangle()
            .fill(tint)
            .frame(width: lineWidth * 0.85, height: size * 0.18)
            .offset(y: -size * 0.03)
        Circle()
            .fill(tint)
            .frame(width: size * 0.05, height: size * 0.05)
            .offset(y: size * 0.16)
    }

    @ViewBuilder
    private func errorGlyph(_ size: CGFloat) -> some View {
        Circle()
            .stroke(tint, lineWidth: lineWidth)
            .frame(width: size * 0.74, height: size * 0.74)
        polyline([(0.34, 0.34), (0.66, 0.66)], in: size)
            .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        polyline([(0.66, 0.34), (0.34, 0.66)], in: size)
            .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
    }

    @ViewBuilder
    private func offlineGlyph(_ size: CGFloat) -> some View {
        OneCloudShape()
            .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .frame(width: size * 0.76, height: size * 0.54)
        polyline([(0.26, 0.72), (0.74, 0.28)], in: size)
            .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
    }

    @ViewBuilder
    private func syncGlyph(_ size: CGFloat) -> some View {
        Circle()
            .trim(from: 0.12, to: 0.56)
            .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .frame(width: size * 0.74, height: size * 0.74)
            .rotationEffect(.degrees(-12))
        Circle()
            .trim(from: 0.62, to: 0.96)
            .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .frame(width: size * 0.74, height: size * 0.74)
            .rotationEffect(.degrees(-12))
        polyline([(0.65, 0.2), (0.78, 0.24), (0.7, 0.34)], in: size)
            .stroke(tint, style: StrokeStyle(lineWidth: lineWidth * 0.82, lineCap: .round, lineJoin: .round))
        polyline([(0.35, 0.8), (0.22, 0.76), (0.3, 0.66)], in: size)
            .stroke(tint, style: StrokeStyle(lineWidth: lineWidth * 0.82, lineCap: .round, lineJoin: .round))
    }

    private func indicatorView(_ indicator: Indicator, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color.clear)
                .frame(width: size * 0.28, height: size * 0.28)
                .overlay(
                    Circle()
                        .fill(.background.opacity(0.001))
                )

            switch indicator {
            case .plus:
                plusGlyph(size * 0.28)
            case .check:
                OneCheckShape()
                    .stroke(
                        tint,
                        style: StrokeStyle(lineWidth: lineWidth * 0.72, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: size * 0.12, height: size * 0.1)
            case .slash:
                polyline([(0.38, 0.7), (0.62, 0.3)], in: size * 0.28)
                    .stroke(tint, style: StrokeStyle(lineWidth: lineWidth * 0.72, lineCap: .round))
            case .spark:
                OneStarShape()
                    .stroke(
                        tint,
                        style: StrokeStyle(lineWidth: lineWidth * 0.68, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: size * 0.12, height: size * 0.12)
            case .dot:
                Circle()
                    .fill(tint)
                    .frame(width: size * 0.08, height: size * 0.08)
            }
        }
        .offset(x: size * 0.24, y: -size * 0.24)
    }

    private func plusGlyph(_ size: CGFloat) -> some View {
        ZStack {
            Rectangle()
                .fill(tint)
                .frame(width: size * 0.12, height: size * 0.46)
            Rectangle()
                .fill(tint)
                .frame(width: size * 0.46, height: size * 0.12)
        }
    }

    private func line(length: CGFloat) -> some View {
        Capsule(style: .continuous)
            .fill(tint)
            .frame(width: length, height: max(1.6, lineWidth * 0.72))
    }

    private func streakDot(_ size: CGFloat) -> some View {
        Circle()
            .fill(tint)
            .frame(width: size * 0.09, height: size * 0.09)
    }

    private func weightStack(_ size: CGFloat) -> some View {
        HStack(spacing: size * 0.03) {
            Rectangle()
                .fill(tint)
                .frame(width: size * 0.05, height: size * 0.22)
            Rectangle()
                .fill(tint)
                .frame(width: size * 0.05, height: size * 0.34)
        }
    }

    private func polyline(_ points: [(CGFloat, CGFloat)], in size: CGFloat) -> Path {
        var path = Path()
        guard let first = points.first else {
            return path
        }
        path.move(to: CGPoint(x: first.0 * size, y: first.1 * size))
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(x: point.0 * size, y: point.1 * size))
        }
        return path
    }
}

private struct OneCheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.16, y: rect.minY + rect.height * 0.58))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.42, y: rect.minY + rect.height * 0.84))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.84, y: rect.minY + rect.height * 0.2))
        return path
    }
}

private struct OneArcShape: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: min(rect.width, rect.height) / 2,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return path
    }
}

private struct OneBellShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.12))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.14, y: rect.height * 0.56),
            control: CGPoint(x: rect.maxX - rect.width * 0.02, y: rect.height * 0.16)
        )
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.08, y: rect.height * 0.72))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.height * 0.72))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.14, y: rect.height * 0.56))
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.12),
            control: CGPoint(x: rect.minX + rect.width * 0.02, y: rect.height * 0.16)
        )
        return path
    }
}

private struct OneLeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.height * 0.74))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.16, y: rect.height * 0.2),
            control: CGPoint(x: rect.midX, y: rect.height * 0.88)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.height * 0.74),
            control: CGPoint(x: rect.maxX - rect.width * 0.04, y: rect.height * 0.78)
        )
        return path
    }
}

private struct OneCarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.14, y: rect.height * 0.62))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.height * 0.38))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.44, y: rect.height * 0.24))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.72, y: rect.height * 0.24))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.height * 0.4))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.06, y: rect.height * 0.58))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.08, y: rect.height * 0.7))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.14, y: rect.height * 0.7))
        path.closeSubpath()
        return path
    }
}

private struct OneReceiptShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.minY + rect.height * 0.06))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.2, y: rect.minY + rect.height * 0.06))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.2, y: rect.maxY - rect.height * 0.12))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.maxY - rect.height * 0.04))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.12))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.maxY - rect.height * 0.04))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.maxY - rect.height * 0.12))
        path.closeSubpath()
        return path
    }
}

private struct OneHeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.14))
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.height * 0.38),
            control1: CGPoint(x: rect.minX + rect.width * 0.24, y: rect.height * 0.78),
            control2: CGPoint(x: rect.minX + rect.width * 0.04, y: rect.height * 0.62)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.height * 0.2),
            control1: CGPoint(x: rect.minX + rect.width * 0.14, y: rect.height * 0.12),
            control2: CGPoint(x: rect.midX - rect.width * 0.16, y: rect.height * 0.06)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.height * 0.38),
            control1: CGPoint(x: rect.midX + rect.width * 0.16, y: rect.height * 0.06),
            control2: CGPoint(x: rect.maxX - rect.width * 0.14, y: rect.height * 0.12)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.14),
            control1: CGPoint(x: rect.maxX - rect.width * 0.04, y: rect.height * 0.62),
            control2: CGPoint(x: rect.maxX - rect.width * 0.24, y: rect.height * 0.78)
        )
        return path
    }
}

private struct OneStarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let points = [
            CGPoint(x: rect.midX, y: rect.minY),
            CGPoint(x: rect.maxX - rect.width * 0.34, y: rect.maxY - rect.height * 0.34),
            CGPoint(x: rect.minX, y: rect.maxY - rect.height * 0.34),
            CGPoint(x: rect.maxX - rect.width * 0.22, y: rect.height * 0.56),
            CGPoint(x: rect.minX + rect.width * 0.22, y: rect.height * 0.56),
            CGPoint(x: rect.midX, y: rect.minY)
        ]

        var path = Path()
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }
}

private struct OneTriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.08))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.08, y: rect.maxY - rect.height * 0.06))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.maxY - rect.height * 0.06))
        path.closeSubpath()
        return path
    }
}

private struct OneCloudShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.height * 0.68))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.height * 0.38),
            control: CGPoint(x: rect.minX + rect.width * 0.14, y: rect.height * 0.48)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.height * 0.34),
            control: CGPoint(x: rect.minX + rect.width * 0.4, y: rect.height * 0.18)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.16, y: rect.height * 0.48),
            control: CGPoint(x: rect.maxX - rect.width * 0.1, y: rect.height * 0.16)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.18, y: rect.height * 0.68),
            control: CGPoint(x: rect.maxX, y: rect.height * 0.54)
        )
        path.closeSubpath()
        return path
    }
}
#endif
