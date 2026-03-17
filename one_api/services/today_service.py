from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, date, datetime
from zoneinfo import ZoneInfo

from sqlalchemy.orm import Session

from one.tracking import build_today_items, materialize_habit_logs
from one_api.db import mappers
from one_api.db.repositories import CompletionLogRepository, HabitRepository, TodayOrderOverrideRepository, TodoRepository
from one_api.metrics import record_materialization_call


@dataclass(slots=True)
class TodayPayload:
    date_local: date
    items: list
    completed_count: int
    total_count: int
    completion_ratio: float


class TodayService:
    def __init__(self, db: Session):
        self.db = db
        self.habits = HabitRepository(db)
        self.todos = TodoRepository(db)
        self.logs = CompletionLogRepository(db)
        self.order_overrides = TodayOrderOverrideRepository(db)

    def get_today(self, *, user_id: str, timezone: str, target_date: date | None = None) -> TodayPayload:
        if target_date is not None:
            target = target_date
        else:
            target = datetime.now(UTC).astimezone(ZoneInfo(timezone)).date()

        habit_rows = self.habits.list_for_user(user_id)
        todo_rows = self.todos.list_for_user(user_id)
        log_rows = self.logs.list_for_date(user_id, target)

        habits = [mappers.to_habit(row) for row in habit_rows]
        todos = [mappers.to_todo(row) for row in todo_rows]
        logs = [mappers.to_completion_log(row) for row in log_rows]

        created_logs = materialize_habit_logs(
            user_id=user_id,
            habits=habits,
            target_date=target,
            existing_logs=logs,
            source="materializer",
        )
        for log in created_logs:
            self.logs.upsert(
                user_id=log.user_id,
                item_type=log.item_type.value,
                item_id=log.item_id,
                date_local=log.date_local,
                state=log.state.value,
                completed_at=log.completed_at,
                source=log.source,
            )

        record_materialization_call(len(created_logs))
        self.db.flush()

        all_logs = [mappers.to_completion_log(row) for row in self.logs.list_for_date(user_id, target)]
        items = build_today_items(
            today=target,
            timezone=timezone,
            habits=habits,
            todos=todos,
            completion_logs=all_logs,
        )
        overrides = self.order_overrides.list_for_date(user_id, target)
        items = self._apply_overrides(items, overrides)

        completed = sum(1 for item in items if item.completed)
        total = len(items)
        ratio = completed / total if total else 0.0

        return TodayPayload(
            date_local=target,
            items=items,
            completed_count=completed,
            total_count=total,
            completion_ratio=ratio,
        )

    def set_today_order(
        self,
        *,
        user_id: str,
        timezone: str,
        target_date: date,
        items: list[tuple[str, str, int]],
    ) -> TodayPayload:
        current = self.get_today(user_id=user_id, timezone=timezone, target_date=target_date)
        current_keys = {(item.item_type.value, item.item_id) for item in current.items}
        validated = [
            (item_type, item_id, order_index)
            for item_type, item_id, order_index in items
            if (item_type, item_id) in current_keys
        ]
        self.order_overrides.replace_for_date(user_id=user_id, target=target_date, items=validated)
        self.db.flush()
        return self.get_today(user_id=user_id, timezone=timezone, target_date=target_date)

    @staticmethod
    def _apply_overrides(items: list, overrides: list) -> list:
        if not overrides:
            return items

        order_lookup = {(row.item_type, row.item_id): row.order_index for row in overrides}
        indexed = list(enumerate(items))

        indexed.sort(
            key=lambda entry: (
                (entry[1].item_type.value, entry[1].item_id) not in order_lookup,
                order_lookup.get((entry[1].item_type.value, entry[1].item_id), 10_000),
                entry[0],
            )
        )
        return [item for _, item in indexed]
