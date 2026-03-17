from __future__ import annotations

from datetime import UTC, datetime

from sqlalchemy.orm import Session

from one.models import CompletionState, ItemType
from one.tracking import set_todo_completion
from one_api.db import mappers
from one_api.db.repositories import CompletionLogRepository, TodoRepository


class TaskService:
    def __init__(self, db: Session):
        self.db = db
        self.todos = TodoRepository(db)
        self.logs = CompletionLogRepository(db)

    @staticmethod
    def _parse_client_timestamp(raw: str | None) -> datetime | None:
        if not raw:
            return None
        try:
            dt = datetime.fromisoformat(raw.replace("Z", "+00:00"))
            if dt.tzinfo is None:
                return dt.replace(tzinfo=UTC)
            return dt.astimezone(UTC)
        except ValueError:
            return None

    def apply_todo_patch(
        self,
        *,
        todo_row,
        payload: dict,
        client_updated_at: str | None,
    ):
        # Server-authoritative last-write-wins.
        client_ts = self._parse_client_timestamp(client_updated_at)
        server_ts = todo_row.updated_at
        if server_ts is not None and server_ts.tzinfo is None:
            server_ts = server_ts.replace(tzinfo=UTC)

        if client_ts and server_ts and client_ts < server_ts:
            return todo_row

        now = datetime.now(UTC)
        for field in ["category_id", "title", "notes", "due_at", "priority", "is_pinned", "status"]:
            if field in payload and payload[field] is not None:
                setattr(todo_row, field, payload[field])

        if payload.get("status") == "completed" and todo_row.completed_at is None:
            todo_row.completed_at = now
        if payload.get("status") == "open":
            todo_row.completed_at = None

        todo_row.updated_at = now
        return todo_row

    def write_completion(
        self,
        *,
        user_id: str,
        item_type: ItemType,
        item_id: str,
        date_local,
        state: CompletionState,
        source: str,
    ):
        completed_at = datetime.now(UTC) if state is CompletionState.COMPLETED else None

        if item_type is ItemType.TODO:
            todo_row = self.todos.get(user_id, item_id)
            if todo_row is None:
                raise ValueError("Todo not found")
            todo = mappers.to_todo(todo_row)
            set_todo_completion(todo, completed=(state is CompletionState.COMPLETED), completed_at=completed_at)
            todo_row.status = todo.status.value
            todo_row.completed_at = todo.completed_at
            todo_row.updated_at = todo.updated_at

        return self.logs.upsert(
            user_id=user_id,
            item_type=item_type.value,
            item_id=item_id,
            date_local=date_local,
            state=state.value,
            completed_at=completed_at,
            source=source,
        )
