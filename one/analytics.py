from __future__ import annotations

from dataclasses import dataclass
from datetime import date, timedelta

from .models import CompletionLog, CompletionState, Habit, PeriodType, Todo, TodoStatus
from .tracking import is_habit_scheduled, todo_action_date


@dataclass(slots=True)
class DailySummary:
    date_local: date
    completed_items: int
    expected_items: int
    completion_rate: float
    habit_completed: int
    habit_expected: int
    todo_completed: int
    todo_expected: int


@dataclass(slots=True)
class PeriodSummary:
    period_type: PeriodType
    period_start: date
    period_end: date
    completed_items: int
    expected_items: int
    completion_rate: float
    active_days: int
    consistency_score: float


@dataclass(slots=True)
class HeatmapCell:
    date_local: date
    intensity: int
    completed_items: int
    completion_rate: float


def period_bounds(anchor_date: date, period_type: PeriodType, week_start: int = 0) -> tuple[date, date]:
    if period_type is PeriodType.DAILY:
        return anchor_date, anchor_date

    if period_type is PeriodType.WEEKLY:
        offset = (anchor_date.weekday() - week_start) % 7
        start = anchor_date - timedelta(days=offset)
        return start, start + timedelta(days=6)

    if period_type is PeriodType.MONTHLY:
        start = anchor_date.replace(day=1)
        next_month = (start.replace(day=28) + timedelta(days=4)).replace(day=1)
        end = next_month - timedelta(days=1)
        return start, end

    if period_type is PeriodType.YEARLY:
        start = anchor_date.replace(month=1, day=1)
        end = anchor_date.replace(month=12, day=31)
        return start, end

    return anchor_date, anchor_date


def compute_daily_summary(
    *,
    user_id: str,
    target_date: date,
    timezone: str,
    habits: list[Habit],
    todos: list[Todo],
    completion_logs: list[CompletionLog],
) -> DailySummary:
    user_habits = [habit for habit in habits if habit.user_id == user_id]
    scheduled_habits = [habit for habit in user_habits if is_habit_scheduled(habit, target_date)]
    habit_expected = len(scheduled_habits)

    completed_habit_ids = {
        log.item_id
        for log in completion_logs
        if log.user_id == user_id
        and log.date_local == target_date
        and log.state is CompletionState.COMPLETED
    }
    habit_completed = sum(1 for habit in scheduled_habits if habit.id in completed_habit_ids)

    user_todos = [todo for todo in todos if todo.user_id == user_id and todo.status is not TodoStatus.CANCELED]
    day_todos = [todo for todo in user_todos if todo_action_date(todo, timezone) == target_date]
    todo_expected = len(day_todos)
    todo_completed = sum(1 for todo in day_todos if todo.status is TodoStatus.COMPLETED)

    completed_items = habit_completed + todo_completed
    expected_items = habit_expected + todo_expected
    completion_rate = completed_items / expected_items if expected_items else 0.0

    return DailySummary(
        date_local=target_date,
        completed_items=completed_items,
        expected_items=expected_items,
        completion_rate=completion_rate,
        habit_completed=habit_completed,
        habit_expected=habit_expected,
        todo_completed=todo_completed,
        todo_expected=todo_expected,
    )


def compute_daily_summaries(
    *,
    user_id: str,
    start_date: date,
    end_date: date,
    timezone: str,
    habits: list[Habit],
    todos: list[Todo],
    completion_logs: list[CompletionLog],
) -> list[DailySummary]:
    summaries: list[DailySummary] = []
    cursor = start_date
    while cursor <= end_date:
        summaries.append(
            compute_daily_summary(
                user_id=user_id,
                target_date=cursor,
                timezone=timezone,
                habits=habits,
                todos=todos,
                completion_logs=completion_logs,
            )
        )
        cursor += timedelta(days=1)
    return summaries


def summarize_period(
    *,
    period_type: PeriodType,
    anchor_date: date,
    daily_summaries: list[DailySummary],
    week_start: int = 0,
) -> PeriodSummary:
    start, end = period_bounds(anchor_date, period_type, week_start=week_start)
    in_period = [summary for summary in daily_summaries if start <= summary.date_local <= end]

    completed = sum(summary.completed_items for summary in in_period)
    expected = sum(summary.expected_items for summary in in_period)
    completion_rate = completed / expected if expected else 0.0
    active_days = sum(1 for summary in in_period if summary.completed_items > 0)
    commitment_days = [summary for summary in in_period if summary.expected_items > 0]
    reliable_days = [summary for summary in commitment_days if summary.completion_rate >= 0.8]
    consistency_score = len(reliable_days) / len(commitment_days) if commitment_days else 0.0

    return PeriodSummary(
        period_type=period_type,
        period_start=start,
        period_end=end,
        completed_items=completed,
        expected_items=expected,
        completion_rate=completion_rate,
        active_days=active_days,
        consistency_score=consistency_score,
    )


def compute_habit_streak(
    *,
    habit: Habit,
    completion_logs: list[CompletionLog],
    anchor_date: date,
) -> int:
    completed_dates = {
        log.date_local
        for log in completion_logs
        if log.item_id == habit.id and log.state is CompletionState.COMPLETED
    }

    streak = 0
    cursor = anchor_date
    while cursor >= habit.start_date:
        if habit.end_date is not None and cursor > habit.end_date:
            cursor -= timedelta(days=1)
            continue
        if not is_habit_scheduled(habit, cursor):
            cursor -= timedelta(days=1)
            continue
        if cursor in completed_dates:
            streak += 1
            cursor -= timedelta(days=1)
            continue
        break

    return streak


def compute_daily_action_streak(
    *,
    daily_summaries: list[DailySummary],
    anchor_date: date,
    minimum_completion_rate: float = 0.6,
) -> int:
    by_day = {summary.date_local: summary for summary in daily_summaries}

    streak = 0
    cursor = anchor_date
    while True:
        summary = by_day.get(cursor)
        if summary is None or summary.expected_items == 0:
            break
        if summary.completion_rate >= minimum_completion_rate:
            streak += 1
            cursor -= timedelta(days=1)
            continue
        break

    return streak


def build_contribution_heatmap(daily_summaries: list[DailySummary]) -> list[HeatmapCell]:
    cells: list[HeatmapCell] = []
    for summary in sorted(daily_summaries, key=lambda x: x.date_local):
        if summary.completed_items == 0:
            intensity = 0
        elif summary.completed_items == 1:
            intensity = 1
        elif summary.completed_items <= 3:
            intensity = 2
        elif summary.completed_items <= 6:
            intensity = 3
        else:
            intensity = 4

        cells.append(
            HeatmapCell(
                date_local=summary.date_local,
                intensity=intensity,
                completed_items=summary.completed_items,
                completion_rate=summary.completion_rate,
            )
        )

    return cells
