from __future__ import annotations

from fastapi import FastAPI

from one_api.api import analytics, auth, categories, coach_cards, completions, habits, preferences, reflections, today, todos, users
from one_api.config import get_settings
from one_api.db.base import Base
from one_api.db.session import engine
from one_api.metrics import snapshot
from one_api.observability import RequestLoggingMiddleware, configure_logging

settings = get_settings()
configure_logging()

app = FastAPI(title=settings.app_name, version="0.2.0")
app.add_middleware(RequestLoggingMiddleware)

app.include_router(auth.router)
app.include_router(users.router)
app.include_router(categories.router)
app.include_router(habits.router)
app.include_router(todos.router)
app.include_router(completions.router)
app.include_router(reflections.router)
app.include_router(coach_cards.router)
app.include_router(preferences.router)
app.include_router(analytics.router)
app.include_router(today.router)


@app.get("/healthz")
def healthz() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/metrics/snapshot")
def metrics_snapshot() -> dict:
    data = snapshot()
    return {"counters": data.counters, "timings_ms": data.timings_ms}


@app.on_event("startup")
def startup() -> None:
    # Development safety: ensures local boot in empty environments.
    Base.metadata.create_all(bind=engine)
