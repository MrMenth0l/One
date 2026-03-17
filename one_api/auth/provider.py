from __future__ import annotations

import base64
import hashlib
import hmac
import json
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from typing import Protocol
from uuid import uuid4

import httpx

from one_api.config import Settings


@dataclass(slots=True)
class AuthIdentity:
    user_id: str
    email: str


@dataclass(slots=True)
class AuthSessionData:
    access_token: str
    refresh_token: str
    expires_in: int
    user_id: str
    email: str
    display_name: str
    timezone: str
    apple_sub: str | None = None


class AuthProvider(Protocol):
    def signup(self, *, email: str, password: str, display_name: str, timezone: str) -> AuthSessionData: ...

    def login(self, *, email: str, password: str) -> AuthSessionData: ...

    def apple(self, *, identity_token: str) -> AuthSessionData: ...

    def authenticate(self, *, access_token: str) -> AuthIdentity: ...


class AuthError(Exception):
    pass


class DevAuthProvider:
    def __init__(self, settings: Settings):
        self.settings = settings
        self._users_by_email: dict[str, dict[str, str]] = {}

    def _sign_token(self, user_id: str, email: str) -> str:
        expires = int((datetime.now(UTC) + timedelta(seconds=self.settings.access_token_ttl_seconds)).timestamp())
        payload = {"uid": user_id, "email": email, "exp": expires}
        raw = json.dumps(payload, separators=(",", ":")).encode("utf-8")
        signature = hmac.new(self.settings.dev_auth_secret.encode("utf-8"), raw, hashlib.sha256).hexdigest()
        return base64.urlsafe_b64encode(raw + b"." + signature.encode("ascii")).decode("ascii")

    def _decode_token(self, token: str) -> dict[str, str | int]:
        try:
            decoded = base64.urlsafe_b64decode(token.encode("ascii"))
            raw, signature = decoded.rsplit(b".", 1)
        except Exception as exc:
            raise AuthError("Invalid token format") from exc

        expected = hmac.new(self.settings.dev_auth_secret.encode("utf-8"), raw, hashlib.sha256).hexdigest().encode("ascii")
        if not hmac.compare_digest(signature, expected):
            raise AuthError("Invalid token signature")

        payload = json.loads(raw.decode("utf-8"))
        exp = int(payload.get("exp", 0))
        if exp < int(datetime.now(UTC).timestamp()):
            raise AuthError("Token expired")
        return payload

    def signup(self, *, email: str, password: str, display_name: str, timezone: str) -> AuthSessionData:
        if email in self._users_by_email:
            raise AuthError("Email already exists")

        user_id = str(uuid4())
        self._users_by_email[email] = {
            "user_id": user_id,
            "password": password,
            "display_name": display_name,
            "timezone": timezone,
        }
        access_token = self._sign_token(user_id=user_id, email=email)
        refresh_token = str(uuid4())
        return AuthSessionData(
            access_token=access_token,
            refresh_token=refresh_token,
            expires_in=self.settings.access_token_ttl_seconds,
            user_id=user_id,
            email=email,
            display_name=display_name,
            timezone=timezone,
        )

    def login(self, *, email: str, password: str) -> AuthSessionData:
        record = self._users_by_email.get(email)
        if record is None or record["password"] != password:
            raise AuthError("Invalid credentials")

        access_token = self._sign_token(user_id=record["user_id"], email=email)
        return AuthSessionData(
            access_token=access_token,
            refresh_token=str(uuid4()),
            expires_in=self.settings.access_token_ttl_seconds,
            user_id=record["user_id"],
            email=email,
            display_name=record["display_name"],
            timezone=record["timezone"],
        )

    def apple(self, *, identity_token: str) -> AuthSessionData:
        email = f"apple_{identity_token[:8]}@example.com"
        record = self._users_by_email.get(email)
        if record is None:
            return self.signup(
                email=email,
                password=str(uuid4()),
                display_name="Apple User",
                timezone="UTC",
            )

        return self.login(email=email, password=record["password"])

    def authenticate(self, *, access_token: str) -> AuthIdentity:
        payload = self._decode_token(access_token)
        return AuthIdentity(user_id=str(payload["uid"]), email=str(payload["email"]))


class SupabaseAuthProvider:
    def __init__(self, settings: Settings):
        if not settings.supabase_url or not settings.supabase_anon_key:
            raise AuthError("Supabase settings are missing")
        self.settings = settings
        self.base_url = settings.supabase_url.rstrip("/")

    def _headers(self, *, use_service_role: bool = False) -> dict[str, str]:
        key = self.settings.supabase_service_role_key if use_service_role else self.settings.supabase_anon_key
        if not key:
            raise AuthError("Supabase API key is missing")
        return {
            "apikey": key,
            "Content-Type": "application/json",
        }

    def signup(self, *, email: str, password: str, display_name: str, timezone: str) -> AuthSessionData:
        with httpx.Client(timeout=15) as client:
            resp = client.post(
                f"{self.base_url}/auth/v1/signup",
                headers=self._headers(),
                json={
                    "email": email,
                    "password": password,
                    "data": {"display_name": display_name, "timezone": timezone},
                },
            )
        if resp.status_code >= 400:
            raise AuthError(resp.text)
        data = resp.json()
        session = data.get("session") or {}
        user = data.get("user") or {}
        metadata = user.get("user_metadata") or {}
        return AuthSessionData(
            access_token=session.get("access_token", ""),
            refresh_token=session.get("refresh_token", ""),
            expires_in=int(session.get("expires_in", self.settings.access_token_ttl_seconds)),
            user_id=user.get("id", ""),
            email=user.get("email", email),
            display_name=metadata.get("display_name", display_name),
            timezone=metadata.get("timezone", timezone),
            apple_sub=user.get("app_metadata", {}).get("provider_id"),
        )

    def login(self, *, email: str, password: str) -> AuthSessionData:
        with httpx.Client(timeout=15) as client:
            resp = client.post(
                f"{self.base_url}/auth/v1/token?grant_type=password",
                headers=self._headers(),
                json={"email": email, "password": password},
            )
        if resp.status_code >= 400:
            raise AuthError(resp.text)
        data = resp.json()
        user = data.get("user") or {}
        metadata = user.get("user_metadata") or {}
        return AuthSessionData(
            access_token=data.get("access_token", ""),
            refresh_token=data.get("refresh_token", ""),
            expires_in=int(data.get("expires_in", self.settings.access_token_ttl_seconds)),
            user_id=user.get("id", ""),
            email=user.get("email", email),
            display_name=metadata.get("display_name", ""),
            timezone=metadata.get("timezone", "UTC"),
            apple_sub=user.get("app_metadata", {}).get("provider_id"),
        )

    def apple(self, *, identity_token: str) -> AuthSessionData:
        with httpx.Client(timeout=15) as client:
            resp = client.post(
                f"{self.base_url}/auth/v1/token?grant_type=id_token",
                headers=self._headers(),
                json={"provider": "apple", "id_token": identity_token},
            )
        if resp.status_code >= 400:
            raise AuthError(resp.text)
        data = resp.json()
        user = data.get("user") or {}
        metadata = user.get("user_metadata") or {}
        return AuthSessionData(
            access_token=data.get("access_token", ""),
            refresh_token=data.get("refresh_token", ""),
            expires_in=int(data.get("expires_in", self.settings.access_token_ttl_seconds)),
            user_id=user.get("id", ""),
            email=user.get("email", ""),
            display_name=metadata.get("display_name", "Apple User"),
            timezone=metadata.get("timezone", "UTC"),
            apple_sub=user.get("app_metadata", {}).get("provider_id"),
        )

    def authenticate(self, *, access_token: str) -> AuthIdentity:
        headers = self._headers()
        headers["Authorization"] = f"Bearer {access_token}"
        with httpx.Client(timeout=15) as client:
            resp = client.get(f"{self.base_url}/auth/v1/user", headers=headers)
        if resp.status_code >= 400:
            raise AuthError("Unauthorized")
        user = resp.json()
        return AuthIdentity(user_id=user.get("id", ""), email=user.get("email", ""))
