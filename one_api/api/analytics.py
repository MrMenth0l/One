from __future__ import annotations

from datetime import date

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from one.models import PeriodType
from one_api.api.deps import UserContext, get_user_context
from one_api.db.session import get_db
from one_api.schemas import DailySummaryResponse, PeriodSummaryResponse
from one_api.services.analytics_service import AnalyticsService

router = APIRouter(prefix="/analytics", tags=["analytics"])


@router.get("/daily", response_model=list[DailySummaryResponse])
def get_daily(
    start_date: date = Query(...),
    end_date: date = Query(...),
    ctx: UserContext = Depends(get_user_context),
    db: Session = Depends(get_db),
):
    summaries = AnalyticsService(db).daily_range(
        user_id=ctx.user_id,
        timezone=ctx.timezone,
        start_date=start_date,
        end_date=end_date,
    )
    return [
        DailySummaryResponse.model_validate(
            {
                "date_local": summary.date_local,
                "completed_items": summary.completed_items,
                "expected_items": summary.expected_items,
                "completion_rate": summary.completion_rate,
                "habit_completed": summary.habit_completed,
                "habit_expected": summary.habit_expected,
                "todo_completed": summary.todo_completed,
                "todo_expected": summary.todo_expected,
            }
        )
        for summary in summaries
    ]


@router.get("/period", response_model=PeriodSummaryResponse)
def get_period(
    anchor_date: date = Query(...),
    period_type: str = Query(...),
    ctx: UserContext = Depends(get_user_context),
    db: Session = Depends(get_db),
):
    summary = AnalyticsService(db).period_summary(
        user_id=ctx.user_id,
        timezone=ctx.timezone,
        anchor_date=anchor_date,
        period_type=PeriodType(period_type),
    )
    return PeriodSummaryResponse.model_validate(
        {
            "period_type": summary.period_type.value,
            "period_start": summary.period_start,
            "period_end": summary.period_end,
            "completed_items": summary.completed_items,
            "expected_items": summary.expected_items,
            "completion_rate": summary.completion_rate,
            "active_days": summary.active_days,
            "consistency_score": summary.consistency_score,
        }
    )
