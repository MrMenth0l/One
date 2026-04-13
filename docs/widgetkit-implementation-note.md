# One WidgetKit / App Intents implementation note

## Relevant architecture inspected

- App entry and navigation live in `ios/OneClient/Sources/OneClient/Features/AppShell.swift`.
- The app is sheet-driven and already had native add-note, add-task, and finance quick-entry flows.
- Today ordering already lived in shared offline logic through `LocalTodayService.materialize(...)` and `TodayIntelligence`.
- Local SwiftData persistence is the source of truth.
- App Intents route into the app through a shared pending-route handoff in the app-group container.

## What was reused

- Existing Today ranking/materialization logic instead of duplicating queue rules in the widget extension.
- Existing note, task, finance, and Today completion flows instead of inventing parallel capture screens.
- Existing route handoff (`OneSystemRouteStore`) so controls and widget taps keep one ingress path.
- Existing theme/icon primitives so the widget and controls stay visually aligned with One.

## What was implemented

- A shared snapshot pipeline backed by `OneWidgetSnapshotStore`.
  - The app publishes a versioned JSON payload to the shared app-group container.
  - The widget extension only reads that payload and never opens SwiftData directly.
- A shared `OneWidgetKind.todayQueue` identifier so the app reloads the correct widget kind.
- `OneWidgetQueueMaterializer`, which reuses the app’s Today materialization path to build the mixed task/habit queue.
- `OneWidgetSyncCoordinator`, owned by `OneAppContainer`, which publishes the snapshot and reloads the widget timeline in one place.
- App-side snapshot publishing after bootstrap, full refresh, tasks-context refresh, task/habit mutations, Today completion, and Today reorder.
- Signed-out and first-launch fallback states so the widget shows an explicit state instead of a blank render.
- App-intent-backed controls for Add Note, Add Task, Add Expense, and Add Income, plus the Today confirmation route.

## Platform fallback

- Lock Screen uses the single-action `Add Note` control instead of forcing a speculative multi-action cluster.
- If no published snapshot exists yet, the Home Screen widget tells the user to open One once rather than trying to rebuild live state inside the extension.
