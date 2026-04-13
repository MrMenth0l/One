import Foundation

public enum OneWidgetKind {
    public static let todayQueue = "com.yehosuah.one.widget.today-queue"
}

public struct OneWidgetQueueItem: Identifiable, Codable, Sendable, Equatable, Hashable {
    public let itemType: ItemType
    public let itemId: String
    public let dateLocal: String
    public let title: String
    public let subtitle: String?
    public let categoryName: String
    public let categoryIcon: OneIconKey
    public let urgency: TodayUrgency
    public let timeBucket: TodayTimeBucket
    public let isPinned: Bool

    public init(
        itemType: ItemType,
        itemId: String,
        dateLocal: String,
        title: String,
        subtitle: String?,
        categoryName: String,
        categoryIcon: OneIconKey,
        urgency: TodayUrgency,
        timeBucket: TodayTimeBucket,
        isPinned: Bool
    ) {
        self.itemType = itemType
        self.itemId = itemId
        self.dateLocal = dateLocal
        self.title = title
        self.subtitle = subtitle
        self.categoryName = categoryName
        self.categoryIcon = categoryIcon
        self.urgency = urgency
        self.timeBucket = timeBucket
        self.isPinned = isPinned
    }

    public var id: String { "\(itemType.rawValue):\(itemId)" }

    public var routeURL: URL {
        OneSystemRoute
            .confirmTodayItem(itemType: itemType, itemId: itemId, dateLocal: dateLocal)
            .url()
    }
}

public struct OneWidgetQueueSnapshot: Codable, Sendable, Equatable {
    public let dateLocal: String
    public let items: [OneWidgetQueueItem]
    public let completedCount: Int
    public let totalCount: Int
    public let isConfigured: Bool

    public init(
        dateLocal: String,
        items: [OneWidgetQueueItem],
        completedCount: Int,
        totalCount: Int,
        isConfigured: Bool
    ) {
        self.dateLocal = dateLocal
        self.items = items
        self.completedCount = completedCount
        self.totalCount = totalCount
        self.isConfigured = isConfigured
    }

    public static func empty(
        dateLocal: String = "",
        isConfigured: Bool = false
    ) -> OneWidgetQueueSnapshot {
        OneWidgetQueueSnapshot(
            dateLocal: dateLocal,
            items: [],
            completedCount: 0,
            totalCount: 0,
            isConfigured: isConfigured
        )
    }
}

public enum OneWidgetConfigurationState: String, Codable, Sendable, Equatable {
    case ready
    case needsAppLaunch
    case signedOut
}

public struct OneWidgetSnapshotPayload: Codable, Sendable, Equatable {
    public let version: Int
    public let generatedAt: Date
    public let todayQueue: OneWidgetQueueSnapshot
    public let configurationState: OneWidgetConfigurationState

    public init(
        version: Int = OneWidgetSnapshotStore.currentVersion,
        generatedAt: Date = Date(),
        todayQueue: OneWidgetQueueSnapshot,
        configurationState: OneWidgetConfigurationState
    ) {
        self.version = version
        self.generatedAt = generatedAt
        self.todayQueue = todayQueue
        self.configurationState = configurationState
    }

    public static func ready(
        todayQueue: OneWidgetQueueSnapshot,
        generatedAt: Date = Date()
    ) -> OneWidgetSnapshotPayload {
        OneWidgetSnapshotPayload(
            generatedAt: generatedAt,
            todayQueue: todayQueue,
            configurationState: .ready
        )
    }

    public static func needsAppLaunch(
        generatedAt: Date = Date()
    ) -> OneWidgetSnapshotPayload {
        OneWidgetSnapshotPayload(
            generatedAt: generatedAt,
            todayQueue: .empty(),
            configurationState: .needsAppLaunch
        )
    }

    public static func signedOut(
        generatedAt: Date = Date()
    ) -> OneWidgetSnapshotPayload {
        OneWidgetSnapshotPayload(
            generatedAt: generatedAt,
            todayQueue: .empty(isConfigured: true),
            configurationState: .signedOut
        )
    }
}

public enum OneWidgetSnapshotStore {
    public static let currentVersion = 1

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    public static func write(
        _ payload: OneWidgetSnapshotPayload,
        fileManager: FileManager = .default,
        storeURL: URL? = nil
    ) throws {
        let data = try encoder.encode(payload)
        let url = try resolvedStoreURL(storeURL, fileManager: fileManager)
        try data.write(to: url, options: .atomic)
    }

    public static func read(
        fileManager: FileManager = .default,
        storeURL: URL? = nil
    ) -> OneWidgetSnapshotPayload {
        guard let url = try? resolvedStoreURL(storeURL, fileManager: fileManager),
              let data = try? Data(contentsOf: url),
              let payload = try? decoder.decode(OneWidgetSnapshotPayload.self, from: data),
              payload.version == currentVersion else {
            return .needsAppLaunch()
        }
        return payload
    }

    public static func clear(
        fileManager: FileManager = .default,
        storeURL: URL? = nil
    ) throws {
        let url = try resolvedStoreURL(storeURL, fileManager: fileManager)
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }
        try fileManager.removeItem(at: url)
    }

    private static func resolvedStoreURL(
        _ storeURL: URL?,
        fileManager: FileManager
    ) throws -> URL {
        if let storeURL {
            return storeURL
        }
        return try OneSharedSystem.widgetSnapshotURL(fileManager: fileManager)
    }
}

public struct OneWidgetSnapshotReader {
    public init() {}

    public func load() -> OneWidgetSnapshotPayload {
        OneWidgetSnapshotStore.read()
    }
}
