# Analytics Parallelization Plan

## Purpose

Prepare the analytics renewal so three parallel implementation threads can work with low merge risk across:

- Finance analytics
- Habits/tasks analytics
- Notes intelligence

This document defines ownership, shared contracts, and merge rules grounded in the current repository layout.

## Current Audit

### Shared foundation

- `ios/OneClient/Sources/OneClient/Features/OneDesignSystem.swift`
  - Shared surface containers, section headers, segmented controls, activity lane.
- `ios/OneClient/Sources/OneClient/Features/OneInteractionSystem.swift`
  - Shared motion and interaction timing.
- `ios/OneClient/Sources/OneClient/Core/Models.swift`
  - Core period, summary, daily summary, note, sentiment, habit and task models.
- `ios/OneClient/Sources/OneClient/Features/AnalyticsContracts.swift`
  - Shared analytics presentation contracts and shared note-sentiment helpers.
- `ios/OneClient/Sources/OneClient/Features/ReviewAnalyticsComponents.swift`
  - Shared review analytics UI primitives and contribution/sentiment views.
- `ios/OneClient/Sources/OneClient/Repositories/Repositories.swift`
  - Shared analytics and reflections repository protocols.
- `ios/OneClient/Sources/OneClient/Core/OneIconography.swift`
  - Shared icon tokens for analytics, finance, habits, notes, streaks, and sentiments.

### Habits/tasks-owned

- `ios/OneClient/Sources/OneClient/Offline/OfflineServices.swift`
  - `LocalAnalyticsService` for daily summaries, streaks, period summaries, habit stats.
- `ios/OneClient/Sources/OneClient/Features/ViewModels.swift`
  - `AnalyticsViewModel`, analytics presentation shaping, execution split, recovery rows.
- `one/analytics.py`
  - Backend period summaries, daily summaries, streaks.
- `one_api/services/analytics_service.py`
  - Backend orchestration for habits/tasks analytics.
- `one_api/api/analytics.py`
  - Analytics endpoints.

### Notes-owned

- `ios/OneClient/Sources/OneClient/Features/ViewModels.swift`
  - `NotesViewModel`, note-period navigation and note-specific sentiment summary state.
- `ios/OneClient/Sources/OneClient/Offline/OfflinePersistence.swift`
  - Reflection persistence and mapping.
- `ios/OneClient/Sources/OneClient/Networking/APIClient.swift`
  - Reflection note fetch/upsert/delete client contract.
- `one/reflections.py`
  - Reflection prompt and note helpers.
- `one_api/api/reflections.py`
  - Reflections endpoints.

### Finance-owned

- `ios/OneClient/Sources/OneClient/Core/FinanceModels.swift`
  - Finance analytics models, chart points, comparison points, insight summary.
- `ios/OneClient/Sources/OneClient/Offline/OfflineFinanceServices.swift`
  - `LocalFinanceAnalyticsService`, cashflow snapshots, warnings, comparisons.
- `ios/OneClient/Sources/OneClient/Offline/OfflineFinancePersistence.swift`
  - Finance local data reads/writes.
- `ios/OneClient/Sources/OneClient/Repositories/FinanceRepositories.swift`
  - Finance repository contracts and implementation.
- `ios/OneClient/Sources/OneClient/Features/FinanceViewModels.swift`
  - `FinanceViewModel`.
- `ios/OneClient/Sources/OneClient/Features/FinanceFeature.swift`
  - Finance analytics and reporting UI.

### Currently overloaded or ambiguous

- `ios/OneClient/Sources/OneClient/Features/AppShell.swift`
  - Review composition mixes habits/tasks analytics, note sentiment overlays, and notes workspace entry.
- `ios/OneClient/Sources/OneClient/Features/ViewModels.swift`
  - Contains both habits/tasks analytics orchestration and notes view-model logic.
- `ios/OneClient/Sources/OneClient/Repositories/Repositories.swift`
  - Analytics and reflections repository protocols share one file, but contracts are now stable enough to treat as extension-only.

## Shared vs Domain-Specific Map

### Must stay shared

- Period/date abstractions: `PeriodType`, `PeriodSummary`, `DailySummary`, `AnalyticsDateRange`
- Shared analytics presentation contracts: `Analytics*` types in `AnalyticsContracts.swift`
- Shared review analytics UI primitives in `ReviewAnalyticsComponents.swift`
- Shared visual system: `OneTheme`, `OneType`, `OneSpacing`, `OneMotion`
- Shared note-sentiment summarization helper: `reflectionSentimentSummary`

### Must stay domain-specific

- Finance chart semantics, cashflow comparisons, warning logic, recurring burden logic
- Habit/task completion aggregation, streak logic, recovery logic, execution split logic
- Notes period navigation, semantic/sentiment inference, note-specific summaries and drill-downs

### Controlled shared extension only

- `AnalyticsContracts.swift`
- `ReviewAnalyticsComponents.swift`
- `OneDesignSystem.swift`
- `OneInteractionSystem.swift`
- `Repositories.swift`

## Thread Boundaries

### Thread A: Finance Analytics Renewal

- Primary files:
  - `ios/OneClient/Sources/OneClient/Features/FinanceFeature.swift`
  - `ios/OneClient/Sources/OneClient/Features/FinanceViewModels.swift`
  - `ios/OneClient/Sources/OneClient/Offline/OfflineFinanceServices.swift`
  - `ios/OneClient/Sources/OneClient/Core/FinanceModels.swift`
  - `ios/OneClient/Sources/OneClient/Repositories/FinanceRepositories.swift`
- Secondary files:
  - `ios/OneClient/Sources/OneClient/Core/OneIconography.swift`
  - `ios/OneClient/Sources/OneClient/Features/OneDesignSystem.swift`
- Do not modify unless exceptional:
  - `AppShell.swift`
  - `ViewModels.swift`
  - `AnalyticsContracts.swift`
  - `ReviewAnalyticsComponents.swift`

### Thread B: Habits/Tasks Analytics Renewal

- Primary files:
  - `ios/OneClient/Sources/OneClient/Features/ViewModels.swift`
    - `AnalyticsViewModel` area only
  - `ios/OneClient/Sources/OneClient/Offline/OfflineServices.swift`
    - `LocalAnalyticsService` area only
  - `one/analytics.py`
  - `one_api/services/analytics_service.py`
  - `one_api/api/analytics.py`
- Secondary files:
  - `ios/OneClient/Sources/OneClient/Features/AppShell.swift`
    - review composition only
  - `ios/OneClient/Sources/OneClient/Features/ReviewAnalyticsComponents.swift`
    - extension-only if a truly shared review primitive is needed
- Do not modify unless exceptional:
  - Finance files
  - `NotesViewModel` area in `ViewModels.swift`
  - `AnalyticsContracts.swift`

### Thread C: Notes Intelligence Renewal

- Primary files:
  - `ios/OneClient/Sources/OneClient/Features/ViewModels.swift`
    - `NotesViewModel` area only
  - `ios/OneClient/Sources/OneClient/Offline/OfflinePersistence.swift`
  - `ios/OneClient/Sources/OneClient/Networking/APIClient.swift`
  - `one/reflections.py`
  - `one_api/api/reflections.py`
- Secondary files:
  - `ios/OneClient/Sources/OneClient/Features/AppShell.swift`
    - notes page composition only
  - `ios/OneClient/Sources/OneClient/Features/ReviewAnalyticsComponents.swift`
    - extension-only for cross-domain note visualization primitives
- Do not modify unless exceptional:
  - Finance files
  - `LocalAnalyticsService` in `OfflineServices.swift`
  - `AnalyticsContracts.swift`

## Shared Contracts That Must Exist Before Parallel Work

These now exist and should be treated as stable:

- `AnalyticsContracts.swift`
  - Shared analytics DTOs for contribution grids, sentiment overview, execution split, recovery rows, chart series
- `ReviewAnalyticsComponents.swift`
  - Shared review analytics cards, tables, contribution grid, and sentiment trend renderer
- `AnalyticsDateRange` in `ViewModels.swift`
  - Shared period-bound calculation contract

## Merge Safety Rules

1. Domain threads own their primary files exclusively. If a change can be contained there, do not touch shared files.
2. Shared files are extension-only. Add generic capabilities; do not rename or restyle existing shared contracts casually.
3. No domain-specific assumptions in shared contracts. Avoid `Finance*`, `Habit*`, or `Note*` semantics inside `AnalyticsContracts.swift` and `ReviewAnalyticsComponents.swift`.
4. Shared UI changes require reuse proof. Only modify `ReviewAnalyticsComponents.swift` or `OneDesignSystem.swift` if the new behavior is reusable by at least two domains.
5. Cross-domain intelligence lives behind existing shared note-sentiment helpers or new dedicated helpers, not inside finance models.
6. Avoid duplicate helpers. Search `OfflineServices.swift`, `OfflineFinanceServices.swift`, `ViewModels.swift`, and `AnalyticsContracts.swift` before introducing new aggregation or trend utilities.
7. Keep visual identity domain-local. Domain-specific shape language, motion flavor, and chart semantics should live in domain feature files, not shared primitives.
8. `AppShell.swift` is composition-only. Put reusable subviews elsewhere; keep this file for wiring, routing, and section assembly.
9. `ViewModels.swift` is split by ownership in place. Thread B must stay inside `AnalyticsViewModel`; Thread C must stay inside `NotesViewModel` unless a shared helper extraction is explicitly required.

## Recommended Naming and Extension Patterns

- New shared analytics primitive:
  - `Analytics...`
- Finance-specific type:
  - `Finance...`
- Habits/tasks-specific type:
  - `Execution...`, `Habit...`, `Task...`, or `Recovery...`
- Notes-specific type:
  - `Notes...` or `Reflection...`
- Cross-domain intelligence helper:
  - `Review...` or `Analytics...`

## Overlap Risks

- Highest current risk:
  - `AppShell.swift`
  - `ViewModels.swift`
- Medium risk:
  - `Repositories.swift`
  - `OneDesignSystem.swift`
- Low risk:
  - Finance files versus notes files

## Minimal Changes Applied

To reduce collision before feature work starts:

1. Added `ios/OneClient/Sources/OneClient/Features/AnalyticsContracts.swift`
   - Moved shared analytics presentation models and note-sentiment helper logic out of `ViewModels.swift`.
2. Added `ios/OneClient/Sources/OneClient/Features/ReviewAnalyticsComponents.swift`
   - Moved shared review analytics UI components out of `AppShell.swift`.
3. Removed duplicated definitions from:
   - `ios/OneClient/Sources/OneClient/Features/ViewModels.swift`
   - `ios/OneClient/Sources/OneClient/Features/AppShell.swift`

These changes are behavior-preserving and reduce the likelihood that Threads B and C collide in monolithic files while still sharing the same stable contracts.
