from __future__ import annotations

from datetime import UTC, datetime

from .models import PeriodType, ReflectionNote


_PROMPTS = {
    PeriodType.DAILY: "What worked today, and what blocked you?",
    PeriodType.WEEKLY: "What were this week's wins, misses, and one adjustment for next week?",
    PeriodType.MONTHLY: "What patterns helped or hurt your month?",
    PeriodType.YEARLY: "What mattered most this year, and what should change next year?",
}


def reflection_prompt(period_type: PeriodType) -> str:
    return _PROMPTS[period_type]


def upsert_reflection(notes: list[ReflectionNote], incoming: ReflectionNote) -> ReflectionNote:
    notes.append(incoming)
    return incoming


def delete_reflection(
    *,
    notes: list[ReflectionNote],
    user_id: str,
    reflection_id: str,
) -> bool:
    for index, note in enumerate(notes):
        if note.user_id == user_id and note.id == reflection_id:
            notes.pop(index)
            return True
    return False


def list_reflections(
    *,
    notes: list[ReflectionNote],
    user_id: str,
    period_type: PeriodType | None = None,
) -> list[ReflectionNote]:
    filtered = [note for note in notes if note.user_id == user_id]
    if period_type is not None:
        filtered = [note for note in filtered if note.period_type is period_type]
    return sorted(
        filtered,
        key=lambda note: (note.period_start, note.created_at or datetime.min.replace(tzinfo=UTC)),
        reverse=True,
    )


def search_reflections(
    *,
    notes: list[ReflectionNote],
    user_id: str,
    query: str,
) -> list[ReflectionNote]:
    q = query.lower().strip()
    if not q:
        return list_reflections(notes=notes, user_id=user_id)

    matched = []
    for note in notes:
        if note.user_id != user_id:
            continue
        if q in note.content.lower() or any(q in tag.lower() for tag in note.tags):
            matched.append(note)

    return sorted(
        matched,
        key=lambda note: (note.period_start, note.created_at or datetime.min.replace(tzinfo=UTC)),
        reverse=True,
    )
