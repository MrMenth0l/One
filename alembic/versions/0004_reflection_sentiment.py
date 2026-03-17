"""add reflection sentiment

Revision ID: 0004_reflection_sentiment
Revises: 0003_coach_card_verse_text
Create Date: 2026-03-13
"""
from __future__ import annotations

from alembic import op
import sqlalchemy as sa


revision = "0004_reflection_sentiment"
down_revision = "0003_coach_card_verse_text"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "reflection_notes",
        sa.Column("sentiment", sa.String(length=32), nullable=False, server_default="okay"),
    )


def downgrade() -> None:
    op.drop_column("reflection_notes", "sentiment")
