from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
from uuid import uuid4

from .models import Category, DEFAULT_CATEGORY_ICONS, DEFAULT_CATEGORY_NAMES, User, UserPreferences


@dataclass(slots=True)
class OnboardingBundle:
    user: User
    categories: list[Category]
    preferences: UserPreferences


def create_onboarding_bundle(
    *,
    user_id: str,
    email: str,
    display_name: str,
    timezone: str,
) -> OnboardingBundle:
    user = User(
        id=user_id,
        email=email,
        display_name=display_name,
        timezone=timezone,
        created_at=datetime.now(UTC),
    )

    categories: list[Category] = []
    for index, name in enumerate(DEFAULT_CATEGORY_NAMES):
        categories.append(
            Category(
                id=str(uuid4()),
                user_id=user_id,
                name=name,
                icon=DEFAULT_CATEGORY_ICONS.get(name, "category.generic"),
                sort_order=index,
                is_default=True,
            )
        )

    preferences = UserPreferences(
        id=str(uuid4()),
        user_id=user_id,
    )

    return OnboardingBundle(user=user, categories=categories, preferences=preferences)
