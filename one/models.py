from __future__ import annotations

from dataclasses import dataclass, field
from datetime import UTC, date, datetime, time
from enum import Enum


class ItemType(str, Enum):
    HABIT = "habit"
    TODO = "todo"
    REFLECTION = "reflection"


class CompletionState(str, Enum):
    COMPLETED = "completed"
    NOT_COMPLETED = "not_completed"


class TodoStatus(str, Enum):
    OPEN = "open"
    COMPLETED = "completed"
    CANCELED = "canceled"


class PeriodType(str, Enum):
    DAILY = "daily"
    WEEKLY = "weekly"
    MONTHLY = "monthly"
    YEARLY = "yearly"


class ReflectionSentiment(str, Enum):
    GREAT = "great"
    FOCUSED = "focused"
    OKAY = "okay"
    TIRED = "tired"
    STRESSED = "stressed"


class Theme(str, Enum):
    LIGHT = "light"
    DARK = "dark"
    SYSTEM = "system"


DEFAULT_CATEGORY_NAMES = [
    "Gym",
    "School",
    "Personal Projects",
    "Wellbeing",
    "Life Admin",
]

DEFAULT_CATEGORY_ICONS = {
    "Gym": "category.gym",
    "School": "category.school",
    "Personal Projects": "category.projects",
    "Wellbeing": "category.wellbeing",
    "Life Admin": "category.life-admin",
}


@dataclass(slots=True)
class User:
    id: str
    email: str
    apple_sub: str | None = None
    display_name: str = ""
    timezone: str = "UTC"
    created_at: datetime = field(default_factory=lambda: datetime.now(UTC))


@dataclass(slots=True)
class Category:
    id: str
    user_id: str
    name: str
    icon: str = "category.generic"
    color: str = "#5B8DEF"
    sort_order: int = 0
    is_default: bool = False
    archived_at: datetime | None = None


@dataclass(slots=True)
class Habit:
    id: str
    user_id: str
    category_id: str
    title: str
    notes: str = ""
    recurrence_rule: str = "DAILY"
    start_date: date = field(default_factory=date.today)
    end_date: date | None = None
    priority_weight: int = 50
    is_active: bool = True
    preferred_time: time | None = None


@dataclass(slots=True)
class Todo:
    id: str
    user_id: str
    category_id: str
    title: str
    notes: str = ""
    due_at: datetime | None = None
    priority: int = 50
    is_pinned: bool = False
    status: TodoStatus = TodoStatus.OPEN
    completed_at: datetime | None = None
    created_at: datetime = field(default_factory=lambda: datetime.now(UTC))
    updated_at: datetime = field(default_factory=lambda: datetime.now(UTC))


@dataclass(slots=True)
class CompletionLog:
    id: str
    user_id: str
    item_type: ItemType
    item_id: str
    date_local: date
    state: CompletionState = CompletionState.NOT_COMPLETED
    completed_at: datetime | None = None
    source: str = "app"
    created_at: datetime = field(default_factory=lambda: datetime.now(UTC))
    updated_at: datetime = field(default_factory=lambda: datetime.now(UTC))


@dataclass(slots=True)
class ReflectionNote:
    id: str
    user_id: str
    period_type: PeriodType
    period_start: date
    period_end: date
    content: str
    sentiment: ReflectionSentiment = ReflectionSentiment.OKAY
    created_at: datetime = field(default_factory=lambda: datetime.now(UTC))
    updated_at: datetime = field(default_factory=lambda: datetime.now(UTC))
    tags: list[str] = field(default_factory=list)


@dataclass(slots=True)
class Reminder:
    id: str
    user_id: str
    item_type: ItemType
    item_id: str
    trigger_local_time: time
    timezone: str
    repeat_pattern: str
    is_enabled: bool = True
    last_sent_at: datetime | None = None


@dataclass(slots=True)
class CoachCard:
    id: str
    title: str
    body: str
    verse_ref: str | None = None
    verse_text: str | None = None
    tags: list[str] = field(default_factory=list)
    locale: str = "en"
    active_from: date | None = None
    active_to: date | None = None
    is_active: bool = True


@dataclass(slots=True)
class UserPreferences:
    id: str
    user_id: str
    theme: Theme = Theme.SYSTEM
    week_start: int = 0
    default_tab: str = "today"
    quiet_hours_start: time | None = None
    quiet_hours_end: time | None = None
    notification_flags: dict[str, bool] = field(
        default_factory=lambda: {
            "habit_reminders": True,
            "todo_reminders": True,
            "reflection_prompts": True,
            "weekly_summary": True,
        }
    )
    coach_enabled: bool = True
