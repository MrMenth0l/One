from __future__ import annotations

from datetime import date

from .models import CoachCard


def select_active_coach_cards(
    *,
    cards: list[CoachCard],
    target_date: date,
    tags: set[str] | None = None,
    limit: int = 3,
) -> list[CoachCard]:
    selected: list[CoachCard] = []
    tags = tags or set()

    for card in cards:
        if not card.is_active:
            continue
        if card.active_from is not None and target_date < card.active_from:
            continue
        if card.active_to is not None and target_date > card.active_to:
            continue
        if tags and card.tags and not tags.intersection(set(card.tags)):
            continue
        selected.append(card)

    selected.sort(key=lambda card: (card.active_from or target_date, card.title))
    return selected[:limit]
