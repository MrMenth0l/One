"""Core domain package for One."""

from .models import (
    CoachCard,
    Category,
    CompletionLog,
    CompletionState,
    Habit,
    ItemType,
    PeriodType,
    ReflectionNote,
    ReflectionSentiment,
    Reminder,
    Theme,
    Todo,
    TodoStatus,
    User,
    UserPreferences,
)
from .analytics import DailySummary, HeatmapCell, PeriodSummary
from .bootstrap import OnboardingBundle, create_onboarding_bundle
from .coaching import select_active_coach_cards
from .notifications import DueReminder, due_reminders, group_close_reminders
from .reflections import delete_reflection, list_reflections, reflection_prompt, search_reflections, upsert_reflection
from .tracking import TodayItem, build_today_items, is_habit_scheduled, materialize_habit_logs, set_habit_completion, set_todo_completion, todo_action_date, today_completion_ratio

__all__ = [
    "CoachCard",
    "Category",
    "CompletionLog",
    "CompletionState",
    "Habit",
    "ItemType",
    "PeriodType",
    "ReflectionNote",
    "ReflectionSentiment",
    "Reminder",
    "Theme",
    "Todo",
    "TodoStatus",
    "User",
    "UserPreferences",
    "DailySummary",
    "HeatmapCell",
    "PeriodSummary",
    "OnboardingBundle",
    "create_onboarding_bundle",
    "select_active_coach_cards",
    "DueReminder",
    "due_reminders",
    "group_close_reminders",
    "list_reflections",
    "delete_reflection",
    "reflection_prompt",
    "search_reflections",
    "upsert_reflection",
    "TodayItem",
    "build_today_items",
    "is_habit_scheduled",
    "materialize_habit_logs",
    "set_habit_completion",
    "set_todo_completion",
    "todo_action_date",
    "today_completion_ratio",
]
