from __future__ import annotations

import re
from dataclasses import replace
from datetime import UTC, datetime

from .models import PeriodType, ReflectionNote, ReflectionSentiment


_PROMPTS = {
    PeriodType.DAILY: "What worked today, and what blocked you?",
    PeriodType.WEEKLY: "What were this week's wins, misses, and one adjustment for next week?",
    PeriodType.MONTHLY: "What patterns helped or hurt your month?",
    PeriodType.YEARLY: "What mattered most this year, and what should change next year?",
}

_STOP_WORDS = {
    "a", "about", "after", "again", "all", "also", "am", "an", "and", "any", "are", "as", "at",
    "be", "because", "been", "before", "being", "but", "by", "can", "did", "do", "does", "down",
    "for", "from", "had", "has", "have", "how", "i", "if", "in", "into", "is", "it", "its",
    "just", "more", "my", "no", "not", "of", "on", "or", "out", "over", "really", "so", "some",
    "still", "that", "the", "their", "them", "then", "there", "these", "they", "this", "to",
    "today", "too", "up", "was", "we", "went", "were", "what", "when", "which", "while", "with",
    "would", "you", "your",
}


def _tokenize(content: str) -> list[str]:
    return re.findall(r"[a-z0-9]+", content.lower())


def _clean_token(token: str) -> str:
    value = token.lower().strip()
    for suffix in ("ing", "ed", "ly", "s"):
        if len(value) > 4 and value.endswith(suffix):
            return value[: -len(suffix)]
    return value


def _infer_note_type(tokens: list[str], content: str) -> str:
    lowered = content.lower()
    bullet_count = sum(
        1
        for line in lowered.splitlines()
        if line.strip().startswith(("-", "*", "•"))
    )
    question_count = lowered.count("?")
    first_person = sum(1 for token in tokens if token in {"i", "me", "my", "myself"})
    reflection_markers = sum(
        1
        for token in tokens
        if token in {"felt", "realized", "noticed", "learned", "processing", "remembered", "today", "yesterday"}
    )
    planning_markers = sum(
        1
        for token in tokens
        if token in {"plan", "next", "tomorrow", "need", "should", "schedule", "prepare", "goal", "follow", "ship"}
    )
    idea_markers = sum(
        1
        for token in tokens
        if token in {"idea", "maybe", "could", "build", "prototype", "experiment", "concept", "explore", "imagine"}
    )

    scores = {
        "quick-capture": 2.6 if len(tokens) <= 24 else 0.5,
        "reflection": float((reflection_markers * 2) + first_person + (1 if len(tokens) >= 40 else 0)),
        "planning": float((planning_markers * 2) + (bullet_count * 1.4) + (1.2 if "need to" in lowered else 0)),
        "idea": float((idea_markers * 2) + (question_count * 0.8) + (1.4 if "what if" in lowered else 0)),
    }
    if len(tokens) <= 18 and bullet_count == 0:
        scores["quick-capture"] += 1
    if "check" in lowered or "tomorrow" in lowered:
        scores["planning"] += 0.8
    if "i think" in lowered or "what if" in lowered:
        scores["idea"] += 0.8
    return max(scores.items(), key=lambda item: item[1])[0]


def derive_reflection_tags(
    *,
    content: str,
    sentiment: ReflectionSentiment,
    existing: list[str] | None = None,
) -> list[str]:
    tokens = _tokenize(content)
    tags = {_clean_token(tag) for tag in existing or [] if _clean_token(tag)}
    tags.add(_infer_note_type(tokens, content))

    cleaned_tokens = [
        _clean_token(token)
        for token in tokens
        if len(_clean_token(token)) > 2 and _clean_token(token) not in _STOP_WORDS
    ]
    tags.update(cleaned_tokens[:8])

    for first, second in zip(tokens, tokens[1:], strict=False):
        clean_first = _clean_token(first)
        clean_second = _clean_token(second)
        if len(clean_first) > 2 and len(clean_second) > 2 and clean_first not in _STOP_WORDS and clean_second not in _STOP_WORDS:
            tags.add(f"{clean_first}-{clean_second}")

    if sentiment is ReflectionSentiment.GREAT:
        tags.add("positive-momentum")
    elif sentiment is ReflectionSentiment.FOCUSED:
        tags.add("clear-focus")
    elif sentiment is ReflectionSentiment.TIRED:
        tags.add("low-energy")
    elif sentiment is ReflectionSentiment.STRESSED:
        tags.add("high-pressure")

    return sorted(tags)


def reflection_prompt(period_type: PeriodType) -> str:
    return _PROMPTS[period_type]


def upsert_reflection(notes: list[ReflectionNote], incoming: ReflectionNote) -> ReflectionNote:
    enriched = replace(
        incoming,
        tags=derive_reflection_tags(
            content=incoming.content,
            sentiment=incoming.sentiment,
            existing=incoming.tags,
        ),
    )
    notes.append(enriched)
    return enriched


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
