from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy.orm import Session

from one_api.api.deps import UserContext, get_user_context
from one_api.db.repositories import ReflectionRepository
from one_api.db.session import get_db
from one_api.schemas import ReflectionNoteResponse, ReflectionWriteRequest

router = APIRouter(prefix="/reflections", tags=["reflections"])


@router.get("", response_model=list[ReflectionNoteResponse])
def list_reflections(
    period_type: str | None = Query(default=None),
    ctx: UserContext = Depends(get_user_context),
    db: Session = Depends(get_db),
):
    rows = ReflectionRepository(db).list_for_user(ctx.user_id, period_type=period_type)
    return [ReflectionNoteResponse.model_validate(row) for row in rows]


@router.post("", response_model=ReflectionNoteResponse, status_code=status.HTTP_201_CREATED)
def create_reflection(
    payload: ReflectionWriteRequest,
    ctx: UserContext = Depends(get_user_context),
    db: Session = Depends(get_db),
):
    row = ReflectionRepository(db).create(
        user_id=ctx.user_id,
        period_type=payload.period_type,
        period_start=payload.period_start,
        period_end=payload.period_end,
        content=payload.content,
        sentiment=payload.sentiment,
        tags=payload.tags,
    )
    db.commit()
    return ReflectionNoteResponse.model_validate(row)


@router.delete("/{reflection_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_reflection(
    reflection_id: str,
    ctx: UserContext = Depends(get_user_context),
    db: Session = Depends(get_db),
):
    deleted = ReflectionRepository(db).delete(ctx.user_id, reflection_id)
    if not deleted:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Reflection not found")
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
