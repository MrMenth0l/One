from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from one_api.api.deps import UserContext, get_user_context
from one_api.db.repositories import UserRepository
from one_api.db.session import get_db
from one_api.schemas import UserResponse, UserUpdateRequest
from one_api.services.user_service import UserService

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me", response_model=UserResponse)
def get_me(
    ctx: UserContext = Depends(get_user_context),
    db: Session = Depends(get_db),
):
    user = UserRepository(db).get(ctx.user_id)
    return UserResponse.model_validate(user)


@router.patch("/me", response_model=UserResponse)
def patch_me(
    payload: UserUpdateRequest,
    ctx: UserContext = Depends(get_user_context),
    db: Session = Depends(get_db),
):
    user = UserService(db).update_profile(
        user_id=ctx.user_id,
        display_name=payload.display_name,
        timezone=payload.timezone,
    )
    db.commit()
    return UserResponse.model_validate(user)
