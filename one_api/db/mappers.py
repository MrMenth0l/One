from __future__ import annotations

from one.models import (
    Category,
    CoachCard,
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
from one_api.db import models


def to_user(row: models.UserModel) -> User:
    return User(
        id=row.id,
        email=row.email,
        apple_sub=row.apple_sub,
        display_name=row.display_name,
        timezone=row.timezone,
        created_at=row.created_at,
    )


def to_category(row: models.CategoryModel) -> Category:
    return Category(
        id=row.id,
        user_id=row.user_id,
        name=row.name,
        icon=row.icon,
        color=row.color,
        sort_order=row.sort_order,
        is_default=row.is_default,
        archived_at=row.archived_at,
    )


def to_habit(row: models.HabitModel) -> Habit:
    return Habit(
        id=row.id,
        user_id=row.user_id,
        category_id=row.category_id,
        title=row.title,
        notes=row.notes,
        recurrence_rule=row.recurrence_rule,
        start_date=row.start_date,
        end_date=row.end_date,
        priority_weight=row.priority_weight,
        is_active=row.is_active,
        preferred_time=row.preferred_time,
    )


def to_todo(row: models.TodoModel) -> Todo:
    return Todo(
        id=row.id,
        user_id=row.user_id,
        category_id=row.category_id,
        title=row.title,
        notes=row.notes,
        due_at=row.due_at,
        priority=row.priority,
        is_pinned=row.is_pinned,
        status=TodoStatus(row.status),
        completed_at=row.completed_at,
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


def to_completion_log(row: models.CompletionLogModel) -> CompletionLog:
    return CompletionLog(
        id=row.id,
        user_id=row.user_id,
        item_type=ItemType(row.item_type),
        item_id=row.item_id,
        date_local=row.date_local,
        state=CompletionState(row.state),
        completed_at=row.completed_at,
        source=row.source,
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


def to_reflection_note(row: models.ReflectionNoteModel) -> ReflectionNote:
    return ReflectionNote(
        id=row.id,
        user_id=row.user_id,
        period_type=PeriodType(row.period_type),
        period_start=row.period_start,
        period_end=row.period_end,
        content=row.content,
        sentiment=ReflectionSentiment(row.sentiment),
        tags=list(row.tags or []),
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


def to_reminder(row: models.ReminderModel) -> Reminder:
    return Reminder(
        id=row.id,
        user_id=row.user_id,
        item_type=ItemType(row.item_type),
        item_id=row.item_id,
        trigger_local_time=row.trigger_local_time,
        timezone=row.timezone,
        repeat_pattern=row.repeat_pattern,
        is_enabled=row.is_enabled,
        last_sent_at=row.last_sent_at,
    )


def to_coach_card(row: models.CoachCardModel) -> CoachCard:
    return CoachCard(
        id=row.id,
        title=row.title,
        body=row.body,
        verse_ref=row.verse_ref,
        verse_text=row.verse_text,
        tags=list(row.tags or []),
        locale=row.locale,
        active_from=row.active_from,
        active_to=row.active_to,
        is_active=row.is_active,
    )


def to_preferences(row: models.UserPreferencesModel) -> UserPreferences:
    return UserPreferences(
        id=row.id,
        user_id=row.user_id,
        theme=Theme(row.theme),
        week_start=row.week_start,
        default_tab=row.default_tab,
        quiet_hours_start=row.quiet_hours_start,
        quiet_hours_end=row.quiet_hours_end,
        notification_flags=dict(row.notification_flags or {}),
        coach_enabled=row.coach_enabled,
    )
