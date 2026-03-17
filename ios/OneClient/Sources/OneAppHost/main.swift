#if canImport(SwiftUI)
import SwiftUI
import OneClient

@main
struct OneAppHost: App {
    var body: some Scene {
        WindowGroup {
            OneAppShell()
        }
    }
}
#else
@main
struct OneAppHost {
    static func main() {
        print("SwiftUI runtime not available for OneAppHost in this environment.")
    }
}
#endif
