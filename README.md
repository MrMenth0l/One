# One

One is a personal operating system for daily execution: habits, tasks, reflections, analytics, reminders, and lightweight finance tracking in a single product surface.

This repository contains:

- A Python domain and API layer built with FastAPI, SQLAlchemy, and Alembic.
- A native iOS client package with the shared app logic and UI system.
- A generated Xcode project for running the iPhone app and unit tests.

The current iOS app is designed to run local-first. The backend remains available for API development, schema evolution, and service-backed flows.

## Architecture

### Backend

- `one/`: core domain logic for tracking, analytics, reflections, notifications, onboarding, and coaching.
- `one_api/`: FastAPI application, routers, services, auth providers, persistence, and API schemas.
- `alembic/`: database migrations.
- `api/openapi.yaml`: API contract snapshot.

### iOS

- `ios/OneClient/`: Swift package that contains the app models, repositories, local persistence, networking, and UI features.
- `ios/OneApp/`: XcodeGen project definition, generated Xcode project, app target, and unit tests.

## Core Capabilities

- Habit and to-do management with today-oriented planning.
- Reflection periods for daily, weekly, monthly, and yearly reviews.
- Analytics rollups, streaks, heatmaps, and period summaries.
- Local notification scheduling for reminders.
- Finance tracking with categories, recurring items, and reporting views.
- WidgetKit Today queue and app-intent based quick entry flows.
- Local onboarding defaults, category/icon systems, and design assets.

## Tech Stack

- Python 3.12
- FastAPI
- SQLAlchemy 2
- Alembic
- Pydantic Settings
- Swift 6 package tooling for shared client code
- SwiftUI + SwiftData on iOS
- XcodeGen for project generation

## Requirements

- Python 3.12+
- A virtual environment tool of your choice
- Xcode 17+ for iOS development
- XcodeGen if you want to regenerate the Xcode project from `ios/OneApp/project.yml`

## Quick Start

### 1. Create the Python environment

```bash
python3.12 -m venv .venv
. .venv/bin/activate
pip install --upgrade pip
pip install -e .
```

### 2. Apply database migrations

By default, the API uses the local SQLite database at `./one.db`.

```bash
. .venv/bin/activate
python -m alembic upgrade head
```

### 3. Run the API

```bash
. .venv/bin/activate
uvicorn one_api.main:app --host 0.0.0.0 --port 8000 --reload
```

Available local endpoints:

- `GET /healthz`
- `GET /metrics/snapshot`
- OpenAPI docs at `/docs`

## Configuration

Settings are loaded from environment variables and optionally from `.env`.

### Supported backend settings

```env
APP_NAME=One API
ENVIRONMENT=development
DATABASE_URL=sqlite+pysqlite:///./one.db

SUPABASE_URL=
SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=

DEV_AUTH_SECRET=change-me-in-prod
ACCESS_TOKEN_TTL_SECONDS=3600
REFRESH_TOKEN_TTL_SECONDS=2592000
```

### Authentication modes

- Default development mode uses the in-repo auth provider backed by `DEV_AUTH_SECRET`.
- Supabase can be enabled by supplying the Supabase settings above.

## iOS Development

### Swift package commands

Build the shared client package:

```bash
cd ios/OneClient
swift build
```

Run the package checks executable:

```bash
cd ios/OneClient
swift run OneClientChecks
```

Run the app host executable:

```bash
cd ios/OneClient
swift run OneAppHost
```

### Xcode project

Open the existing project:

- `ios/OneApp/OneApp.xcodeproj`

If needed, regenerate it from XcodeGen:

```bash
cd ios/OneApp
xcodegen generate
```

### Base URL behavior

- The app reads `ONE_API_BASE_URL` from its Info.plist configuration.
- A debug override can be stored in-app under `one.debug.api_base_url_override`.
- The current product direction is local-first, so many flows work without a live backend.

### Widgets and app shortcuts

- The iOS app now includes `OneWidgetsExtension` for a Today queue widget and quick-entry controls.
- Shared routing between the app, widgets, and shortcuts is implemented with the `one://action/...` URL scheme.
- The shared SwiftData store is app-group backed through `group.com.yehosuah.one.shared`.

## Testing

### Python tests

```bash
. .venv/bin/activate
python -m unittest discover -s tests -v
```

### iOS tests

From Xcode, run the `OneApp` scheme and its `OneAppTests` target.

From the command line, an example invocation is:

```bash
xcodebuild test \
  -project ios/OneApp/OneApp.xcodeproj \
  -scheme OneApp \
  -destination 'platform=iOS Simulator,OS=26.3.1,name=iPhone 17' \
  -derivedDataPath .deriveddata/OneAppTests \
  CODE_SIGNING_ALLOWED=NO
```

Use an installed simulator available on your machine if that exact destination differs.

## Repository Map

### Backend

- `one/models.py`: shared domain entities and enums.
- `one/tracking.py`: recurrence evaluation, materialization, and today ordering.
- `one/analytics.py`: summaries, streaks, and contribution data.
- `one/reflections.py`: reflection prompts and note helpers.
- `one/notifications.py`: reminder scheduling logic.
- `one/bootstrap.py`: onboarding defaults.
- `one/coaching.py`: coach card selection.
- `one_api/main.py`: FastAPI entrypoint.
- `one_api/api/`: HTTP routers.
- `one_api/services/`: service layer orchestration.
- `one_api/db/`: SQLAlchemy models, mappers, repositories, and session setup.
- `one_api/schemas.py`: request and response contracts.

### iOS

- `ios/OneClient/Sources/OneClient/Core/`: shared models, iconography, and core systems.
- `ios/OneClient/Sources/OneClient/Features/`: SwiftUI app features and view models.
- `ios/OneClient/Sources/OneClient/Offline/`: local-first persistence and services.
- `ios/OneClient/Sources/OneClient/Repositories/`: repository layer and sync queue.
- `ios/OneApp/OneApp/`: app entrypoint and platform assets.
- `ios/OneApp/OneAppTests/`: unit test suite.

## Design Assets

The repository also includes working design references used during implementation:

- `one-ios-design.html`
- `one-iconography-system.html`
- `logo.png`

## Additional Docs

- `docs/widgetkit-implementation-note.md`
- `docs/emotional-tone.md`
- `docs/analytics-parallelization-plan.md`

## Icon Workflow

- Raw SVG exports live under `ios/OneClient/Sources/OneClient/Resources/StreamlineExports/`.
- The semantic-to-asset mapping lives in `ios/OneClient/Sources/OneClient/Resources/streamline-lucide-manifest.json`.
- Rebuild the iOS asset catalog with `python3 tools/sync_streamline_icons.py`.

## Notes

- The repository ignores generated Xcode build output under `.deriveddata/`.
- `one.db` is a local development database artifact.
- The backend creates tables on startup as a development safety net, but migrations remain the correct source of truth.
