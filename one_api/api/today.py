from __future__ import annotations

from datetime import date

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from one_api.api.deps import UserContext, get_user_context
from one_api.db.session import get_db
from one_api.schemas import TodayItemResponse, TodayOrderWriteRequest, TodayResponse
from one_api.services.today_service import TodayService

router = APIRouter(prefix="/today", tags=["today"])


@router.get("", response_model=TodayResponse)
def get_today(
    date_local: date | None = Query(default=None, alias="date"),
    ctx: UserContext = Depends(get_user_context),
    db: Session = Depends(get_db),
):
    payload = TodayService(db).get_today(
        user_id=ctx.user_id,
        timezone=ctx.timezone,
        target_date=date_local,
    )
    db.commit()
    return _to_response(payload)

@router.put("/order", response_model=TodayResponse)
def put_today_order(
    payload: TodayOrderWriteRequest,
    ctx: UserContext = Depends(get_user_context),
    db: Session = Depends(get_db),
):
    today_payload = TodayService(db).set_today_order(
        user_id=ctx.user_id,
        timezone=ctx.timezone,
        target_date=payload.date_local,
        items=[(item.item_type, item.item_id, item.order_index) for item in payload.items],
    )
    db.commit()
    return _to_response(today_payload)


def _to_response(payload) -> TodayResponse:
    return TodayResponse(
        date_local=payload.date_local,
        items=[
            TodayItemResponse(
                item_type=item.item_type.value,
                item_id=item.item_id,
                title=item.title,
                category_id=item.category_id,
                completed=item.completed,
                sort_bucket=item.sort_bucket,
                sort_score=item.sort_score,
                subtitle=item.subtitle,
                is_pinned=item.is_pinned,
                priority=item.priority,
                due_at=item.due_at,
                preferred_time=item.preferred_time,
            )
            for item in payload.items
        ],
        completed_count=payload.completed_count,
        total_count=payload.total_count,
        completion_ratio=payload.completion_ratio,
    )
