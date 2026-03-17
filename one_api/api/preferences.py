from __future__ import annotations

from datetime import UTC, datetime

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from one_api.api.deps import UserContext, get_user_context
from one_api.db.repositories import PreferencesRepository
from one_api.db.session import get_db
from one_api.schemas import UserPreferencesResponse, UserPreferencesUpdateRequest

router = APIRouter(prefix="/preferences", tags=["preferences"])


@router.get("", response_model=UserPreferencesResponse)
def get_preferences(
    ctx: UserContext = Depends(get_user_context),
    db: Session = Depends(get_db),
):
    row = PreferencesRepository(db).get_or_create(ctx.user_id)
    db.commit()
    return UserPreferencesResponse.model_validate(row)


@router.patch("", response_model=UserPreferencesResponse)
def patch_preferences(
    payload: UserPreferencesUpdateRequest,
    ctx: UserContext = Depends(get_user_context),
    db: Session = Depends(get_db),
):
    repo = PreferencesRepository(db)
    row = repo.get_or_create(ctx.user_id)
    updates = payload.model_dump(exclude_unset=True)
    for key, value in updates.items():
        setattr(row, key, value)
    row.updated_at = datetime.now(UTC)
    db.commit()
    return UserPreferencesResponse.model_validate(row)
