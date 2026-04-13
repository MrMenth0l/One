#if canImport(WidgetKit) && os(iOS)
import WidgetKit

public enum OneWidgetReloader {
    public static func reloadTodayQueue() {
        WidgetCenter.shared.reloadTimelines(ofKind: OneWidgetKind.todayQueue)
    }

    public static func reloadControls() {
        guard #available(iOS 18.0, *) else {
            return
        }
        ControlCenter.shared.reloadAllControls()
    }

    public static func reloadAll() {
        reloadTodayQueue()
        reloadControls()
    }
}
#else
public enum OneWidgetReloader {
    public static func reloadTodayQueue() {}
    public static func reloadControls() {}
    public static func reloadAll() {}
}
#endif
