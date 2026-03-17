# One Architecture Implementation Baseline

This document maps the architecture plan into concrete repository artifacts.

## Implemented now

- Domain model and product contracts for all core entities.
- Tracking logic for recurring habits, one-off todos, binary completion state, and Today ordering.
- Analytics engine for daily summaries, calendar rollups, streaks, and contribution heatmap intensity.
- Reflection prompts + note upsert/list/search behavior.
- Reminder evaluation with quiet-hours support and grouping.
- Curated coach card selection.
- Onboarding bootstrap defaults (categories + user preferences).
- OpenAPI contract, including additive `GET /today` with `TodayResponse`.
- FastAPI backend layers: routers -> services -> repositories -> domain.
- SQLAlchemy persistence + Alembic initial schema migration.
- Swift client package with:
  - live HTTP API transport + typed DTO mapping
  - bearer token session persistence (Keychain with in-memory fallback)
  - app host target for auth, today, analytics, profile, coach, and notification preferences
  - sync queue + reminder planning utilities
  - iOS local notification scheduling adapter (`UNUserNotificationCenter`)
- Generated iOS app project under `ios/OneApp`:
  - app target (`OneApp`) consuming local `OneClient` package
  - unit-test target (`OneAppTests`)
  - Debug/Release Info.plist split for Debug-only ATS HTTP allowance

## Files of record

- Domain and feature logic: [`one/`](/Users/yehosuahercules/Desktop/Misc./One./one)
- API contract: [`api/openapi.yaml`](/Users/yehosuahercules/Desktop/Misc./One./api/openapi.yaml)
- Behavioral checks: [`tests/`](/Users/yehosuahercules/Desktop/Misc./One./tests)
- Backend app: [`one_api/`](/Users/yehosuahercules/Desktop/Misc./One./one_api)
- DB migrations: [`alembic/`](/Users/yehosuahercules/Desktop/Misc./One./alembic)
- iOS package: [`ios/OneClient/`](/Users/yehosuahercules/Desktop/Misc./One./ios/OneClient)

## Implementation boundaries

- Backend uses managed-auth adapter interfaces (Supabase-ready + dev fallback).
- Persistence is migration-driven; hard delete is used in this phase.
- iOS package compiles and includes an app-host executable for manual end-to-end flow checks.
- iOS app project exists for real device deployment, but requires full Xcode toolchain selection on host machine.
- Local reminders are client-side only; backend push/APNs is intentionally deferred.

## Immediate next implementation layer

1. Add APNs token registration + push scheduling layer (post-MVP).
2. Add richer sync conflict telemetry and retry backoff policy.
3. Expand iOS endpoint coverage (reflections, category management UX polish).
4. Add automated UI tests for device smoke flow in Xcode test plans.
