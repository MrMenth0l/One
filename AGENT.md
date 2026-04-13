# One Agent Guide

## Project Summary

One is a personal operating system product with two active code surfaces in one repo: a Python backend/domain layer (`one/`, `one_api/`, Alembic migrations, `tests/`) and a native iOS client (`ios/OneClient/` Swift package plus `ios/OneApp/` Xcode app wrapper). The iOS app is currently local-first by default, but the FastAPI backend remains the source for API development, persistence, and schema evolution.

## Repository Map

- `one/`: pure domain logic for tracking, analytics, reflections, notifications, onboarding bootstrap, and coaching.
- `one_api/`: FastAPI app, auth providers, routers, services, SQLAlchemy models/mappers/repositories, and settings.
- `alembic/` and `alembic.ini`: schema migrations and migration config.
- `tests/`: Python `unittest` coverage for domain logic, API flows, migrations, and contract checks.
- `api/openapi.yaml`: checked-in API contract snapshot; backend tests assert against it.
- `ios/OneClient/`: Swift package with shared app logic, offline persistence, networking, `OneClientChecks`, and `OneAppHost`.
- `ios/OneApp/`: XcodeGen source (`project.yml`), generated `OneApp.xcodeproj`, app target, configs, plists, and unit tests.
- `docs/architecture-implementation.md`: current architecture baseline.

Generated or local-only areas:

- `.deriveddata/`: local Xcode build output under repo root; ignore it during search and code mapping.
- `.build/`, `.venv/`, `*.db`, `*.egg-info/`: generated artifacts or local state.

## Commands

Backend setup:

```bash
python3 -m venv .venv
.venv/bin/python -m pip install --upgrade pip
.venv/bin/python -m pip install -e .
```

Backend database and API:

```bash
DATABASE_URL=sqlite+pysqlite:///./one.db .venv/bin/alembic upgrade head
.venv/bin/uvicorn one_api.main:app --host 0.0.0.0 --port 8000 --reload
```

Backend validation:

```bash
.venv/bin/python -m unittest discover -s tests -v
.venv/bin/python -m unittest tests.test_backend_api -v
.venv/bin/python -m unittest tests.test_tracking -v
```

iOS / Swift package:

```bash
cd ios/OneClient && swift build
cd ios/OneClient && swift run OneClientChecks
cd ios/OneClient && swift run OneAppHost
```

Xcode project maintenance:

```bash
cd ios/OneApp && xcodegen generate
xcodebuild -list -project ios/OneApp/OneApp.xcodeproj
```

Simulator-dependent app tests:

- Use Xcode with the `OneApp` scheme and `OneAppTests` target, or adapt the `xcodebuild test` example in [`README.md`](/Users/yehosuahercules/Desktop/Misc./One./README.md) to a simulator installed on the current machine.

What is not configured here:

- No repo-level lint, format, or static typecheck command is configured in `pyproject.toml` or root tooling files.
- Python tests use `unittest`, not `pytest`.

## Conventions

- Treat `ios/OneApp/project.yml` as the source of truth for project structure. Regenerate `ios/OneApp/OneApp.xcodeproj` with XcodeGen after project changes; avoid hand-editing `project.pbxproj` unless absolutely necessary.
- Treat Alembic migrations as the schema source of truth. `one_api.main` calls `Base.metadata.create_all()` at startup only as a development safety net.
- Keep `api/openapi.yaml` in sync with backend API changes. `tests/test_backend_api.py` loads that file directly and asserts expected paths and schemas.
- The iOS app reads `ONE_API_BASE_URL` from `Info.Debug.plist` / `Info.Release.plist`, but `AppEnvironment` currently resolves runtime mode to local and supports a debug override via `one.debug.api_base_url_override`.
- Debug iOS builds allow arbitrary HTTP loads for local development; Release turns that off.

## Validation Before Handoff

- Backend or domain changes: run `.venv/bin/python -m unittest discover -s tests -v`.
- Migration changes: run `DATABASE_URL=sqlite+pysqlite:///./scratch.db .venv/bin/alembic upgrade head` against a throwaway SQLite file, then remove it.
- Swift package changes: run `cd ios/OneClient && swift run OneClientChecks`.
- Xcode/project changes: regenerate with `cd ios/OneApp && xcodegen generate`, then at minimum run `xcodebuild -list -project ios/OneApp/OneApp.xcodeproj`. Run simulator tests when the app target, test target, or project wiring changed.

## Warnings and Guardrails

- Ignore `.deriveddata/` during exploration; it contains thousands of generated files and will drown real source searches.
- Local SQLite files are normal in this repo (`one.db`, migration scratch DBs, test DBs). Do not treat them as source files.
- There is no CI config checked into the repo, so local validation is the current source of truth.
- `ios/OneClient/Sources/OneClient/Resources/kjv_lookup.json` is a large checked-in data file; prefer targeted searches when you do not need resource contents.

## Related Docs

- [`README.md`](/Users/yehosuahercules/Desktop/Misc./One./README.md)
- [`docs/architecture-implementation.md`](/Users/yehosuahercules/Desktop/Misc./One./docs/architecture-implementation.md)
