import os
import unittest

try:  # pragma: no cover - SQLAlchemy может отсутствовать в среде теста
    import sqlalchemy  # type: ignore[unused-ignore]
except ImportError:  # pragma: no cover - используем skipIf
    sqlalchemy = None  # type: ignore[assignment]

if sqlalchemy is not None:  # pragma: no cover - для mypy
    from supra.scripts.accounts.config import AccountsConfig
    from supra.scripts.accounts.db import init_engine, reset_engine
    from supra.scripts.progress import service
else:  # pragma: no cover - заглушки для статического анализа
    AccountsConfig = None  # type: ignore[assignment]
    init_engine = reset_engine = service = None  # type: ignore[assignment]


@unittest.skipIf(sqlalchemy is None, "sqlalchemy не установлена")
class ProgressServiceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.db_path = "test_progress.db"
        try:
            os.remove(self.db_path)
        except FileNotFoundError:
            pass
        init_engine(AccountsConfig(database_url=f"sqlite:///./{self.db_path}"))

    def tearDown(self) -> None:
        reset_engine()
        try:
            os.remove(self.db_path)
        except FileNotFoundError:
            pass

    def test_checklist_completion_roundtrip(self) -> None:
        service.upsert_checklist_task(
            {
                "code": "day1",
                "title": "День 1",
                "description": "Войти и ознакомиться",
                "day_index": 0,
                "reward_kind": "ticket",
                "reward_value": {"lottery_id": "jackpot"},
                "metadata": {"group": "daily"},
                "is_active": True,
            }
        )

        initial = service.get_checklist_for_address("0xABC")
        self.assertEqual(len(initial), 1)
        task, progress = initial[0]
        self.assertEqual(task.code, "day1")
        self.assertIsNone(progress)

        result = service.complete_checklist_task(
            "0xABC", "day1", metadata={"source": "test"}, reward_claimed=False
        )
        self.assertEqual(result.address, "0xabc")
        self.assertEqual(result.task.code, "day1")
        self.assertFalse(result.reward_claimed)
        self.assertEqual(result.metadata.get("source"), "test")

        after = service.get_checklist_for_address("0xabc")
        self.assertTrue(after[0][1].completed_at is not None)
        self.assertEqual(after[0][1].metadata["source"], "test")

    def test_achievement_unlock_roundtrip(self) -> None:
        service.upsert_achievement(
            {
                "code": "collector",
                "title": "Коллекционер",
                "description": "Куплено 10 билетов",
                "points": 50,
                "metadata": {"threshold": 10},
            }
        )

        listing = service.list_achievements_for_address("0xABC")
        self.assertEqual(len(listing), 1)
        achievement, progress = listing[0]
        self.assertEqual(achievement.code, "collector")
        self.assertIsNone(progress)

        unlocked = service.unlock_achievement(
            "0xabc", "collector", progress_value=10, metadata={"source": "unit"}
        )
        self.assertEqual(unlocked.address, "0xabc")
        self.assertEqual(unlocked.progress_value, 10)
        self.assertEqual(unlocked.metadata["source"], "unit")
        self.assertIsNotNone(unlocked.unlocked_at)

        after = service.list_achievements_for_address("0xabc")
        self.assertTrue(after[0][1].unlocked_at is not None)
        self.assertEqual(after[0][1].metadata["source"], "unit")


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
