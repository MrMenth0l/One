from __future__ import annotations

from datetime import UTC, datetime

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from one_api.api.deps import UserContext, get_user_context
from one_api.db import mappers
from one_api.db.repositories import CoachCardRepository
from one_api.db.session import get_db
from one_api.schemas import CoachCardResponse

router = APIRouter(prefix="/coach-cards", tags=["coach-cards"])


@router.get("", response_model=list[CoachCardResponse])
def list_coach_cards(
    ctx: UserContext = Depends(get_user_context),
    db: Session = Depends(get_db),
):
    rows = CoachCardRepository(db).list_active(datetime.now(UTC).date())
    return [CoachCardResponse.model_validate(mappers.to_coach_card(row)) for row in rows]
