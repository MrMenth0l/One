"""add today order overrides

Revision ID: 0002_today_order_overrides
Revises: 0001_initial
Create Date: 2026-03-12
"""
from __future__ import annotations

from alembic import op
import sqlalchemy as sa


revision = "0002_today_order_overrides"
down_revision = "0001_initial"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "today_order_overrides",
        sa.Column("id", sa.String(length=36), primary_key=True),
        sa.Column("user_id", sa.String(length=36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("date_local", sa.Date(), nullable=False),
        sa.Column("item_type", sa.String(length=32), nullable=False),
        sa.Column("item_id", sa.String(length=36), nullable=False),
        sa.Column("order_index", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("user_id", "date_local", "item_type", "item_id", name="uq_today_order_item_day"),
    )
    op.create_index("ix_today_order_overrides_user_id", "today_order_overrides", ["user_id"], unique=False)
    op.create_index("ix_today_order_overrides_date_local", "today_order_overrides", ["date_local"], unique=False)
    op.create_index("ix_today_order_overrides_item_type", "today_order_overrides", ["item_type"], unique=False)
    op.create_index("ix_today_order_overrides_item_id", "today_order_overrides", ["item_id"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_today_order_overrides_item_id", table_name="today_order_overrides")
    op.drop_index("ix_today_order_overrides_item_type", table_name="today_order_overrides")
    op.drop_index("ix_today_order_overrides_date_local", table_name="today_order_overrides")
    op.drop_index("ix_today_order_overrides_user_id", table_name="today_order_overrides")
    op.drop_table("today_order_overrides")
