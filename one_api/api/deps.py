from __future__ import annotations

from fastapi import Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from one_api.auth.dependencies import get_current_identity
from one_api.auth.provider import AuthIdentity
from one_api.db.repositories import PreferencesRepository, UserRepository
from one_api.db.session import get_db


class UserContext:
    def __init__(self, user_id: str, email: str, timezone: str):
        self.user_id = user_id
        self.email = email
        self.timezone = timezone


def get_user_context(
    request: Request,
    identity: AuthIdentity = Depends(get_current_identity),
    db: Session = Depends(get_db),
) -> UserContext:
    user = UserRepository(db).get(identity.user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not provisioned")
    request.state.user_id = user.id
    return UserContext(user_id=user.id, email=user.email, timezone=user.timezone)
