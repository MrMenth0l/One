from __future__ import annotations

import os
from datetime import date, datetime, timedelta
from pathlib import Path
import unittest

from fastapi.testclient import TestClient
import yaml

# Configure backend settings before importing app modules.
os.environ["DATABASE_URL"] = "sqlite+pysqlite:///./test_one_api.db"
os.environ["DEV_AUTH_SECRET"] = "test-secret"

from one_api.auth.dependencies import get_auth_provider
from one_api.config import get_settings
from one_api.db.base import Base
from one_api.db import models
from one_api.db.session import SessionLocal, engine
from one_api.main import app


class BackendAPITests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        get_settings.cache_clear()
        try:
            Path("test_one_api.db").unlink()
        except FileNotFoundError:
            pass
        Base.metadata.create_all(bind=engine)
        cls.client = TestClient(app)

    @classmethod
    def tearDownClass(cls) -> None:
        cls.client.close()
        Base.metadata.drop_all(bind=engine)
        try:
            Path("test_one_api.db").unlink()
        except FileNotFoundError:
            pass

    def _signup(self, email: str = "one@example.com") -> tuple[str, dict]:
        resp = self.client.post(
            "/auth/signup",
            json={
                "email": email,
                "password": "password123",
                "display_name": "One User",
                "timezone": "America/Guatemala",
            },
        )
        self.assertEqual(resp.status_code, 201, resp.text)
        data = resp.json()
        token = data["access_token"]
        return token, data

    def _headers(self, token: str) -> dict[str, str]:
        return {"Authorization": f"Bearer {token}"}

    def test_signup_bootstrap_and_today_flow(self) -> None:
        token, session = self._signup(email="flow@example.com")
        me_resp = self.client.get("/users/me", headers=self._headers(token))
        self.assertEqual(me_resp.status_code, 200, me_resp.text)
        self.assertEqual(me_resp.json()["id"], session["user"]["id"])

        cat_resp = self.client.get("/categories", headers=self._headers(token))
        self.assertEqual(cat_resp.status_code, 200)
        categories = cat_resp.json()
        self.assertGreaterEqual(len(categories), 5)
        gym_category = categories[0]["id"]

        habit_resp = self.client.post(
            "/habits",
            headers=self._headers(token),
            json={
                "category_id": gym_category,
                "title": "Workout",
                "recurrence_rule": "DAILY",
                "priority_weight": 80,
            },
        )
        self.assertEqual(habit_resp.status_code, 201, habit_resp.text)
        habit_id = habit_resp.json()["id"]

        due_at = datetime.now().replace(microsecond=0).isoformat() + "Z"
        todo_resp = self.client.post(
            "/todos",
            headers=self._headers(token),
            json={
                "category_id": gym_category,
                "title": "Submit assignment",
                "priority": 90,
                "is_pinned": True,
                "due_at": due_at,
            },
        )
        self.assertEqual(todo_resp.status_code, 201, todo_resp.text)
        todo_id = todo_resp.json()["id"]

        today_resp = self.client.get("/today", headers=self._headers(token), params={"date": date.today().isoformat()})
        self.assertEqual(today_resp.status_code, 200, today_resp.text)
        today = today_resp.json()
        self.assertEqual(today["items"][0]["item_id"], todo_id)
        self.assertEqual(today["items"][0]["item_type"], "todo")

        completion_resp = self.client.post(
            "/completions",
            headers=self._headers(token),
            json={
                "item_type": "habit",
                "item_id": habit_id,
                "date_local": date.today().isoformat(),
                "state": "completed",
                "source": "test",
            },
        )
        self.assertEqual(completion_resp.status_code, 200, completion_resp.text)

        today_after = self.client.get("/today", headers=self._headers(token), params={"date": date.today().isoformat()}).json()
        self.assertGreaterEqual(today_after["completed_count"], 1)
        self.assertGreaterEqual(today_after["completion_ratio"], 0)
        self.assertLessEqual(today_after["completion_ratio"], 1)

    def test_analytics_period_and_preferences(self) -> None:
        token, _ = self._signup(email="analytics@example.com")
        headers = self._headers(token)

        pref_resp = self.client.get("/preferences", headers=headers)
        self.assertEqual(pref_resp.status_code, 200)

        patch_pref = self.client.patch(
            "/preferences",
            headers=headers,
            json={
                "quiet_hours_start": "22:00:00",
                "quiet_hours_end": "07:00:00",
                "coach_enabled": False,
            },
        )
        self.assertEqual(patch_pref.status_code, 200, patch_pref.text)

        anchor = date.today().isoformat()
        period_resp = self.client.get(
            "/analytics/period",
            headers=headers,
            params={"anchor_date": anchor, "period_type": "weekly"},
        )
        self.assertEqual(period_resp.status_code, 200, period_resp.text)
        self.assertIn("consistency_score", period_resp.json())

    def test_reflections_append_and_coach_cards_expose_verse_text(self) -> None:
        token, session = self._signup(email="coach-reflections@example.com")
        headers = self._headers(token)
        today = date.today().isoformat()

        first_reflection = self.client.post(
            "/reflections",
            headers=headers,
            json={
                "period_type": "daily",
                "period_start": today,
                "period_end": today,
                "content": "First quick note",
                "sentiment": "focused",
            },
        )
        self.assertEqual(first_reflection.status_code, 201, first_reflection.text)
        self.assertEqual(first_reflection.json()["sentiment"], "focused")

        second_reflection = self.client.post(
            "/reflections",
            headers=headers,
            json={
                "period_type": "daily",
                "period_start": today,
                "period_end": today,
                "content": "Second quick note",
                "sentiment": "great",
            },
        )
        self.assertEqual(second_reflection.status_code, 201, second_reflection.text)
        self.assertEqual(second_reflection.json()["sentiment"], "great")

        reflection_list = self.client.get("/reflections", headers=headers, params={"period_type": "daily"})
        self.assertEqual(reflection_list.status_code, 200, reflection_list.text)
        reflection_payload = reflection_list.json()
        self.assertEqual(len(reflection_payload), 2)
        self.assertEqual(reflection_payload[0]["content"], "Second quick note")
        self.assertEqual(reflection_payload[0]["sentiment"], "great")

        delete_resp = self.client.delete(f"/reflections/{second_reflection.json()['id']}", headers=headers)
        self.assertEqual(delete_resp.status_code, 204, delete_resp.text)

        reflection_list_after_delete = self.client.get("/reflections", headers=headers, params={"period_type": "daily"})
        self.assertEqual(reflection_list_after_delete.status_code, 200, reflection_list_after_delete.text)
        reflection_payload_after_delete = reflection_list_after_delete.json()
        self.assertEqual(len(reflection_payload_after_delete), 1)
        self.assertEqual(reflection_payload_after_delete[0]["content"], "First quick note")

        with SessionLocal() as db:
            db.add(
                models.CoachCardModel(
                    id="coach-api-1",
                    title="Commit the work",
                    body="Keep the next action clear.",
                    verse_ref="Proverbs 16:3",
                    verse_text="Commit to the Lord whatever you do, and he will establish your plans.",
                    locale="en",
                    is_active=True,
                )
            )
            db.commit()

        cards_resp = self.client.get("/coach-cards", headers=headers)
        self.assertEqual(cards_resp.status_code, 200, cards_resp.text)
        cards = cards_resp.json()
        self.assertTrue(cards)
        matching = next(card for card in cards if card["id"] == "coach-api-1")
        self.assertEqual(matching["verse_text"], "Commit to the Lord whatever you do, and he will establish your plans.")
        self.assertEqual(matching["verse_ref"], "Proverbs 16:3")

    def test_today_order_override_persists_for_date(self) -> None:
        token, _ = self._signup(email="order@example.com")
        headers = self._headers(token)
        category_id = self.client.get("/categories", headers=headers).json()[0]["id"]
        today = date.today().isoformat()

        habit_resp = self.client.post(
            "/habits",
            headers=headers,
            json={
                "category_id": category_id,
                "title": "Read",
                "recurrence_rule": "DAILY",
                "priority_weight": 65,
            },
        )
        self.assertEqual(habit_resp.status_code, 201, habit_resp.text)
        habit_id = habit_resp.json()["id"]

        todo_resp = self.client.post(
            "/todos",
            headers=headers,
            json={
                "category_id": category_id,
                "title": "Submit report",
                "is_pinned": True,
                "priority": 90,
            },
        )
        self.assertEqual(todo_resp.status_code, 201, todo_resp.text)
        todo_id = todo_resp.json()["id"]

        first_today = self.client.get("/today", headers=headers, params={"date": today})
        self.assertEqual(first_today.status_code, 200, first_today.text)
        self.assertEqual(first_today.json()["items"][0]["item_id"], todo_id)

        order_write = self.client.put(
            "/today/order",
            headers=headers,
            json={
                "date_local": today,
                "items": [
                    {"item_type": "habit", "item_id": habit_id, "order_index": 0},
                    {"item_type": "todo", "item_id": todo_id, "order_index": 1},
                ],
            },
        )
        self.assertEqual(order_write.status_code, 200, order_write.text)
        self.assertEqual(order_write.json()["items"][0]["item_id"], habit_id)

        second_today = self.client.get("/today", headers=headers, params={"date": today})
        self.assertEqual(second_today.status_code, 200, second_today.text)
        self.assertEqual(second_today.json()["items"][0]["item_id"], habit_id)

    def test_habit_stats_returns_window_and_streak(self) -> None:
        token, _ = self._signup(email="habitstats@example.com")
        headers = self._headers(token)
        category_id = self.client.get("/categories", headers=headers).json()[0]["id"]
        today = date.today().isoformat()

        habit_resp = self.client.post(
            "/habits",
            headers=headers,
            json={
                "category_id": category_id,
                "title": "Workout",
                "recurrence_rule": "DAILY",
                "priority_weight": 80,
            },
        )
        self.assertEqual(habit_resp.status_code, 201, habit_resp.text)
        habit_id = habit_resp.json()["id"]

        completion_resp = self.client.post(
            "/completions",
            headers=headers,
            json={
                "item_type": "habit",
                "item_id": habit_id,
                "date_local": today,
                "state": "completed",
                "source": "test",
            },
        )
        self.assertEqual(completion_resp.status_code, 200, completion_resp.text)

        stats_resp = self.client.get(
            f"/habits/{habit_id}/stats",
            headers=headers,
            params={"anchor_date": today, "window_days": 30},
        )
        self.assertEqual(stats_resp.status_code, 200, stats_resp.text)
        stats = stats_resp.json()
        self.assertEqual(stats["habit_id"], habit_id)
        self.assertGreaterEqual(stats["streak_current"], 1)
        self.assertGreaterEqual(stats["completed_window"], 1)
        self.assertGreaterEqual(stats["expected_window"], stats["completed_window"])
        self.assertLessEqual(stats["completion_rate_window"], 1)
        self.assertIn("last_completed_date", stats)

    def test_weekly_period_matches_daily_rollup_window(self) -> None:
        token, _ = self._signup(email="rollup@example.com")
        headers = self._headers(token)
        category_id = self.client.get("/categories", headers=headers).json()[0]["id"]
        today = date.today()

        self.client.patch(
            "/preferences",
            headers=headers,
            json={"week_start": today.weekday()},
        )

        habit_resp = self.client.post(
            "/habits",
            headers=headers,
            json={
                "category_id": category_id,
                "title": "Read",
                "recurrence_rule": "DAILY",
                "priority_weight": 60,
            },
        )
        self.assertEqual(habit_resp.status_code, 201, habit_resp.text)
        habit_id = habit_resp.json()["id"]

        completion_resp = self.client.post(
            "/completions",
            headers=headers,
            json={
                "item_type": "habit",
                "item_id": habit_id,
                "date_local": today.isoformat(),
                "state": "completed",
                "source": "test",
            },
        )
        self.assertEqual(completion_resp.status_code, 200, completion_resp.text)

        period_resp = self.client.get(
            "/analytics/period",
            headers=headers,
            params={"anchor_date": today.isoformat(), "period_type": "weekly"},
        )
        self.assertEqual(period_resp.status_code, 200, period_resp.text)
        period = period_resp.json()

        daily_resp = self.client.get(
            "/analytics/daily",
            headers=headers,
            params={
                "start_date": period["period_start"],
                "end_date": period["period_end"],
            },
        )
        self.assertEqual(daily_resp.status_code, 200, daily_resp.text)
        daily = daily_resp.json()

        self.assertEqual(sum(row["completed_items"] for row in daily), period["completed_items"])
        self.assertEqual(sum(row["expected_items"] for row in daily), period["expected_items"])
        self.assertAlmostEqual(
            period["completion_rate"],
            (period["completed_items"] / period["expected_items"]) if period["expected_items"] else 0.0,
        )

    def test_server_timestamp_wins_on_todo_patch(self) -> None:
        token, _ = self._signup(email="conflict@example.com")
        headers = self._headers(token)
        category_id = self.client.get("/categories", headers=headers).json()[0]["id"]

        todo_resp = self.client.post(
            "/todos",
            headers=headers,
            json={"category_id": category_id, "title": "Server Title"},
        )
        self.assertEqual(todo_resp.status_code, 201)
        todo = todo_resp.json()

        server_updated_at = todo["updated_at"]
        stale = (datetime.fromisoformat(server_updated_at.replace("Z", "+00:00")) - timedelta(minutes=10)).isoformat()

        patch_resp = self.client.patch(
            f"/todos/{todo['id']}",
            headers={**headers, "x-client-updated-at": stale},
            json={"title": "Stale Client Title"},
        )
        self.assertEqual(patch_resp.status_code, 200, patch_resp.text)
        self.assertEqual(patch_resp.json()["title"], "Server Title")

    def test_openapi_contract_contains_today_endpoint(self) -> None:
        spec_path = Path("api/openapi.yaml")
        spec = yaml.safe_load(spec_path.read_text())
        self.assertIn("/today", spec["paths"])
        self.assertIn("/today/order", spec["paths"])
        self.assertIn("/habits/{habit_id}/stats", spec["paths"])
        self.assertIn("/reflections/{reflection_id}", spec["paths"])
        self.assertIn("TodayResponse", spec["components"]["schemas"])
        coach_schema = spec["components"]["schemas"]["CoachCardResponse"]
        self.assertIn("verse_text", coach_schema["properties"])
        reflection_write_schema = spec["components"]["schemas"]["ReflectionWriteRequest"]
        self.assertIn("sentiment", reflection_write_schema["properties"])

    def test_mvp_contract_shapes_for_vertical_slice(self) -> None:
        token, session = self._signup(email="shape@example.com")
        self.assertIn("access_token", session)
        self.assertIn("refresh_token", session)
        self.assertIn("expires_in", session)
        headers = self._headers(token)

        me = self.client.get("/users/me", headers=headers)
        self.assertEqual(me.status_code, 200, me.text)
        self.assertIn("display_name", me.json())

        categories = self.client.get("/categories", headers=headers)
        self.assertEqual(categories.status_code, 200, categories.text)
        first_category = categories.json()[0]
        self.assertIn("name", first_category)
        self.assertIn("sort_order", first_category)

        habit = self.client.post(
            "/habits",
            headers=headers,
            json={
                "category_id": first_category["id"],
                "title": "Lift",
                "recurrence_rule": "DAILY",
            },
        )
        self.assertEqual(habit.status_code, 201, habit.text)
        self.assertIn("recurrence_rule", habit.json())

        todo = self.client.post(
            "/todos",
            headers=headers,
            json={
                "category_id": first_category["id"],
                "title": "Read notes",
            },
        )
        self.assertEqual(todo.status_code, 201, todo.text)
        self.assertIn("status", todo.json())

        completion = self.client.post(
            "/completions",
            headers=headers,
            json={
                "item_type": "habit",
                "item_id": habit.json()["id"],
                "date_local": date.today().isoformat(),
                "state": "completed",
                "source": "test",
            },
        )
        self.assertEqual(completion.status_code, 200, completion.text)
        self.assertIn("state", completion.json())

        today = self.client.get("/today", headers=headers, params={"date": date.today().isoformat()})
        self.assertEqual(today.status_code, 200, today.text)
        self.assertIn("items", today.json())
        self.assertIn("completion_ratio", today.json())

        period = self.client.get(
            "/analytics/period",
            headers=headers,
            params={"anchor_date": date.today().isoformat(), "period_type": "weekly"},
        )
        self.assertEqual(period.status_code, 200, period.text)
        self.assertIn("period_start", period.json())

        preferences = self.client.patch(
            "/preferences",
            headers=headers,
            json={"quiet_hours_start": "22:00:00", "quiet_hours_end": "07:00:00"},
        )
        self.assertEqual(preferences.status_code, 200, preferences.text)
        self.assertIn("notification_flags", preferences.json())


if __name__ == "__main__":
    unittest.main()
