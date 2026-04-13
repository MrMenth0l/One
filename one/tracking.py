from __future__ import annotations

from collections import Counter
from dataclasses import dataclass
from datetime import UTC, date, datetime, time
from enum import Enum
import re
from uuid import uuid4
from zoneinfo import ZoneInfo

from .models import CompletionLog, CompletionState, Habit, ItemType, Todo, TodoStatus

_WEEKDAY_INDEX = {
    "MON": 0,
    "TUE": 1,
    "WED": 2,
    "THU": 3,
    "FRI": 4,
    "SAT": 5,
    "SUN": 6,
}

_TITLE_STOPWORDS = {
    "a",
    "an",
    "and",
    "for",
    "from",
    "in",
    "of",
    "on",
    "the",
    "to",
    "with",
}
_QUICK_TOKENS = {
    "call",
    "email",
    "pay",
    "plan",
    "reply",
    "review",
    "send",
    "stretch",
    "tidy",
    "water",
}
_DEEP_TOKENS = {
    "assignment",
    "build",
    "clean",
    "deep",
    "design",
    "essay",
    "gym",
    "project",
    "study",
    "train",
    "workout",
    "write",
}


class TodayProminence(str, Enum):
    COMPACT = "compact"
    STANDARD = "standard"
    FEATURED = "featured"


class TodaySurfaceZone(str, Enum):
    FLOW = "flow"
    QUIET = "quiet"
    HIDDEN = "hidden"


class TodayUrgency(str, Enum):
    NONE = "none"
    SOON = "soon"
    DUE_TODAY = "due_today"
    OVERDUE = "overdue"


class TodayTimeBucket(str, Enum):
    ANYTIME = "anytime"
    MORNING = "morning"
    MIDDAY = "midday"
    EVENING = "evening"
    LATE = "late"


@dataclass(slots=True)
class TodayOrderOverride:
    date_local: date
    item_type: ItemType
    item_id: str
    order_index: int


@dataclass(slots=True)
class _HistorySignal:
    time_bucket: TodayTimeBucket
    time_confidence: float
    preferred_weekdays: set[int]
    weekday_confidence: float
    routine_strength: float
    observation_count: int


@dataclass(slots=True)
class _TodayDraft:
    item: TodayItem
    current_override_index: int | None
    recency_key: float
    title_key: str
    due_pressure: float
    manual_boost: float
    priority_value: float
    zone_rank: int


@dataclass(slots=True)
class TodayItem:
    item_type: ItemType
    item_id: str
    title: str
    category_id: str
    completed: bool
    sort_bucket: int
    sort_score: float
    subtitle: str | None = None
    is_pinned: bool | None = None
    priority: int | None = None
    due_at: datetime | None = None
    preferred_time: time | None = None
    blended_score: float = 0.0
    prominence: TodayProminence = TodayProminence.STANDARD
    surface_zone: TodaySurfaceZone = TodaySurfaceZone.FLOW
    urgency: TodayUrgency = TodayUrgency.NONE
    time_bucket: TodayTimeBucket = TodayTimeBucket.ANYTIME
    cluster_key: str = ""
    learning_confidence: float = 0.0
    manual_boost: float = 0.0


def _as_local(dt: datetime, timezone: str) -> datetime:
    tz = ZoneInfo(timezone)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=UTC)
    return dt.astimezone(tz)


def _coerce_local(dt: datetime, timezone: str) -> datetime:
    if dt.tzinfo is None:
        return dt.replace(tzinfo=ZoneInfo(timezone))
    return dt.astimezone(ZoneInfo(timezone))


def todo_action_date(todo: Todo, timezone: str) -> date:
    if todo.due_at is not None:
        return _as_local(todo.due_at, timezone).date()
    return _as_local(todo.created_at, timezone).date()


def is_habit_scheduled(habit: Habit, target_date: date) -> bool:
    if not habit.is_active:
        return False
    if target_date < habit.start_date:
        return False
    if habit.end_date is not None and target_date > habit.end_date:
        return False

    rule = habit.recurrence_rule.strip().upper()
    if not rule or rule == "DAILY":
        return True

    if rule.startswith("WEEKLY:"):
        day_codes = [x.strip() for x in rule.split(":", 1)[1].split(",") if x.strip()]
        valid_days = {_WEEKDAY_INDEX[d] for d in day_codes if d in _WEEKDAY_INDEX}
        return target_date.weekday() in valid_days

    if rule.startswith("MONTHLY:"):
        days = [x.strip() for x in rule.split(":", 1)[1].split(",") if x.strip()]
        valid_days = {int(d) for d in days if d.isdigit()}
        return target_date.day in valid_days

    if rule.startswith("YEARLY:"):
        month_days = [x.strip() for x in rule.split(":", 1)[1].split(",") if x.strip()]
        current = f"{target_date.month:02d}-{target_date.day:02d}"
        return current in month_days

    return False


def materialize_habit_logs(
    *,
    user_id: str,
    habits: list[Habit],
    target_date: date,
    existing_logs: list[CompletionLog],
    source: str = "materializer",
) -> list[CompletionLog]:
    existing_keys = {
        (log.item_type, log.item_id, log.date_local)
        for log in existing_logs
        if log.item_type is ItemType.HABIT
    }
    created: list[CompletionLog] = []

    for habit in habits:
        if habit.user_id != user_id:
            continue
        if not is_habit_scheduled(habit, target_date):
            continue
        key = (ItemType.HABIT, habit.id, target_date)
        if key in existing_keys:
            continue

        created.append(
            CompletionLog(
                id=str(uuid4()),
                user_id=user_id,
                item_type=ItemType.HABIT,
                item_id=habit.id,
                date_local=target_date,
                state=CompletionState.NOT_COMPLETED,
                source=source,
            )
        )

    return created


def set_habit_completion(
    *,
    logs: list[CompletionLog],
    user_id: str,
    habit_id: str,
    target_date: date,
    completed: bool,
    source: str = "app",
    completed_at: datetime | None = None,
) -> CompletionLog:
    now = datetime.now(UTC)
    for log in logs:
        if (
            log.user_id == user_id
            and log.item_type is ItemType.HABIT
            and log.item_id == habit_id
            and log.date_local == target_date
        ):
            log.state = CompletionState.COMPLETED if completed else CompletionState.NOT_COMPLETED
            log.completed_at = completed_at or now if completed else None
            log.updated_at = now
            log.source = source
            return log

    new_log = CompletionLog(
        id=str(uuid4()),
        user_id=user_id,
        item_type=ItemType.HABIT,
        item_id=habit_id,
        date_local=target_date,
        state=CompletionState.COMPLETED if completed else CompletionState.NOT_COMPLETED,
        completed_at=completed_at or now if completed else None,
        source=source,
    )
    logs.append(new_log)
    return new_log


def set_todo_completion(todo: Todo, *, completed: bool, completed_at: datetime | None = None) -> Todo:
    now = datetime.now(UTC)
    if completed:
        todo.status = TodoStatus.COMPLETED
        todo.completed_at = completed_at or now
    else:
        todo.status = TodoStatus.OPEN
        todo.completed_at = None
    todo.updated_at = now
    return todo


def _todo_urgency_score(todo: Todo, today: date, timezone: str) -> float:
    score = float(todo.priority)
    if todo.due_at is None:
        return score

    due_date = _as_local(todo.due_at, timezone).date()
    delta = (due_date - today).days
    if delta < 0:
        score += 200 + abs(delta) * 10
    elif delta == 0:
        score += 150
    elif delta == 1:
        score += 100
    else:
        score += max(0, 40 - delta)
    return score


def _habit_sort_score(habit: Habit) -> float:
    score = float(habit.priority_weight)
    if habit.preferred_time is not None:
        minutes = habit.preferred_time.hour * 60 + habit.preferred_time.minute
        # Earlier preferred times are ranked slightly higher for morning planning.
        score += max(0, (24 * 60 - minutes) / 1440)
    return score


def _todo_today_sort_key(todo: Todo, today: date, timezone: str) -> tuple[float, float, str]:
    return (
        -_todo_urgency_score(todo, today, timezone),
        -todo.created_at.timestamp(),
        todo.title.casefold(),
    )


def _habit_today_sort_key(habit: Habit) -> tuple[float, str]:
    return (-_habit_sort_score(habit), habit.title.casefold())


def _minutes_from_time(value: time | None) -> int | None:
    if value is None:
        return None
    return value.hour * 60 + value.minute


def _bucket_from_minutes(minutes: int | None) -> TodayTimeBucket:
    if minutes is None:
        return TodayTimeBucket.ANYTIME
    if minutes < 11 * 60:
        return TodayTimeBucket.MORNING
    if minutes < 16 * 60:
        return TodayTimeBucket.MIDDAY
    if minutes < 22 * 60:
        return TodayTimeBucket.EVENING
    return TodayTimeBucket.LATE


def _bucket_phrase(bucket: TodayTimeBucket) -> str:
    return {
        TodayTimeBucket.ANYTIME: "anytime",
        TodayTimeBucket.MORNING: "mornings",
        TodayTimeBucket.MIDDAY: "midday",
        TodayTimeBucket.EVENING: "evenings",
        TodayTimeBucket.LATE: "late",
    }[bucket]


def _bucket_distance(left: TodayTimeBucket, right: TodayTimeBucket) -> float:
    order = {
        TodayTimeBucket.MORNING: 0,
        TodayTimeBucket.MIDDAY: 1,
        TodayTimeBucket.EVENING: 2,
        TodayTimeBucket.LATE: 3,
        TodayTimeBucket.ANYTIME: 1.5,
    }
    return abs(order[left] - order[right]) / 3.0


def _normalize_title_signature(title: str) -> str:
    tokens = [
        token
        for token in re.findall(r"[a-z0-9]+", title.casefold())
        if token not in _TITLE_STOPWORDS
    ]
    if not tokens:
        return "untitled"
    return "-".join(tokens[:4])


def _effort_band(title: str, notes: str) -> str:
    tokens = set(re.findall(r"[a-z0-9]+", f"{title} {notes}".casefold()))
    if tokens & _DEEP_TOKENS:
        return "deep"
    if tokens & _QUICK_TOKENS:
        return "quick"
    return "steady"


def _default_time_signal(
    *,
    item_type: ItemType,
    title: str,
    notes: str,
    category_name: str,
    due_at: datetime | None,
    preferred_time: time | None,
    timezone: str,
) -> tuple[TodayTimeBucket, float]:
    if preferred_time is not None:
        return _bucket_from_minutes(_minutes_from_time(preferred_time)), 0.76
    if due_at is not None:
        local_due = _as_local(due_at, timezone)
        return _bucket_from_minutes(local_due.hour * 60 + local_due.minute), 0.58

    text = f"{category_name} {title} {notes}".casefold()
    if any(word in text for word in {"workout", "gym", "pray", "journal", "run", "school", "study"}):
        return TodayTimeBucket.MORNING, 0.24
    if any(word in text for word in {"admin", "call", "email", "meeting", "pay", "reply", "send"}):
        return TodayTimeBucket.MIDDAY, 0.24
    if any(word in text for word in {"clean", "plan", "read", "review", "reset", "tidy"}):
        return TodayTimeBucket.EVENING, 0.24
    if item_type is ItemType.HABIT:
        return TodayTimeBucket.MORNING, 0.18
    return TodayTimeBucket.ANYTIME, 0.14


def _time_history_signal(
    *,
    completed_times: list[datetime],
    fallback_bucket: TodayTimeBucket,
    fallback_confidence: float,
) -> _HistorySignal:
    if not completed_times:
        return _HistorySignal(
            time_bucket=fallback_bucket,
            time_confidence=fallback_confidence,
            preferred_weekdays=set(),
            weekday_confidence=0.0,
            routine_strength=0.0,
            observation_count=0,
        )

    bucket_counts = Counter(
        _bucket_from_minutes(value.hour * 60 + value.minute)
        for value in completed_times
    )
    dominant_bucket, dominant_bucket_count = bucket_counts.most_common(1)[0]
    weekday_counts = Counter(value.weekday() for value in completed_times)
    dominant_weekday_count = weekday_counts.most_common(1)[0][1]
    dominant_bucket_share = dominant_bucket_count / len(completed_times)
    preferred_weekdays = {
        weekday
        for weekday, count in weekday_counts.items()
        if len(completed_times) >= 5 and count >= 2 and count / len(completed_times) >= 0.4
    }
    return _HistorySignal(
        time_bucket=dominant_bucket if len(completed_times) >= 5 and dominant_bucket_share >= 0.45 else fallback_bucket,
        time_confidence=max(
            fallback_confidence,
            dominant_bucket_share * min(1.0, len(completed_times) / 7.0),
        ),
        preferred_weekdays=preferred_weekdays,
        weekday_confidence=(dominant_weekday_count / len(completed_times)) * min(1.0, len(completed_times) / 7.0) if len(completed_times) >= 5 else 0.0,
        routine_strength=min(1.0, len(completed_times) / 10.0),
        observation_count=len(completed_times),
    )


def _todo_history_signal(
    *,
    todo: Todo,
    todos: list[Todo],
    timezone: str,
    fallback_bucket: TodayTimeBucket,
    fallback_confidence: float,
) -> _HistorySignal:
    signature = _normalize_title_signature(todo.title)
    completed_times = [
        _as_local(candidate.completed_at, timezone)
        for candidate in todos
        if candidate.status is TodoStatus.COMPLETED
        and candidate.completed_at is not None
        and candidate.category_id == todo.category_id
        and _normalize_title_signature(candidate.title) == signature
    ]
    return _time_history_signal(
        completed_times=completed_times,
        fallback_bucket=fallback_bucket,
        fallback_confidence=fallback_confidence,
    )


def _habit_history_signal(
    *,
    habit: Habit,
    completion_logs: list[CompletionLog],
    timezone: str,
    fallback_bucket: TodayTimeBucket,
    fallback_confidence: float,
) -> _HistorySignal:
    completed_times = [
        _as_local(log.completed_at, timezone)
        for log in completion_logs
        if log.item_type is ItemType.HABIT
        and log.item_id == habit.id
        and log.state is CompletionState.COMPLETED
        and log.completed_at is not None
    ]
    return _time_history_signal(
        completed_times=completed_times,
        fallback_bucket=fallback_bucket,
        fallback_confidence=fallback_confidence,
    )


def _manual_boost_for_item(
    *,
    item_type: ItemType,
    item_id: str,
    title_signature: str,
    category_id: str,
    today: date,
    is_pinned: bool,
    current_override_lookup: dict[tuple[ItemType, str], int],
    history_overrides: list[TodayOrderOverride],
    todo_lookup: dict[str, Todo],
    habit_lookup: dict[str, Habit],
) -> tuple[float, int | None]:
    current_override_index = current_override_lookup.get((item_type, item_id))
    boost = 0.0
    if current_override_index is not None:
        if current_override_index == 0:
            boost += 0.24
        elif current_override_index <= 2:
            boost += 0.15
        else:
            boost += 0.06
    if is_pinned:
        boost += 0.14

    history_count = 0
    for override in history_overrides:
        if override.date_local >= today or override.order_index > 2 or override.item_type is not item_type:
            continue
        if item_type is ItemType.HABIT:
            if override.item_id == item_id:
                history_count += 1
            continue
        candidate = todo_lookup.get(override.item_id)
        if candidate is None:
            continue
        if candidate.category_id == category_id and _normalize_title_signature(candidate.title) == title_signature:
            history_count += 1

    if history_count >= 2:
        boost += min(0.14, 0.04 + (history_count - 2) * 0.025)
    return boost, current_override_index


def _todo_due_pressure(todo: Todo, *, today: date, timezone: str) -> tuple[float, TodayUrgency]:
    if todo.due_at is None:
        return 0.0, TodayUrgency.NONE
    due_date = _as_local(todo.due_at, timezone).date()
    delta = (due_date - today).days
    if delta < 0:
        return min(1.0, 0.9 + abs(delta) * 0.06), TodayUrgency.OVERDUE
    if delta == 0:
        return 0.82, TodayUrgency.DUE_TODAY
    if delta == 1:
        return 0.42, TodayUrgency.SOON
    if delta <= 3:
        return max(0.16, 0.28 - delta * 0.03), TodayUrgency.SOON
    return 0.0, TodayUrgency.NONE


def _habit_due_pressure(
    *,
    current_bucket: TodayTimeBucket,
    target_bucket: TodayTimeBucket,
    confidence: float,
) -> float:
    if target_bucket is TodayTimeBucket.ANYTIME:
        return 0.0
    if current_bucket == target_bucket:
        return 0.1 * confidence
    order = {
        TodayTimeBucket.MORNING: 0,
        TodayTimeBucket.MIDDAY: 1,
        TodayTimeBucket.EVENING: 2,
        TodayTimeBucket.LATE: 3,
        TodayTimeBucket.ANYTIME: 1,
    }
    current_order = order[current_bucket]
    target_order = order[target_bucket]
    if current_order > target_order:
        return min(0.32, (0.14 + (current_order - target_order) * 0.07) * confidence)
    return max(0.0, (0.05 - (target_order - current_order) * 0.02) * confidence)


def _time_match_score(
    *,
    current_bucket: TodayTimeBucket,
    target_bucket: TodayTimeBucket,
    confidence: float,
) -> float:
    if target_bucket is TodayTimeBucket.ANYTIME:
        return 0.03 * confidence
    return max(0.0, (0.15 - _bucket_distance(current_bucket, target_bucket) * 0.1) * confidence)


def _weekday_match_score(
    *,
    today: date,
    preferred_weekdays: set[int],
    confidence: float,
) -> float:
    if not preferred_weekdays:
        return 0.0
    return 0.07 * confidence if today.weekday() in preferred_weekdays else 0.0


def _recent_todo_boost(todo: Todo, *, today: date, timezone: str, current_local_dt: datetime) -> float:
    created_local = _as_local(todo.created_at, timezone)
    day_gap = (today - created_local.date()).days
    if day_gap < 0:
        return 0.0
    if day_gap == 0:
        age_hours = max(0.0, (current_local_dt - created_local).total_seconds() / 3600.0)
        return 0.04 if age_hours <= 18 else 0.025
    if day_gap == 1:
        return 0.015
    return 0.0


def _effort_context_score(
    *,
    item_type: ItemType,
    effort_band: str,
    current_bucket: TodayTimeBucket,
    category_name: str,
    title: str,
    notes: str,
) -> float:
    text = f"{category_name} {title} {notes}".casefold()
    if any(word in text for word in {"admin", "call", "email", "meeting", "pay", "reply", "send"}):
        return 0.03 if current_bucket in {TodayTimeBucket.MIDDAY, TodayTimeBucket.EVENING} else 0.0
    if any(word in text for word in {"gym", "journal", "pray", "run", "study", "workout", "write"}):
        return 0.04 if current_bucket in {TodayTimeBucket.MORNING, TodayTimeBucket.MIDDAY} else 0.0
    if item_type is ItemType.HABIT and any(word in text for word in {"clean", "reset", "tidy"}):
        return 0.03 if current_bucket in {TodayTimeBucket.EVENING, TodayTimeBucket.LATE} else 0.0
    if effort_band == "deep":
        return 0.04 if current_bucket in {TodayTimeBucket.MORNING, TodayTimeBucket.MIDDAY} else 0.0
    if effort_band == "quick":
        return 0.02 if current_bucket in {TodayTimeBucket.MIDDAY, TodayTimeBucket.EVENING} else 0.0
    return 0.0


def _supporting_line(
    *,
    item_type: ItemType,
    completed: bool,
    surface_zone: TodaySurfaceZone,
    urgency: TodayUrgency,
    manual_boost: float,
    is_pinned: bool,
    history: _HistorySignal,
    category_name: str,
    notes: str,
    recurrence_rule: str | None,
    effort_band: str,
) -> str:
    if completed:
        if surface_zone is TodaySurfaceZone.QUIET:
            return "Done, still visible"
        return "Completed"
    if urgency is TodayUrgency.OVERDUE:
        return "Recovery first"
    if urgency is TodayUrgency.DUE_TODAY:
        return "Needs attention"
    if urgency is TodayUrgency.SOON:
        return "Coming into view"
    if manual_boost >= 0.22:
        return "Do first"
    if is_pinned:
        return "Pinned focus"
    if history.observation_count >= 5 and history.weekday_confidence >= 0.62:
        return "Usual for today"
    if history.observation_count >= 5 and history.routine_strength >= 0.55:
        return "Stable routine" if item_type is ItemType.HABIT else "Fits your rhythm"
    if item_type is ItemType.HABIT:
        rule = (recurrence_rule or "").strip().upper()
        if not rule or rule == "DAILY":
            return "Daily anchor"
        if rule.startswith("WEEKLY:"):
            return "Weekly anchor"
        return "Keeps the rhythm"
    if notes.strip():
        return "Context ready"
    if effort_band == "quick":
        return "Quick clear"
    if effort_band == "deep":
        return "Longer block"
    return category_name or "Ready to move"

def _prominence_for_rank(
    *,
    surface_zone: TodaySurfaceZone,
    flow_rank: int,
    flow_count: int,
    top_flow_score: float,
    blended_score: float,
    urgency: TodayUrgency,
    current_override_index: int | None,
    priority_value: float,
    manual_boost: float,
) -> TodayProminence:
    if surface_zone is not TodaySurfaceZone.FLOW:
        return TodayProminence.COMPACT
    if flow_rank == 0:
        return TodayProminence.FEATURED
    if (
        flow_rank == 1
        and flow_count >= 7
        and (
            urgency is not TodayUrgency.NONE
            or current_override_index == 0
            or manual_boost >= 0.16
            or priority_value >= 0.8
            or blended_score >= top_flow_score * 0.88
        )
    ):
        return TodayProminence.FEATURED
    if (
        flow_count >= 8
        and flow_rank >= flow_count - 2
        and urgency is TodayUrgency.NONE
        and priority_value < 0.45
        and manual_boost < 0.1
        and blended_score < max(0.42, top_flow_score * 0.52)
    ):
        return TodayProminence.COMPACT
    return TodayProminence.STANDARD


def _zone_for_item(
    *,
    item_type: ItemType,
    completed: bool,
    priority_value: float,
    is_pinned: bool,
    history: _HistorySignal,
    manual_boost: float,
) -> TodaySurfaceZone:
    if not completed:
        return TodaySurfaceZone.FLOW
    should_keep_quiet = (
        item_type is ItemType.HABIT
        and (priority_value >= 0.62 or history.routine_strength >= 0.5 or history.time_confidence >= 0.6)
    ) or is_pinned or manual_boost >= 0.18
    return TodaySurfaceZone.QUIET if should_keep_quiet else TodaySurfaceZone.HIDDEN


def _zone_rank(zone: TodaySurfaceZone) -> int:
    return {
        TodaySurfaceZone.FLOW: 0,
        TodaySurfaceZone.QUIET: 1,
        TodaySurfaceZone.HIDDEN: 2,
    }[zone]


def build_today_items(
    *,
    today: date,
    timezone: str,
    habits: list[Habit],
    todos: list[Todo],
    completion_logs: list[CompletionLog],
    order_overrides: list[TodayOrderOverride] | None = None,
    categories_by_id: dict[str, str] | None = None,
    current_local_dt: datetime | None = None,
) -> list[TodayItem]:
    order_overrides = order_overrides or []
    categories_by_id = categories_by_id or {}
    now_local = current_local_dt
    if now_local is None:
        now_local = datetime.now(UTC).astimezone(ZoneInfo(timezone))
    else:
        now_local = _coerce_local(now_local, timezone)
    if now_local.date() != today:
        now_local = datetime.combine(today, time(13, 0), tzinfo=ZoneInfo(timezone))
    current_bucket = _bucket_from_minutes(now_local.hour * 60 + now_local.minute)

    habit_logs = {
        log.item_id: log
        for log in completion_logs
        if log.item_type is ItemType.HABIT and log.date_local == today
    }
    current_override_lookup = {
        (override.item_type, override.item_id): override.order_index
        for override in order_overrides
        if override.date_local == today
    }
    todo_lookup = {todo.id: todo for todo in todos}
    habit_lookup = {habit.id: habit for habit in habits}
    relevant_todos = [
        todo
        for todo in todos
        if (
            todo.status is TodoStatus.OPEN
            or (todo.status is TodoStatus.COMPLETED and todo_action_date(todo, timezone) == today)
        )
    ]
    scheduled_habits = [habit for habit in habits if is_habit_scheduled(habit, today)]
    drafts: list[_TodayDraft] = []

    for todo in relevant_todos:
        category_name = categories_by_id.get(todo.category_id, "")
        title_signature = _normalize_title_signature(todo.title)
        default_bucket, default_confidence = _default_time_signal(
            item_type=ItemType.TODO,
            title=todo.title,
            notes=todo.notes,
            category_name=category_name,
            due_at=todo.due_at,
            preferred_time=None,
            timezone=timezone,
        )
        history = _todo_history_signal(
            todo=todo,
            todos=todos,
            timezone=timezone,
            fallback_bucket=default_bucket,
            fallback_confidence=default_confidence,
        )
        manual_boost, current_override_index = _manual_boost_for_item(
            item_type=ItemType.TODO,
            item_id=todo.id,
            title_signature=title_signature,
            category_id=todo.category_id,
            today=today,
            is_pinned=todo.is_pinned,
            current_override_lookup=current_override_lookup,
            history_overrides=order_overrides,
            todo_lookup=todo_lookup,
            habit_lookup=habit_lookup,
        )
        due_pressure, urgency = _todo_due_pressure(todo, today=today, timezone=timezone)
        priority_value = 1.0 if todo.is_pinned else (todo.priority / 100.0)
        time_match = _time_match_score(
            current_bucket=current_bucket,
            target_bucket=history.time_bucket,
            confidence=history.time_confidence,
        )
        weekday_match = _weekday_match_score(
            today=today,
            preferred_weekdays=history.preferred_weekdays,
            confidence=history.weekday_confidence,
        )
        effort = _effort_band(todo.title, todo.notes)
        context_fit = _effort_context_score(
            item_type=ItemType.TODO,
            effort_band=effort,
            current_bucket=current_bucket,
            category_name=category_name,
            title=todo.title,
            notes=todo.notes,
        )
        freshness = _recent_todo_boost(todo, today=today, timezone=timezone, current_local_dt=now_local)
        blended_score = (
            priority_value * 0.24
            + due_pressure * 0.36
            + time_match
            + weekday_match
            + history.routine_strength * 0.06
            + context_fit
            + freshness
            + manual_boost
        )
        surface_zone = _zone_for_item(
            item_type=ItemType.TODO,
            completed=todo.status is TodoStatus.COMPLETED,
            priority_value=priority_value,
            is_pinned=todo.is_pinned,
            history=history,
            manual_boost=manual_boost,
        )
        subtitle = _supporting_line(
            item_type=ItemType.TODO,
            completed=todo.status is TodoStatus.COMPLETED,
            surface_zone=surface_zone,
            urgency=urgency,
            manual_boost=manual_boost,
            is_pinned=todo.is_pinned,
            history=history,
            category_name=category_name,
            notes=todo.notes,
            recurrence_rule=None,
            effort_band=effort,
        )
        item = TodayItem(
            item_type=ItemType.TODO,
            item_id=todo.id,
            title=todo.title,
            category_id=todo.category_id,
            completed=todo.status is TodoStatus.COMPLETED,
            sort_bucket=_zone_rank(surface_zone) * 10 + (0 if urgency is TodayUrgency.OVERDUE else 1 if urgency is TodayUrgency.DUE_TODAY else 2 if urgency is TodayUrgency.SOON else 3),
            sort_score=blended_score,
            subtitle=subtitle,
            is_pinned=todo.is_pinned,
            priority=todo.priority,
            due_at=todo.due_at,
            blended_score=blended_score,
            surface_zone=surface_zone,
            urgency=urgency,
            time_bucket=history.time_bucket,
            cluster_key=f"todo:{todo.category_id}:{title_signature}",
            learning_confidence=max(history.time_confidence, history.weekday_confidence),
            manual_boost=manual_boost,
        )
        drafts.append(
            _TodayDraft(
                item=item,
                current_override_index=current_override_index,
                recency_key=todo.created_at.timestamp(),
                title_key=todo.title.casefold(),
                due_pressure=due_pressure,
                manual_boost=manual_boost,
                priority_value=priority_value,
                zone_rank=_zone_rank(surface_zone),
            )
        )

    for habit in scheduled_habits:
        log = habit_logs.get(habit.id)
        category_name = categories_by_id.get(habit.category_id, "")
        default_bucket, default_confidence = _default_time_signal(
            item_type=ItemType.HABIT,
            title=habit.title,
            notes=habit.notes,
            category_name=category_name,
            due_at=None,
            preferred_time=habit.preferred_time,
            timezone=timezone,
        )
        history = _habit_history_signal(
            habit=habit,
            completion_logs=completion_logs,
            timezone=timezone,
            fallback_bucket=default_bucket,
            fallback_confidence=default_confidence,
        )
        manual_boost, current_override_index = _manual_boost_for_item(
            item_type=ItemType.HABIT,
            item_id=habit.id,
            title_signature=_normalize_title_signature(habit.title),
            category_id=habit.category_id,
            today=today,
            is_pinned=False,
            current_override_lookup=current_override_lookup,
            history_overrides=order_overrides,
            todo_lookup=todo_lookup,
            habit_lookup=habit_lookup,
        )
        priority_value = habit.priority_weight / 100.0
        due_pressure = _habit_due_pressure(
            current_bucket=current_bucket,
            target_bucket=history.time_bucket,
            confidence=history.time_confidence,
        )
        urgency = TodayUrgency.SOON if due_pressure >= 0.18 and log is not None and log.state is not CompletionState.COMPLETED else TodayUrgency.NONE
        time_match = _time_match_score(
            current_bucket=current_bucket,
            target_bucket=history.time_bucket,
            confidence=history.time_confidence,
        )
        weekday_match = _weekday_match_score(
            today=today,
            preferred_weekdays=history.preferred_weekdays,
            confidence=history.weekday_confidence,
        )
        effort = _effort_band(habit.title, habit.notes)
        context_fit = _effort_context_score(
            item_type=ItemType.HABIT,
            effort_band=effort,
            current_bucket=current_bucket,
            category_name=category_name,
            title=habit.title,
            notes=habit.notes,
        )
        blended_score = (
            priority_value * 0.34
            + due_pressure * 0.22
            + time_match
            + weekday_match
            + history.routine_strength * 0.14
            + context_fit
            + manual_boost
        )
        is_completed = log is not None and log.state is CompletionState.COMPLETED
        surface_zone = _zone_for_item(
            item_type=ItemType.HABIT,
            completed=is_completed,
            priority_value=priority_value,
            is_pinned=False,
            history=history,
            manual_boost=manual_boost,
        )
        subtitle = _supporting_line(
            item_type=ItemType.HABIT,
            completed=is_completed,
            surface_zone=surface_zone,
            urgency=urgency,
            manual_boost=manual_boost,
            is_pinned=False,
            history=history,
            category_name=category_name,
            notes=habit.notes,
            recurrence_rule=habit.recurrence_rule,
            effort_band=effort,
        )
        item = TodayItem(
            item_type=ItemType.HABIT,
            item_id=habit.id,
            title=habit.title,
            category_id=habit.category_id,
            completed=is_completed,
            sort_bucket=_zone_rank(surface_zone) * 10 + (0 if urgency is TodayUrgency.OVERDUE else 1 if urgency is TodayUrgency.DUE_TODAY else 2 if urgency is TodayUrgency.SOON else 3),
            sort_score=blended_score,
            subtitle=subtitle,
            is_pinned=False,
            priority=habit.priority_weight,
            preferred_time=habit.preferred_time,
            blended_score=blended_score,
            surface_zone=surface_zone,
            urgency=urgency,
            time_bucket=history.time_bucket,
            cluster_key=f"habit:{habit.category_id}:{_normalize_title_signature(habit.title)}",
            learning_confidence=max(history.time_confidence, history.weekday_confidence),
            manual_boost=manual_boost,
        )
        drafts.append(
            _TodayDraft(
                item=item,
                current_override_index=current_override_index,
                recency_key=0.0,
                title_key=habit.title.casefold(),
                due_pressure=due_pressure,
                manual_boost=manual_boost,
                priority_value=priority_value,
                zone_rank=_zone_rank(surface_zone),
            )
        )

    drafts.sort(
        key=lambda draft: (
            draft.zone_rank,
            draft.current_override_index is None,
            draft.current_override_index if draft.current_override_index is not None else 10_000,
            draft.item.sort_bucket,
            -draft.item.blended_score,
            -draft.manual_boost,
            -draft.due_pressure,
            -draft.priority_value,
            -draft.recency_key,
            draft.title_key,
        )
    )
    flow_drafts = [draft for draft in drafts if draft.item.surface_zone is TodaySurfaceZone.FLOW]
    top_flow_score = flow_drafts[0].item.blended_score if flow_drafts else 0.0
    flow_count = len(flow_drafts)

    finalized: list[TodayItem] = []
    flow_rank = 0
    for draft in drafts:
        if draft.item.surface_zone is TodaySurfaceZone.FLOW:
            prominence = _prominence_for_rank(
                surface_zone=draft.item.surface_zone,
                flow_rank=flow_rank,
                flow_count=flow_count,
                top_flow_score=top_flow_score,
                blended_score=draft.item.blended_score,
                urgency=draft.item.urgency,
                current_override_index=draft.current_override_index,
                priority_value=draft.priority_value,
                manual_boost=draft.manual_boost,
            )
            flow_rank += 1
        else:
            prominence = TodayProminence.COMPACT

        finalized.append(
            TodayItem(
                item_type=draft.item.item_type,
                item_id=draft.item.item_id,
                title=draft.item.title,
                category_id=draft.item.category_id,
                completed=draft.item.completed,
                sort_bucket=draft.item.sort_bucket,
                sort_score=draft.item.sort_score,
                subtitle=draft.item.subtitle,
                is_pinned=draft.item.is_pinned,
                priority=draft.item.priority,
                due_at=draft.item.due_at,
                preferred_time=draft.item.preferred_time,
                blended_score=draft.item.blended_score,
                prominence=prominence,
                surface_zone=draft.item.surface_zone,
                urgency=draft.item.urgency,
                time_bucket=draft.item.time_bucket,
                cluster_key=draft.item.cluster_key,
                learning_confidence=draft.item.learning_confidence,
                manual_boost=draft.item.manual_boost,
            )
        )
    return finalized


def today_completion_ratio(items: list[TodayItem]) -> float:
    if not items:
        return 0.0
    completed = sum(1 for item in items if item.completed)
    return completed / len(items)
