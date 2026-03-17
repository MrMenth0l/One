from __future__ import annotations

from datetime import UTC, date, datetime, time
from uuid import uuid4

from sqlalchemy import JSON, Boolean, Date, DateTime, ForeignKey, Integer, String, Text, Time, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from one_api.db.base import Base


def _uuid() -> str:
    return str(uuid4())


def _utcnow() -> datetime:
    return datetime.now(UTC)


class UserModel(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    email: Mapped[str] = mapped_column(String(320), unique=True, index=True)
    apple_sub: Mapped[str | None] = mapped_column(String(255), nullable=True)
    display_name: Mapped[str] = mapped_column(String(255), default="")
    timezone: Mapped[str] = mapped_column(String(64), default="UTC")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow, onupdate=_utcnow)


class CategoryModel(Base):
    __tablename__ = "categories"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), index=True)
    name: Mapped[str] = mapped_column(String(100))
    icon: Mapped[str] = mapped_column(String(64), default="circle")
    color: Mapped[str] = mapped_column(String(32), default="#5B8DEF")
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    is_default: Mapped[bool] = mapped_column(Boolean, default=False)
    archived_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow, onupdate=_utcnow)


class HabitModel(Base):
    __tablename__ = "habits"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), index=True)
    category_id: Mapped[str] = mapped_column(String(36), ForeignKey("categories.id", ondelete="CASCADE"), index=True)
    title: Mapped[str] = mapped_column(String(255))
    notes: Mapped[str] = mapped_column(Text, default="")
    recurrence_rule: Mapped[str] = mapped_column(String(255), default="DAILY")
    start_date: Mapped[date] = mapped_column(Date)
    end_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    priority_weight: Mapped[int] = mapped_column(Integer, default=50)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    preferred_time: Mapped[time | None] = mapped_column(Time, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow, onupdate=_utcnow)


class TodoModel(Base):
    __tablename__ = "todos"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), index=True)
    category_id: Mapped[str] = mapped_column(String(36), ForeignKey("categories.id", ondelete="CASCADE"), index=True)
    title: Mapped[str] = mapped_column(String(255))
    notes: Mapped[str] = mapped_column(Text, default="")
    due_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    priority: Mapped[int] = mapped_column(Integer, default=50)
    is_pinned: Mapped[bool] = mapped_column(Boolean, default=False)
    status: Mapped[str] = mapped_column(String(32), default="open")
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow, onupdate=_utcnow)


class CompletionLogModel(Base):
    __tablename__ = "completion_logs"
    __table_args__ = (
        UniqueConstraint("user_id", "item_type", "item_id", "date_local", name="uq_completion_log_item_day"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), index=True)
    item_type: Mapped[str] = mapped_column(String(32), index=True)
    item_id: Mapped[str] = mapped_column(String(36), index=True)
    date_local: Mapped[date] = mapped_column(Date, index=True)
    state: Mapped[str] = mapped_column(String(32), default="not_completed")
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    source: Mapped[str] = mapped_column(String(64), default="app")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow, onupdate=_utcnow)


class TodayOrderOverrideModel(Base):
    __tablename__ = "today_order_overrides"
    __table_args__ = (
        UniqueConstraint("user_id", "date_local", "item_type", "item_id", name="uq_today_order_item_day"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), index=True)
    date_local: Mapped[date] = mapped_column(Date, index=True)
    item_type: Mapped[str] = mapped_column(String(32), index=True)
    item_id: Mapped[str] = mapped_column(String(36), index=True)
    order_index: Mapped[int] = mapped_column(Integer, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow, onupdate=_utcnow)


class ReflectionNoteModel(Base):
    __tablename__ = "reflection_notes"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), index=True)
    period_type: Mapped[str] = mapped_column(String(32), index=True)
    period_start: Mapped[date] = mapped_column(Date)
    period_end: Mapped[date] = mapped_column(Date)
    content: Mapped[str] = mapped_column(Text)
    sentiment: Mapped[str] = mapped_column(String(32), default="okay")
    tags: Mapped[list[str]] = mapped_column(JSON, default=list)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow, onupdate=_utcnow)


class ReminderModel(Base):
    __tablename__ = "reminders"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), index=True)
    item_type: Mapped[str] = mapped_column(String(32))
    item_id: Mapped[str] = mapped_column(String(36))
    trigger_local_time: Mapped[time] = mapped_column(Time)
    timezone: Mapped[str] = mapped_column(String(64))
    repeat_pattern: Mapped[str] = mapped_column(String(64))
    is_enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    last_sent_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow, onupdate=_utcnow)


class CoachCardModel(Base):
    __tablename__ = "coach_cards"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    title: Mapped[str] = mapped_column(String(255))
    body: Mapped[str] = mapped_column(Text)
    verse_ref: Mapped[str | None] = mapped_column(String(128), nullable=True)
    verse_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    tags: Mapped[list[str]] = mapped_column(JSON, default=list)
    locale: Mapped[str] = mapped_column(String(16), default="en")
    active_from: Mapped[date | None] = mapped_column(Date, nullable=True)
    active_to: Mapped[date | None] = mapped_column(Date, nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow, onupdate=_utcnow)


class UserPreferencesModel(Base):
    __tablename__ = "user_preferences"
    __table_args__ = (
        UniqueConstraint("user_id", name="uq_user_preferences_user"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(String(36), ForeignKey("users.id", ondelete="CASCADE"), index=True)
    theme: Mapped[str] = mapped_column(String(16), default="system")
    week_start: Mapped[int] = mapped_column(Integer, default=0)
    default_tab: Mapped[str] = mapped_column(String(32), default="today")
    quiet_hours_start: Mapped[time | None] = mapped_column(Time, nullable=True)
    quiet_hours_end: Mapped[time | None] = mapped_column(Time, nullable=True)
    notification_flags: Mapped[dict[str, bool]] = mapped_column(JSON, default=dict)
    coach_enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow, onupdate=_utcnow)
