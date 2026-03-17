from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from one.models import CompletionState, ItemType
from one_api.api.deps import UserContext, get_user_context
from one_api.db.session import get_db
from one_api.schemas import CompletionLogResponse, CompletionWriteRequest
from one_api.services.task_service import TaskService

router = APIRouter(prefix="/completions", tags=["completions"])


@router.post("", response_model=CompletionLogResponse)
def write_completion(
    payload: CompletionWriteRequest,
    ctx: UserContext = Depends(get_user_context),
    db: Session = Depends(get_db),
):
    try:
        item_type = ItemType(payload.item_type)
        state = CompletionState(payload.state)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Invalid item_type/state") from exc

    try:
        row = TaskService(db).write_completion(
            user_id=ctx.user_id,
            item_type=item_type,
            item_id=payload.item_id,
            date_local=payload.date_local,
            state=state,
            source=payload.source,
        )
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc

    db.commit()
    return CompletionLogResponse.model_validate(row)
