import Foundation

public enum OneSharedSystem {
    public static let appGroupIdentifier = "group.com.yehosuah.one.shared"
    public static let routeScheme = "one"
    public static let routeHost = "action"

    static let storeDirectoryName = "OneSharedStore"
    static let storeFilename = "OneOfflineStore.store"
    static let routeDirectoryName = "OneSystemRouting"
    static let pendingRouteFilename = "pending-route.json"
    static let widgetDirectoryName = "OneWidgetSnapshots"
    static let widgetSnapshotFilename = "today-queue.json"

    static func sharedContainerURL(fileManager: FileManager = .default) -> URL? {
        fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        )
    }

    static func applicationSupportDirectoryURL(fileManager: FileManager = .default) throws -> URL {
        let applicationSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        try fileManager.createDirectory(
            at: applicationSupportURL,
            withIntermediateDirectories: true
        )
        return applicationSupportURL
    }

    public static func legacyStoreURL(fileManager: FileManager = .default) throws -> URL {
        try applicationSupportDirectoryURL(fileManager: fileManager)
            .appendingPathComponent(storeFilename)
    }

    public static func storeURL(fileManager: FileManager = .default) throws -> URL {
        if let groupContainer = sharedContainerURL(fileManager: fileManager) {
            let storeDirectory = groupContainer.appendingPathComponent(
                storeDirectoryName,
                isDirectory: true
            )
            try fileManager.createDirectory(
                at: storeDirectory,
                withIntermediateDirectories: true
            )
            return storeDirectory.appendingPathComponent(storeFilename)
        }

        return try legacyStoreURL(fileManager: fileManager)
    }

    static func pendingRouteURL(fileManager: FileManager = .default) throws -> URL {
        if let groupContainer = sharedContainerURL(fileManager: fileManager) {
            let routeDirectory = groupContainer.appendingPathComponent(
                routeDirectoryName,
                isDirectory: true
            )
            try fileManager.createDirectory(
                at: routeDirectory,
                withIntermediateDirectories: true
            )
            return routeDirectory.appendingPathComponent(pendingRouteFilename)
        }

        return try applicationSupportDirectoryURL(fileManager: fileManager)
            .appendingPathComponent(pendingRouteFilename)
    }

    static func widgetSnapshotURL(fileManager: FileManager = .default) throws -> URL {
        if let groupContainer = sharedContainerURL(fileManager: fileManager) {
            let widgetDirectory = groupContainer.appendingPathComponent(
                widgetDirectoryName,
                isDirectory: true
            )
            try fileManager.createDirectory(
                at: widgetDirectory,
                withIntermediateDirectories: true
            )
            return widgetDirectory.appendingPathComponent(widgetSnapshotFilename)
        }

        return try applicationSupportDirectoryURL(fileManager: fileManager)
            .appendingPathComponent(widgetSnapshotFilename)
    }
}

public enum OneSystemRoute: Codable, Hashable, Sendable {
    case addNote(anchorDate: String?)
    case addTask
    case addExpense
    case addIncome
    case confirmTodayItem(itemType: ItemType, itemId: String, dateLocal: String)

    public func url() -> URL {
        var components = URLComponents()
        components.scheme = OneSharedSystem.routeScheme
        components.host = OneSharedSystem.routeHost

        switch self {
        case .addNote(let anchorDate):
            components.path = "/add-note"
            if let anchorDate {
                components.queryItems = [
                    URLQueryItem(name: "date", value: anchorDate)
                ]
            }
        case .addTask:
            components.path = "/add-task"
        case .addExpense:
            components.path = "/add-expense"
        case .addIncome:
            components.path = "/add-income"
        case .confirmTodayItem(let itemType, let itemId, let dateLocal):
            components.path = "/today-confirm"
            components.queryItems = [
                URLQueryItem(name: "itemType", value: itemType.rawValue),
                URLQueryItem(name: "itemId", value: itemId),
                URLQueryItem(name: "date", value: dateLocal),
            ]
        }

        return components.url ?? URL(string: "\(OneSharedSystem.routeScheme)://\(OneSharedSystem.routeHost)")!
    }

    public init?(url: URL) {
        guard url.scheme?.lowercased() == OneSharedSystem.routeScheme,
              url.host?.lowercased() == OneSharedSystem.routeHost else {
            return nil
        }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let queryItems = components?.queryItems ?? []
        let queryLookup = Dictionary(uniqueKeysWithValues: queryItems.map { ($0.name, $0.value) })

        switch path {
        case "add-note":
            self = .addNote(anchorDate: queryLookup["date"] ?? nil)
        case "add-task":
            self = .addTask
        case "add-expense":
            self = .addExpense
        case "add-income":
            self = .addIncome
        case "today-confirm":
            guard let itemTypeValue = queryLookup["itemType"] ?? nil,
                  let itemType = ItemType(rawValue: itemTypeValue),
                  let itemId = queryLookup["itemId"] ?? nil,
                  let dateLocal = queryLookup["date"] ?? nil else {
                return nil
            }
            self = .confirmTodayItem(itemType: itemType, itemId: itemId, dateLocal: dateLocal)
        default:
            return nil
        }
    }
}

public enum OneSystemRouteStore {
    public static func storePending(_ route: OneSystemRoute) throws {
        let data = try JSONEncoder().encode(route)
        let url = try OneSharedSystem.pendingRouteURL()
        try data.write(to: url, options: .atomic)
    }

    public static func consumePending() -> OneSystemRoute? {
        let fileManager = FileManager.default
        guard let url = try? OneSharedSystem.pendingRouteURL(fileManager: fileManager),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        try? fileManager.removeItem(at: url)
        return try? JSONDecoder().decode(OneSystemRoute.self, from: data)
    }
}
