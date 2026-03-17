"""add coach card verse text

Revision ID: 0003_coach_card_verse_text
Revises: 0002_today_order_overrides
Create Date: 2026-03-12
"""
from __future__ import annotations

from alembic import op
import sqlalchemy as sa


revision = "0003_coach_card_verse_text"
down_revision = "0002_today_order_overrides"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("coach_cards", sa.Column("verse_text", sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column("coach_cards", "verse_text")
