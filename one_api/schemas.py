from __future__ import annotations

from datetime import date, datetime, time

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class EmailSignupRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8)
    display_name: str
    timezone: str


class EmailLoginRequest(BaseModel):
    email: EmailStr
    password: str


class AppleLoginRequest(BaseModel):
    identity_token: str


class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    email: EmailStr
    apple_sub: str | None = None
    display_name: str
    timezone: str
    created_at: datetime


class AuthSessionResponse(BaseModel):
    access_token: str
    refresh_token: str
    expires_in: int
    user: UserResponse


class UserUpdateRequest(BaseModel):
    display_name: str | None = None
    timezone: str | None = None


class CategoryCreateRequest(BaseModel):
    name: str
    icon: str = "circle"
    color: str = "#5B8DEF"


class CategoryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    user_id: str
    name: str
    icon: str
    color: str
    sort_order: int
    is_default: bool
    archived_at: datetime | None = None


class HabitCreateRequest(BaseModel):
    category_id: str
    title: str
    notes: str = ""
    recurrence_rule: str
    start_date: date | None = None
    end_date: date | None = None
    priority_weight: int = 50
    preferred_time: time | None = None


class HabitUpdateRequest(BaseModel):
    category_id: str | None = None
    title: str | None = None
    notes: str | None = None
    recurrence_rule: str | None = None
    end_date: date | None = None
    priority_weight: int | None = None
    preferred_time: time | None = None
    is_active: bool | None = None


class HabitResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    user_id: str
    category_id: str
    title: str
    notes: str
    recurrence_rule: str
    start_date: date
    end_date: date | None
    priority_weight: int
    preferred_time: time | None
    is_active: bool


class TodoCreateRequest(BaseModel):
    category_id: str
    title: str
    notes: str = ""
    due_at: datetime | None = None
    priority: int = 50
    is_pinned: bool = False


class TodoUpdateRequest(BaseModel):
    category_id: str | None = None
    title: str | None = None
    notes: str | None = None
    due_at: datetime | None = None
    priority: int | None = None
    is_pinned: bool | None = None
    status: str | None = None


class TodoResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    user_id: str
    category_id: str
    title: str
    notes: str
    due_at: datetime | None
    priority: int
    is_pinned: bool
    status: str
    completed_at: datetime | None
    created_at: datetime
    updated_at: datetime


class CompletionWriteRequest(BaseModel):
    item_type: str
    item_id: str
    date_local: date
    state: str
    source: str = "app"


class CompletionLogResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    user_id: str
    item_type: str
    item_id: str
    date_local: date
    state: str
    completed_at: datetime | None
    source: str
    created_at: datetime
    updated_at: datetime


class ReflectionWriteRequest(BaseModel):
    period_type: str
    period_start: date
    period_end: date
    content: str
    sentiment: str = "okay"
    tags: list[str] = Field(default_factory=list)


class ReflectionNoteResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    user_id: str
    period_type: str
    period_start: date
    period_end: date
    content: str
    sentiment: str
    tags: list[str]
    created_at: datetime
    updated_at: datetime


class CoachCardResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    title: str
    body: str
    verse_ref: str | None
    verse_text: str | None
    tags: list[str]
    locale: str
    active_from: date | None
    active_to: date | None
    is_active: bool


class UserPreferencesResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    user_id: str
    theme: str
    week_start: int
    default_tab: str
    quiet_hours_start: time | None
    quiet_hours_end: time | None
    notification_flags: dict[str, bool]
    coach_enabled: bool


class UserPreferencesUpdateRequest(BaseModel):
    theme: str | None = None
    week_start: int | None = None
    default_tab: str | None = None
    quiet_hours_start: time | None = None
    quiet_hours_end: time | None = None
    notification_flags: dict[str, bool] | None = None
    coach_enabled: bool | None = None


class DailySummaryResponse(BaseModel):
    date_local: date
    completed_items: int
    expected_items: int
    completion_rate: float
    habit_completed: int
    habit_expected: int
    todo_completed: int
    todo_expected: int


class PeriodSummaryResponse(BaseModel):
    period_type: str
    period_start: date
    period_end: date
    completed_items: int
    expected_items: int
    completion_rate: float
    active_days: int
    consistency_score: float


class TodayItemResponse(BaseModel):
    item_type: str
    item_id: str
    title: str
    category_id: str
    completed: bool
    sort_bucket: int
    sort_score: float
    subtitle: str | None = None
    is_pinned: bool | None = None
    priority: int | None = None
    due_at: datetime | None = None
    preferred_time: time | None = None


class TodayResponse(BaseModel):
    date_local: date
    items: list[TodayItemResponse]
    completed_count: int
    total_count: int
    completion_ratio: float


class TodayOrderItemRequest(BaseModel):
    item_type: str
    item_id: str
    order_index: int


class TodayOrderWriteRequest(BaseModel):
    date_local: date
    items: list[TodayOrderItemRequest]


class HabitStatsResponse(BaseModel):
    habit_id: str
    anchor_date: date
    window_days: int
    streak_current: int
    completed_window: int
    expected_window: int
    completion_rate_window: float
    last_completed_date: date | None
