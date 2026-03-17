from __future__ import annotations

from datetime import UTC, datetime

from sqlalchemy.orm import Session

from one_api.db.repositories import CategoryRepository, PreferencesRepository, UserRepository


class UserService:
    def __init__(self, db: Session):
        self.db = db
        self.users = UserRepository(db)
        self.categories = CategoryRepository(db)
        self.preferences = PreferencesRepository(db)

    def ensure_user_and_defaults(
        self,
        *,
        user_id: str,
        email: str,
        display_name: str,
        timezone: str,
        apple_sub: str | None = None,
    ):
        user = self.users.upsert(
            user_id=user_id,
            email=email,
            display_name=display_name,
            timezone=timezone,
            apple_sub=apple_sub,
        )
        self.categories.create_defaults(user_id)
        self.preferences.get_or_create(user_id)
        self.db.flush()
        return user

    def update_profile(self, *, user_id: str, display_name: str | None, timezone: str | None):
        row = self.users.get(user_id)
        if row is None:
            raise ValueError("User not found")
        if display_name is not None:
            row.display_name = display_name
        if timezone is not None:
            row.timezone = timezone
        row.updated_at = datetime.now(UTC)
        self.db.flush()
        return row
