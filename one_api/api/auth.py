from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from one_api.auth.dependencies import get_auth_provider
from one_api.auth.provider import AuthError, AuthProvider
from one_api.db.session import get_db
from one_api.schemas import AppleLoginRequest, AuthSessionResponse, EmailLoginRequest, EmailSignupRequest, UserResponse
from one_api.services.user_service import UserService

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/signup", response_model=AuthSessionResponse, status_code=status.HTTP_201_CREATED)
def signup(
    payload: EmailSignupRequest,
    db: Session = Depends(get_db),
    provider: AuthProvider = Depends(get_auth_provider),
):
    try:
        session = provider.signup(
            email=payload.email,
            password=payload.password,
            display_name=payload.display_name,
            timezone=payload.timezone,
        )
    except AuthError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    user = UserService(db).ensure_user_and_defaults(
        user_id=session.user_id,
        email=session.email,
        display_name=session.display_name,
        timezone=session.timezone,
        apple_sub=session.apple_sub,
    )
    db.commit()

    return AuthSessionResponse(
        access_token=session.access_token,
        refresh_token=session.refresh_token,
        expires_in=session.expires_in,
        user=UserResponse.model_validate(user),
    )


@router.post("/login", response_model=AuthSessionResponse)
def login(
    payload: EmailLoginRequest,
    db: Session = Depends(get_db),
    provider: AuthProvider = Depends(get_auth_provider),
):
    try:
        session = provider.login(email=payload.email, password=payload.password)
    except AuthError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc

    user = UserService(db).ensure_user_and_defaults(
        user_id=session.user_id,
        email=session.email,
        display_name=session.display_name,
        timezone=session.timezone,
        apple_sub=session.apple_sub,
    )
    db.commit()

    return AuthSessionResponse(
        access_token=session.access_token,
        refresh_token=session.refresh_token,
        expires_in=session.expires_in,
        user=UserResponse.model_validate(user),
    )


@router.post("/apple", response_model=AuthSessionResponse)
def apple_login(
    payload: AppleLoginRequest,
    db: Session = Depends(get_db),
    provider: AuthProvider = Depends(get_auth_provider),
):
    try:
        session = provider.apple(identity_token=payload.identity_token)
    except AuthError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc

    user = UserService(db).ensure_user_and_defaults(
        user_id=session.user_id,
        email=session.email,
        display_name=session.display_name,
        timezone=session.timezone,
        apple_sub=session.apple_sub,
    )
    db.commit()

    return AuthSessionResponse(
        access_token=session.access_token,
        refresh_token=session.refresh_token,
        expires_in=session.expires_in,
        user=UserResponse.model_validate(user),
    )
