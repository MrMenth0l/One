# One (Vertical Slice Foundation)

This repository now includes a runnable vertical slice for **One**:
- `FastAPI + SQLAlchemy + Alembic` backend with PostgreSQL-ready schema/migrations.
- Additive `GET /today` API and server-defined tracking/analytics logic.
- Swift client package with a live HTTP API client, session persistence, local reminder scheduling, and a generated iOS app project for device deployment.

## What is implemented

- Domain entities for users, habits, todos, categories, completion logs, reflections, reminders, coach cards, and preferences.
- Core tracking logic:
  - Habit recurrence evaluation (`DAILY`, `WEEKLY`, `MONTHLY`, `YEARLY` patterns)
  - Daily habit log materialization (`not_completed` default)
  - Binary completion toggles
  - Today ordering model: pinned todos -> urgent todos -> scheduled habits -> remaining todos
- Analytics logic:
  - Daily summaries
  - Weekly/monthly/yearly calendar rollups
  - Habit streaks and daily action streak
  - Contribution heatmap intensity generation
- Reflection subsystem:
  - Period prompts (daily/weekly/monthly/yearly)
  - Upsert/list/search behavior
- Notification subsystem:
  - Quiet-hours filtering
  - Due reminder evaluation
  - Grouping of close reminders to reduce noise
- Onboarding bootstrap:
  - Default categories
  - Initial user preferences bundle
- Coaching content selection:
  - Curated active card filtering by date/tags
- API contract:
  - OpenAPI spec at [`api/openapi.yaml`](/Users/yehosuahercules/Desktop/Misc./One./api/openapi.yaml)
  - Additive `GET /today` endpoint with `TodayResponse`
- Backend service:
  - [`one_api/`](/Users/yehosuahercules/Desktop/Misc./One./one_api) with layered structure:
    - routers -> services -> repositories -> domain logic (`one/`)
- Migrations:
  - Alembic config + initial migration under [`alembic/`](/Users/yehosuahercules/Desktop/Misc./One./alembic)
- iOS client scaffold:
  - Swift package at [`ios/OneClient/`](/Users/yehosuahercules/Desktop/Misc./One./ios/OneClient)
  - `OneAppHost` executable target with SwiftUI auth gate + tabs (`Home`, `Today`, `Analytics`, `Profile`)
  - `HTTPAPIClient` with typed wire DTO mapping and bearer-token session handling
  - `KeychainAuthSessionStore` (with in-memory fallback)
  - Local notification scheduling via `UNUserNotificationCenter` adapter (iOS)
  - SwiftData-backed sync queue selection on iOS runtime (fallback to in-memory)
  - `CoachSheet` and standalone notification preferences UI
- iOS app project:
  - Generated Xcode project at [`ios/OneApp/OneApp.xcodeproj`](/Users/yehosuahercules/Desktop/Misc./One./ios/OneApp/OneApp.xcodeproj)
  - `Debug`/`Release` Info.plist split with Debug-only HTTP ATS allowance
  - `OneAppTests` unit test target scaffold

## Module map

- [`one/models.py`](/Users/yehosuahercules/Desktop/Misc./One./one/models.py): core entities and enums
- [`one/tracking.py`](/Users/yehosuahercules/Desktop/Misc./One./one/tracking.py): recurrence, today list, completion state
- [`one/analytics.py`](/Users/yehosuahercules/Desktop/Misc./One./one/analytics.py): rollups, streaks, heatmap
- [`one/reflections.py`](/Users/yehosuahercules/Desktop/Misc./One./one/reflections.py): note prompts and CRUD-like helpers
- [`one/notifications.py`](/Users/yehosuahercules/Desktop/Misc./One./one/notifications.py): reminder scheduling logic
- [`one/bootstrap.py`](/Users/yehosuahercules/Desktop/Misc./One./one/bootstrap.py): onboarding defaults
- [`one/coaching.py`](/Users/yehosuahercules/Desktop/Misc./One./one/coaching.py): curated coach card selection
- [`one_api/main.py`](/Users/yehosuahercules/Desktop/Misc./One./one_api/main.py): FastAPI app entrypoint
- [`one_api/services/today_service.py`](/Users/yehosuahercules/Desktop/Misc./One./one_api/services/today_service.py): server-defined Today ordering/materialization
- [`ios/OneClient/Sources/OneClient/`](/Users/yehosuahercules/Desktop/Misc./One./ios/OneClient/Sources/OneClient): iOS module scaffold

## Run tests

```bash
. .venv/bin/activate
python -m unittest discover -s tests -v
```

## Run migrations

```bash
. .venv/bin/activate
python -m alembic upgrade head
```

## Run API locally

```bash
. .venv/bin/activate
uvicorn one_api.main:app --host 0.0.0.0 --port 8000 --reload
```

## Build iOS client package

```bash
cd ios/OneClient
swift build
```

## Run iOS package checks

```bash
cd ios/OneClient
swift run OneClientChecks
```

## Run app host target

```bash
cd ios/OneClient
swift run OneAppHost
```

## Generate iOS Xcode project

```bash
cd ios/OneApp
xcodegen generate
```

## iPhone 13 deployment preflight

1. Install full Xcode from the App Store.
2. Select full Xcode as active developer directory:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
xcodebuild -version
```

3. Ensure iPhone and Mac are on the same Wi-Fi network.
4. Start backend on LAN-accessible host:

```bash
. .venv/bin/activate
uvicorn one_api.main:app --host 0.0.0.0 --port 8000
```

5. In the app, set `Profile -> Debug API URL` to `http://<your-mac-lan-ip>:8000`.
6. Open `ios/OneApp/OneApp.xcodeproj` in Xcode, choose your Personal Team, connect iPhone 13, and run `OneApp`.

## iOS base URL configuration

- Default base URL comes from app Info.plist (`ONE_API_BASE_URL`).
- Debug override is stored under `one.debug.api_base_url_override` and can be set from Profile -> Debug API URL.
