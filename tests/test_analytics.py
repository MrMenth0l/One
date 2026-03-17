from datetime import date, datetime
import unittest

from one.analytics import (
    DailySummary,
    build_contribution_heatmap,
    compute_daily_action_streak,
    compute_daily_summaries,
    compute_habit_streak,
    summarize_period,
)
from one.models import CompletionLog, CompletionState, Habit, ItemType, PeriodType, Todo, TodoStatus


class AnalyticsTests(unittest.TestCase):
    def test_calendar_rollups_and_primary_metrics(self) -> None:
        start = date(2026, 3, 9)
        end = date(2026, 3, 15)

        habit = Habit(
            id="h1",
            user_id="u1",
            category_id="c-gym",
            title="Workout",
            recurrence_rule="DAILY",
            start_date=date(2026, 1, 1),
        )
        todo = Todo(
            id="t1",
            user_id="u1",
            category_id="c-school",
            title="Assignment",
            created_at=datetime(2026, 3, 11, 12, 0),
            status=TodoStatus.COMPLETED,
            completed_at=datetime(2026, 3, 11, 14, 0),
        )

        logs = [
            CompletionLog(
                id="l1",
                user_id="u1",
                item_type=ItemType.HABIT,
                item_id="h1",
                date_local=date(2026, 3, 9),
                state=CompletionState.COMPLETED,
            ),
            CompletionLog(
                id="l2",
                user_id="u1",
                item_type=ItemType.HABIT,
                item_id="h1",
                date_local=date(2026, 3, 10),
                state=CompletionState.COMPLETED,
            ),
            CompletionLog(
                id="l3",
                user_id="u1",
                item_type=ItemType.HABIT,
                item_id="h1",
                date_local=date(2026, 3, 11),
                state=CompletionState.NOT_COMPLETED,
            ),
        ]

        daily = compute_daily_summaries(
            user_id="u1",
            start_date=start,
            end_date=end,
            timezone="America/Guatemala",
            habits=[habit],
            todos=[todo],
            completion_logs=logs,
        )

        weekly = summarize_period(
            period_type=PeriodType.WEEKLY,
            anchor_date=date(2026, 3, 11),
            daily_summaries=daily,
            week_start=0,
        )

        self.assertEqual(weekly.period_start, date(2026, 3, 9))
        self.assertEqual(weekly.period_end, date(2026, 3, 15))
        self.assertEqual(weekly.completed_items, 3)
        self.assertEqual(weekly.expected_items, 8)
        self.assertAlmostEqual(weekly.completion_rate, 3 / 8)

    def test_streak_computation(self) -> None:
        habit = Habit(
            id="h1",
            user_id="u1",
            category_id="c-gym",
            title="Workout",
            recurrence_rule="DAILY",
            start_date=date(2026, 1, 1),
        )

        logs = [
            CompletionLog(
                id="l1",
                user_id="u1",
                item_type=ItemType.HABIT,
                item_id="h1",
                date_local=date(2026, 3, 9),
                state=CompletionState.COMPLETED,
            ),
            CompletionLog(
                id="l2",
                user_id="u1",
                item_type=ItemType.HABIT,
                item_id="h1",
                date_local=date(2026, 3, 10),
                state=CompletionState.COMPLETED,
            ),
            CompletionLog(
                id="l3",
                user_id="u1",
                item_type=ItemType.HABIT,
                item_id="h1",
                date_local=date(2026, 3, 11),
                state=CompletionState.COMPLETED,
            ),
        ]

        daily = [
            DailySummary(date_local=date(2026, 3, 9), completed_items=1, expected_items=1, completion_rate=1.0, habit_completed=1, habit_expected=1, todo_completed=0, todo_expected=0),
            DailySummary(date_local=date(2026, 3, 10), completed_items=1, expected_items=1, completion_rate=1.0, habit_completed=1, habit_expected=1, todo_completed=0, todo_expected=0),
            DailySummary(date_local=date(2026, 3, 11), completed_items=1, expected_items=1, completion_rate=0.8, habit_completed=1, habit_expected=1, todo_completed=0, todo_expected=0),
        ]

        habit_streak = compute_habit_streak(
            habit=habit,
            completion_logs=logs,
            anchor_date=date(2026, 3, 11),
        )
        daily_streak = compute_daily_action_streak(
            daily_summaries=daily,
            anchor_date=date(2026, 3, 11),
            minimum_completion_rate=0.6,
        )

        self.assertEqual(habit_streak, 3)
        self.assertEqual(daily_streak, 3)

    def test_heatmap_intensity(self) -> None:
        daily = [
            DailySummary(date_local=date(2026, 3, 9), completed_items=0, expected_items=1, completion_rate=0.0, habit_completed=0, habit_expected=1, todo_completed=0, todo_expected=0),
            DailySummary(date_local=date(2026, 3, 10), completed_items=2, expected_items=2, completion_rate=1.0, habit_completed=1, habit_expected=1, todo_completed=1, todo_expected=1),
            DailySummary(date_local=date(2026, 3, 11), completed_items=7, expected_items=7, completion_rate=1.0, habit_completed=5, habit_expected=5, todo_completed=2, todo_expected=2),
        ]

        cells = build_contribution_heatmap(daily)
        self.assertEqual([c.intensity for c in cells], [0, 2, 4])


if __name__ == "__main__":
    unittest.main()
