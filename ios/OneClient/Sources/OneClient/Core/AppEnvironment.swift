import Foundation

public struct AppEnvironment: Sendable, Equatable {
    public enum RuntimeMode: String, Sendable, CaseIterable {
        case local
        case remote
    }

    public static let debugBaseURLOverrideKey = "one.debug.api_base_url_override"
    public static let debugRuntimeModeKey = "one.debug.runtime_mode"

    public let apiBaseURL: URL
    public let runtimeMode: RuntimeMode

    public init(apiBaseURL: URL, runtimeMode: RuntimeMode = .local) {
        self.apiBaseURL = apiBaseURL
        self.runtimeMode = runtimeMode
    }

    public static func current(
        bundle: Bundle = .main,
        defaults: UserDefaults = .standard
    ) -> AppEnvironment {
        let runtimeMode = runtimeMode(from: bundle, defaults: defaults)

        if let override = defaults.string(forKey: debugBaseURLOverrideKey),
           let url = URL(string: override),
           url.scheme != nil {
            return AppEnvironment(apiBaseURL: url, runtimeMode: runtimeMode)
        }

        if let configured = bundle.object(forInfoDictionaryKey: "ONE_API_BASE_URL") as? String,
           let url = URL(string: configured),
           url.scheme != nil {
            return AppEnvironment(apiBaseURL: url, runtimeMode: runtimeMode)
        }

        return AppEnvironment(
            apiBaseURL: URL(string: "http://127.0.0.1:8000")!,
            runtimeMode: runtimeMode
        )
    }

    public static func setDebugBaseURLOverride(_ value: String?, defaults: UserDefaults = .standard) {
        if let value, !value.isEmpty {
            defaults.set(value, forKey: debugBaseURLOverrideKey)
            return
        }
        defaults.removeObject(forKey: debugBaseURLOverrideKey)
    }

    public static func setDebugRuntimeMode(_ value: RuntimeMode?, defaults: UserDefaults = .standard) {
        if let value {
            defaults.set(value.rawValue, forKey: debugRuntimeModeKey)
            return
        }
        defaults.removeObject(forKey: debugRuntimeModeKey)
    }

    private static func runtimeMode(
        from bundle: Bundle,
        defaults: UserDefaults
    ) -> RuntimeMode {
        _ = bundle
        _ = defaults
        return .local
    }
}
