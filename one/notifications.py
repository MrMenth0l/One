from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime, time
from zoneinfo import ZoneInfo

from .models import Reminder, UserPreferences


@dataclass(slots=True)
class DueReminder:
    reminder_id: str
    item_type: str
    item_id: str
    trigger_at: datetime


def _in_quiet_hours(current: time, start: time | None, end: time | None) -> bool:
    if start is None or end is None:
        return False

    if start < end:
        return start <= current < end
    # Overnight quiet range, e.g. 22:00 -> 07:00
    return current >= start or current < end


def due_reminders(
    *,
    reminders: list[Reminder],
    now_utc: datetime,
    preferences: UserPreferences,
) -> list[DueReminder]:
    due: list[DueReminder] = []

    for reminder in reminders:
        if not reminder.is_enabled:
            continue
        if reminder.user_id != preferences.user_id:
            continue

        tz = ZoneInfo(reminder.timezone)
        now_local = now_utc.replace(tzinfo=UTC).astimezone(tz)
        if _in_quiet_hours(
            now_local.time(), preferences.quiet_hours_start, preferences.quiet_hours_end
        ):
            continue

        trigger = reminder.trigger_local_time
        if now_local.hour == trigger.hour and now_local.minute == trigger.minute:
            due.append(
                DueReminder(
                    reminder_id=reminder.id,
                    item_type=reminder.item_type.value,
                    item_id=reminder.item_id,
                    trigger_at=now_local,
                )
            )

    return due


def group_close_reminders(
    due: list[DueReminder],
    *,
    window_minutes: int = 10,
) -> list[list[DueReminder]]:
    if not due:
        return []

    due_sorted = sorted(due, key=lambda x: x.trigger_at)
    groups: list[list[DueReminder]] = [[due_sorted[0]]]

    for candidate in due_sorted[1:]:
        previous = groups[-1][-1]
        delta_minutes = (candidate.trigger_at - previous.trigger_at).total_seconds() / 60
        if delta_minutes <= window_minutes:
            groups[-1].append(candidate)
        else:
            groups.append([candidate])

    return groups
