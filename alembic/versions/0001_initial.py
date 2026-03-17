"""initial schema

Revision ID: 0001_initial
Revises: 
Create Date: 2026-03-12
"""
from __future__ import annotations

from alembic import op
import sqlalchemy as sa


revision = "0001_initial"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("email", sa.String(length=320), nullable=False),
        sa.Column("apple_sub", sa.String(length=255), nullable=True),
        sa.Column("display_name", sa.String(length=255), nullable=False),
        sa.Column("timezone", sa.String(length=64), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_users_email", "users", ["email"], unique=True)

    op.create_table(
        "categories",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("user_id", sa.String(length=36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("name", sa.String(length=100), nullable=False),
        sa.Column("icon", sa.String(length=64), nullable=False),
        sa.Column("color", sa.String(length=32), nullable=False),
        sa.Column("sort_order", sa.Integer(), nullable=False),
        sa.Column("is_default", sa.Boolean(), nullable=False),
        sa.Column("archived_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_categories_user_id", "categories", ["user_id"], unique=False)

    op.create_table(
        "habits",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("user_id", sa.String(length=36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("category_id", sa.String(length=36), sa.ForeignKey("categories.id", ondelete="CASCADE"), nullable=False),
        sa.Column("title", sa.String(length=255), nullable=False),
        sa.Column("notes", sa.Text(), nullable=False),
        sa.Column("recurrence_rule", sa.String(length=255), nullable=False),
        sa.Column("start_date", sa.Date(), nullable=False),
        sa.Column("end_date", sa.Date(), nullable=True),
        sa.Column("priority_weight", sa.Integer(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        sa.Column("preferred_time", sa.Time(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_habits_user_id", "habits", ["user_id"], unique=False)
    op.create_index("ix_habits_category_id", "habits", ["category_id"], unique=False)

    op.create_table(
        "todos",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("user_id", sa.String(length=36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("category_id", sa.String(length=36), sa.ForeignKey("categories.id", ondelete="CASCADE"), nullable=False),
        sa.Column("title", sa.String(length=255), nullable=False),
        sa.Column("notes", sa.Text(), nullable=False),
        sa.Column("due_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("priority", sa.Integer(), nullable=False),
        sa.Column("is_pinned", sa.Boolean(), nullable=False),
        sa.Column("status", sa.String(length=32), nullable=False),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_todos_user_id", "todos", ["user_id"], unique=False)
    op.create_index("ix_todos_category_id", "todos", ["category_id"], unique=False)

    op.create_table(
        "completion_logs",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("user_id", sa.String(length=36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("item_type", sa.String(length=32), nullable=False),
        sa.Column("item_id", sa.String(length=36), nullable=False),
        sa.Column("date_local", sa.Date(), nullable=False),
        sa.Column("state", sa.String(length=32), nullable=False),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("source", sa.String(length=64), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("user_id", "item_type", "item_id", "date_local", name="uq_completion_log_item_day"),
    )
    op.create_index("ix_completion_logs_user_id", "completion_logs", ["user_id"], unique=False)
    op.create_index("ix_completion_logs_item_type", "completion_logs", ["item_type"], unique=False)
    op.create_index("ix_completion_logs_item_id", "completion_logs", ["item_id"], unique=False)
    op.create_index("ix_completion_logs_date_local", "completion_logs", ["date_local"], unique=False)

    op.create_table(
        "reflection_notes",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("user_id", sa.String(length=36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("period_type", sa.String(length=32), nullable=False),
        sa.Column("period_start", sa.Date(), nullable=False),
        sa.Column("period_end", sa.Date(), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("tags", sa.JSON(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_reflection_notes_user_id", "reflection_notes", ["user_id"], unique=False)
    op.create_index("ix_reflection_notes_period_type", "reflection_notes", ["period_type"], unique=False)

    op.create_table(
        "reminders",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("user_id", sa.String(length=36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("item_type", sa.String(length=32), nullable=False),
        sa.Column("item_id", sa.String(length=36), nullable=False),
        sa.Column("trigger_local_time", sa.Time(), nullable=False),
        sa.Column("timezone", sa.String(length=64), nullable=False),
        sa.Column("repeat_pattern", sa.String(length=64), nullable=False),
        sa.Column("is_enabled", sa.Boolean(), nullable=False),
        sa.Column("last_sent_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_reminders_user_id", "reminders", ["user_id"], unique=False)

    op.create_table(
        "coach_cards",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("title", sa.String(length=255), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("verse_ref", sa.String(length=128), nullable=True),
        sa.Column("tags", sa.JSON(), nullable=False),
        sa.Column("locale", sa.String(length=16), nullable=False),
        sa.Column("active_from", sa.Date(), nullable=True),
        sa.Column("active_to", sa.Date(), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )

    op.create_table(
        "user_preferences",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("user_id", sa.String(length=36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("theme", sa.String(length=16), nullable=False),
        sa.Column("week_start", sa.Integer(), nullable=False),
        sa.Column("default_tab", sa.String(length=32), nullable=False),
        sa.Column("quiet_hours_start", sa.Time(), nullable=True),
        sa.Column("quiet_hours_end", sa.Time(), nullable=True),
        sa.Column("notification_flags", sa.JSON(), nullable=False),
        sa.Column("coach_enabled", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("user_id", name="uq_user_preferences_user"),
    )
    op.create_index("ix_user_preferences_user_id", "user_preferences", ["user_id"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_user_preferences_user_id", table_name="user_preferences")
    op.drop_table("user_preferences")
    op.drop_table("coach_cards")
    op.drop_index("ix_reminders_user_id", table_name="reminders")
    op.drop_table("reminders")
    op.drop_index("ix_reflection_notes_period_type", table_name="reflection_notes")
    op.drop_index("ix_reflection_notes_user_id", table_name="reflection_notes")
    op.drop_table("reflection_notes")
    op.drop_index("ix_completion_logs_date_local", table_name="completion_logs")
    op.drop_index("ix_completion_logs_item_id", table_name="completion_logs")
    op.drop_index("ix_completion_logs_item_type", table_name="completion_logs")
    op.drop_index("ix_completion_logs_user_id", table_name="completion_logs")
    op.drop_table("completion_logs")
    op.drop_index("ix_todos_category_id", table_name="todos")
    op.drop_index("ix_todos_user_id", table_name="todos")
    op.drop_table("todos")
    op.drop_index("ix_habits_category_id", table_name="habits")
    op.drop_index("ix_habits_user_id", table_name="habits")
    op.drop_table("habits")
    op.drop_index("ix_categories_user_id", table_name="categories")
    op.drop_table("categories")
    op.drop_index("ix_users_email", table_name="users")
    op.drop_table("users")
