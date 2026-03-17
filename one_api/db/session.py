from __future__ import annotations

from collections.abc import Generator
import time

from sqlalchemy import create_engine, event
from sqlalchemy.orm import Session, sessionmaker

from one_api.config import get_settings
from one_api.metrics import record_db_query_duration


settings = get_settings()
engine = create_engine(settings.database_url, future=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False, expire_on_commit=False, class_=Session)


@event.listens_for(engine, "before_cursor_execute")
def _before_cursor_execute(conn, cursor, statement, parameters, context, executemany):  # noqa: ANN001
    context._query_start_time = time.perf_counter()


@event.listens_for(engine, "after_cursor_execute")
def _after_cursor_execute(conn, cursor, statement, parameters, context, executemany):  # noqa: ANN001
    start = getattr(context, "_query_start_time", None)
    if start is None:
        return
    record_db_query_duration((time.perf_counter() - start) * 1000)


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
