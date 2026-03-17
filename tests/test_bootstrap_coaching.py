from datetime import date
import unittest

from one.bootstrap import create_onboarding_bundle
from one.coaching import select_active_coach_cards
from one.models import CoachCard


class BootstrapAndCoachingTests(unittest.TestCase):
    def test_onboarding_bundle_includes_default_categories(self) -> None:
        bundle = create_onboarding_bundle(
            user_id="u1",
            email="user@example.com",
            display_name="One User",
            timezone="America/Guatemala",
        )

        self.assertEqual(bundle.user.timezone, "America/Guatemala")
        self.assertEqual(
            [category.name for category in bundle.categories],
            ["Gym", "School", "Personal Projects", "Wellbeing", "Life Admin"],
        )
        self.assertEqual(bundle.preferences.default_tab, "today")

    def test_coach_card_selection_filters_by_date_and_tags(self) -> None:
        cards = [
            CoachCard(
                id="c1",
                title="Stay consistent",
                body="Small wins compound.",
                tags=["gym"],
                active_from=date(2026, 3, 1),
                active_to=date(2026, 3, 31),
            ),
            CoachCard(
                id="c2",
                title="School focus",
                body="Deep work block.",
                tags=["school"],
                active_from=date(2026, 3, 1),
                active_to=date(2026, 3, 31),
            ),
            CoachCard(
                id="c3",
                title="Expired",
                body="Old card.",
                tags=["gym"],
                active_from=date(2026, 2, 1),
                active_to=date(2026, 2, 28),
            ),
        ]

        selected = select_active_coach_cards(
            cards=cards,
            target_date=date(2026, 3, 11),
            tags={"gym"},
            limit=3,
        )

        self.assertEqual([card.id for card in selected], ["c1"])


if __name__ == "__main__":
    unittest.main()
