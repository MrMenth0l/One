import Foundation

@MainActor
public final class OneWidgetSyncCoordinator {
    private let materializer: OneWidgetQueueMaterializer

    public init(materializer: OneWidgetQueueMaterializer = OneWidgetQueueMaterializer()) {
        self.materializer = materializer
    }

    public func syncTodayQueue(referenceDate: Date = Date()) async {
        do {
            let payload = try materializer.makePayload(referenceDate: referenceDate)
            try OneWidgetSnapshotStore.write(payload)
            OneWidgetReloader.reloadTodayQueue()
        } catch {
            // Preserve the last good payload when local store access fails.
        }
    }

    public func writeSignedOut() async {
        do {
            try OneWidgetSnapshotStore.write(.signedOut())
            OneWidgetReloader.reloadTodayQueue()
        } catch {
            // Preserve the last good payload when the shared container is unavailable.
        }
    }
}
