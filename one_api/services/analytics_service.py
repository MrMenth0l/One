from __future__ import annotations

from datetime import date, timedelta

from sqlalchemy.orm import Session

from one.analytics import compute_daily_summaries, compute_habit_streak, period_bounds, summarize_period
from one.tracking import is_habit_scheduled
from one.models import PeriodType
from one_api.db import mappers
from one_api.db.repositories import CompletionLogRepository, HabitRepository, PreferencesRepository, TodoRepository


class AnalyticsService:
    def __init__(self, db: Session):
        self.db = db
        self.habits = HabitRepository(db)
        self.todos = TodoRepository(db)
        self.logs = CompletionLogRepository(db)
        self.preferences = PreferencesRepository(db)

    def daily_range(self, *, user_id: str, timezone: str, start_date: date, end_date: date):
        habits = [mappers.to_habit(row) for row in self.habits.list_for_user(user_id)]
        todos = [mappers.to_todo(row) for row in self.todos.list_for_user(user_id)]
        logs = [mappers.to_completion_log(row) for row in self.logs.list_for_user(user_id)]
        return compute_daily_summaries(
            user_id=user_id,
            start_date=start_date,
            end_date=end_date,
            timezone=timezone,
            habits=habits,
            todos=todos,
            completion_logs=logs,
        )

    def period_summary(self, *, user_id: str, timezone: str, anchor_date: date, period_type: PeriodType):
        prefs = self.preferences.get_or_create(user_id)
        period_start, period_end = period_bounds(
            anchor_date=anchor_date,
            period_type=period_type,
            week_start=prefs.week_start,
        )
        daily = self.daily_range(
            user_id=user_id,
            timezone=timezone,
            start_date=period_start,
            end_date=period_end,
        )
        return summarize_period(
            period_type=period_type,
            anchor_date=anchor_date,
            daily_summaries=daily,
            week_start=prefs.week_start,
        )

    def habit_stats(
        self,
        *,
        user_id: str,
        habit_id: str,
        anchor_date: date,
        window_days: int = 30,
    ) -> dict:
        row = self.habits.get(user_id, habit_id)
        if row is None:
            raise KeyError("habit_not_found")

        habit = mappers.to_habit(row)
        logs = [mappers.to_completion_log(entry) for entry in self.logs.list_for_user(user_id)]
        streak_current = compute_habit_streak(
            habit=habit,
            completion_logs=logs,
            anchor_date=anchor_date,
        )

        start = anchor_date - timedelta(days=max(window_days - 1, 0))
        completed_dates = {
            log.date_local
            for log in logs
            if log.item_type.value == "habit"
            and log.item_id == habit_id
            and log.state.value == "completed"
            and start <= log.date_local <= anchor_date
        }
        expected_window = 0
        for day_offset in range((anchor_date - start).days + 1):
            cursor = start + timedelta(days=day_offset)
            if is_habit_scheduled(habit, cursor):
                expected_window += 1
        completed_window = len(completed_dates)
        completion_rate_window = completed_window / expected_window if expected_window else 0.0
        last_completed_date = max(completed_dates) if completed_dates else None

        return {
            "habit_id": habit_id,
            "anchor_date": anchor_date,
            "window_days": window_days,
            "streak_current": streak_current,
            "completed_window": completed_window,
            "expected_window": expected_window,
            "completion_rate_window": completion_rate_window,
            "last_completed_date": last_completed_date,
        }
