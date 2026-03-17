from __future__ import annotations

from functools import lru_cache

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from one_api.auth.provider import AuthError, AuthIdentity, AuthProvider, DevAuthProvider, SupabaseAuthProvider
from one_api.config import get_settings

security = HTTPBearer(auto_error=False)


@lru_cache(maxsize=1)
def get_auth_provider() -> AuthProvider:
    settings = get_settings()
    if settings.supabase_url and settings.supabase_anon_key:
        return SupabaseAuthProvider(settings)
    return DevAuthProvider(settings)


def get_current_identity(
    creds: HTTPAuthorizationCredentials | None = Depends(security),
    provider: AuthProvider = Depends(get_auth_provider),
) -> AuthIdentity:
    if creds is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing bearer token")
    try:
        return provider.authenticate(access_token=creds.credentials)
    except AuthError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
