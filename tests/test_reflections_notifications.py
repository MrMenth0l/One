from datetime import datetime, time, date
import unittest

from one.models import ItemType, PeriodType, ReflectionNote, ReflectionSentiment, Reminder, UserPreferences
from one.notifications import due_reminders, group_close_reminders
from one.reflections import delete_reflection, reflection_prompt, search_reflections, upsert_reflection


class ReflectionAndNotificationTests(unittest.TestCase):
    def test_reflection_prompts_and_append(self) -> None:
        notes: list[ReflectionNote] = []
        first = ReflectionNote(
            id="r1",
            user_id="u1",
            period_type=PeriodType.DAILY,
            period_start=date(2026, 3, 11),
            period_end=date(2026, 3, 11),
            content="Gym done, school delayed.",
            sentiment=ReflectionSentiment.FOCUSED,
            tags=["gym", "school"],
        )
        upsert_reflection(notes, first)

        updated = ReflectionNote(
            id="r2",
            user_id="u1",
            period_type=PeriodType.DAILY,
            period_start=date(2026, 3, 11),
            period_end=date(2026, 3, 11),
            content="Gym done, school recovered in evening.",
            sentiment=ReflectionSentiment.GREAT,
            tags=["gym", "school", "recovery"],
        )
        upsert_reflection(notes, updated)

        self.assertEqual(len(notes), 2)
        self.assertIn("worked", reflection_prompt(PeriodType.DAILY).lower())
        found = search_reflections(notes=notes, user_id="u1", query="recovery")
        self.assertEqual(found[0].content, "Gym done, school recovered in evening.")
        self.assertEqual(found[0].sentiment, ReflectionSentiment.GREAT)

        deleted = delete_reflection(notes=notes, user_id="u1", reflection_id="r1")
        self.assertTrue(deleted)
        self.assertEqual(len(notes), 1)

    def test_reminders_respect_quiet_hours_and_grouping(self) -> None:
        prefs = UserPreferences(
            id="p1",
            user_id="u1",
            quiet_hours_start=time(22, 0),
            quiet_hours_end=time(7, 0),
        )
        reminders = [
            Reminder(
                id="rm1",
                user_id="u1",
                item_type=ItemType.HABIT,
                item_id="h1",
                trigger_local_time=time(6, 30),
                timezone="America/Guatemala",
                repeat_pattern="DAILY",
            ),
            Reminder(
                id="rm2",
                user_id="u1",
                item_type=ItemType.TODO,
                item_id="t1",
                trigger_local_time=time(8, 0),
                timezone="America/Guatemala",
                repeat_pattern="ONCE",
            ),
            Reminder(
                id="rm3",
                user_id="u1",
                item_type=ItemType.TODO,
                item_id="t2",
                trigger_local_time=time(8, 5),
                timezone="America/Guatemala",
                repeat_pattern="ONCE",
            ),
        ]

        # 2026-03-11 14:00 UTC == 08:00 America/Guatemala
        due = due_reminders(
            reminders=reminders,
            now_utc=datetime(2026, 3, 11, 14, 0),
            preferences=prefs,
        )
        self.assertEqual([r.reminder_id for r in due], ["rm2"])

        # 2026-03-11 14:05 UTC == 08:05 America/Guatemala
        due_2 = due_reminders(
            reminders=reminders,
            now_utc=datetime(2026, 3, 11, 14, 5),
            preferences=prefs,
        )
        groups = group_close_reminders(due + due_2, window_minutes=10)
        self.assertEqual(len(groups), 1)
        self.assertEqual([r.reminder_id for r in groups[0]], ["rm2", "rm3"])


if __name__ == "__main__":
    unittest.main()
