from __future__ import annotations

from datetime import UTC, date, datetime
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from one_api.api.deps import UserContext, get_user_context
from one_api.db import models
from one_api.db.repositories import HabitRepository
from one_api.db.session import get_db
from one_api.schemas import HabitCreateRequest, HabitResponse, HabitStatsResponse, HabitUpdateRequest
from one_api.services.analytics_service import AnalyticsService

router = APIRouter(prefix="/habits", tags=["habits"])


@router.get("", response_model=list[HabitResponse])
def list_habits(
    ctx: UserContext = Depends(get_user_context),
    db: Session = Depends(get_db),
):
    rows = HabitRepository(db).list_for_user(ctx.user_id)
    return [HabitResponse.model_validate(row) for row in rows]


@router.post("", response_model=HabitResponse, status_code=status.HTTP_201_CREATED)
def create_habit(
    payload: HabitCreateRequest,
    ctx: UserContext = Depends(get_user_context),
    db: Session = Depends(get_db),
):
    now = datetime.now(UTC)
    row = models.HabitModel(
        id=str(uuid4()),
        user_id=ctx.user_id,
        category_id=payload.category_id,
        title=payload.title,
        notes=payload.notes,
        recurrence_rule=payload.recurrence_rule,
        start_date=payload.start_date or date.today(),
        end_date=payload.end_date,
        priority_weight=payload.priority_weight,
        preferred_time=payload.preferred_time,
        is_active=True,
        created_at=now,
        updated_at=now,
    )
    HabitRepository(db).create(row)
    db.commit()
    return HabitResponse.model_validate(row)


@router.patch("/{habit_id}", response_model=HabitResponse)
def patch_habit(
    habit_id: str,
    payload: HabitUpdateRequest,
    ctx: UserContext = Depends(get_user_context),
    db: Session = Depends(get_db),
):
    repo = HabitRepository(db)
    row = repo.get(ctx.user_id, habit_id)
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Habit not found")

    updates = payload.model_dump(exclude_unset=True)
    for key, value in updates.items():
        setattr(row, key, value)
    row.updated_at = datetime.now(UTC)

    db.commit()
    return HabitResponse.model_validate(row)


@router.delete("/{habit_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_habit(
    habit_id: str,
    ctx: UserContext = Depends(get_user_context),
    db: Session = Depends(get_db),
):
    deleted = HabitRepository(db).delete(ctx.user_id, habit_id)
    if not deleted:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Habit not found")
    db.commit()


@router.get("/{habit_id}/stats", response_model=HabitStatsResponse)
def get_habit_stats(
    habit_id: str,
    anchor_date: date | None = Query(default=None),
    window_days: int = Query(default=30, ge=1, le=365),
    ctx: UserContext = Depends(get_user_context),
    db: Session = Depends(get_db),
):
    target = anchor_date or datetime.now(UTC).date()
    service = AnalyticsService(db)
    try:
        payload = service.habit_stats(
            user_id=ctx.user_id,
            habit_id=habit_id,
            anchor_date=target,
            window_days=window_days,
        )
    except KeyError:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Habit not found") from None
    return HabitStatsResponse.model_validate(payload)
