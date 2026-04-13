import SwiftUI
import OneClient
#if canImport(AppIntents)
import AppIntents
#endif
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
private final class OneAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if let url = launchOptions?[.url] as? URL {
            _ = OneLaunchRouteIngress.capture(url)
        }
        return true
    }

    func application(
        _ application: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        OneLaunchRouteIngress.capture(url)
    }
}

private enum OneLaunchRouteIngress {
    static func capture(_ url: URL) -> Bool {
        guard let route = OneSystemRoute(url: url) else {
            return false
        }
        try? OneSystemRouteStore.storePending(route)
        return true
    }
}
#endif

@main
struct OneApp: App {
    #if canImport(UIKit)
    @UIApplicationDelegateAdaptor(OneAppDelegate.self) private var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            OneAppShell()
        }
    }
}
