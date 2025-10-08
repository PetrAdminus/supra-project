import importlib
import os
import unittest
from unittest import mock

try:
    from fastapi.testclient import TestClient
except ImportError:  # pragma: no cover - FastAPI optional for some environments
    TestClient = None  # type: ignore[assignment]

try:  # pragma: no cover - SQLAlchemy может отсутствовать в минимальной среде
    import sqlalchemy  # type: ignore[unused-ignore]
except ImportError:  # pragma: no cover - используем skipIf
    sqlalchemy = None  # type: ignore[assignment]

if sqlalchemy is None:  # pragma: no cover - для mypy и статических анализаторов
    api_server_module = None  # type: ignore[assignment]


@unittest.skipIf(TestClient is None, "fastapi is not installed")
@unittest.skipIf(sqlalchemy is None, "sqlalchemy не установлена")
class ApiServerStatusTests(unittest.TestCase):
    def setUp(self) -> None:
        self.env_patch = mock.patch.dict(
            os.environ,
            {
                "PROFILE": "test_profile",
                "LOTTERY_ADDR": "0x1",
                "DEPOSIT_ADDR": "0x2",
                "CLIENT_ADDR": "0x3",
                "MAX_GAS_PRICE": "1",
                "MAX_GAS_LIMIT": "1",
                "VERIFICATION_GAS_VALUE": "1",
                "SUPRA_API_CACHE_TTL": "60",
                "SUPRA_API_CORS_ORIGINS": "http://localhost:5173",
                "SUPRA_ACCOUNTS_DB_URL": "sqlite:///./test_api_accounts.db",
            },
            clear=True,
        )
        self.env_patch.start()
        from supra.scripts import api_server as api_server_module

        self.module = importlib.reload(api_server_module)

    def tearDown(self) -> None:
        try:
            os.remove("test_api_accounts.db")
        except FileNotFoundError:
            pass
        self.env_patch.stop()

    def _fake_gather(self):
        counter = {"value": 0}

        def _inner(config):  # type: ignore[no-untyped-def]
            counter["value"] += 1
            return {"counter": counter["value"], "config": config.lottery_addr}

        return counter, _inner

    def test_status_cache_and_refresh_parameter(self) -> None:
        counter, gather = self._fake_gather()
        with mock.patch.object(self.module, "gather_data", side_effect=gather):
            with TestClient(self.module.app) as client:
                first = client.get("/status")
                self.assertEqual(first.status_code, 200)
                self.assertEqual(first.json()["counter"], 1)

                second = client.get("/status")
                self.assertEqual(second.json()["counter"], 1)
                self.assertEqual(counter["value"], 1)

                refreshed = client.get("/status?refresh=true")
                self.assertEqual(refreshed.json()["counter"], 2)
                self.assertEqual(counter["value"], 2)

    def test_overrides_disable_cache(self) -> None:
        counter, gather = self._fake_gather()
        with mock.patch.object(self.module, "gather_data", side_effect=gather):
            with TestClient(self.module.app) as client:
                baseline = client.get("/status")
                self.assertEqual(baseline.json()["config"], "0x1")
                self.assertEqual(counter["value"], 1)

                override = client.get("/status", params={"lottery_addr": "0xabc"})
                self.assertEqual(override.json()["config"], "0xabc")
                self.assertEqual(counter["value"], 2)

    def test_cors_headers_present(self) -> None:
        counter, gather = self._fake_gather()
        with mock.patch.object(self.module, "gather_data", side_effect=gather):
            with TestClient(self.module.app) as client:
                response = client.options(
                    "/status",
                    headers={
                        "Origin": "http://localhost:5173",
                        "Access-Control-Request-Method": "GET",
                    },
                )
                self.assertEqual(response.status_code, 200)
                self.assertEqual(
                    response.headers.get("access-control-allow-origin"),
                    "http://localhost:5173",
                )

    def test_vrf_log_endpoint_invokes_gather(self) -> None:
        with mock.patch.object(self.module, "gather_vrf_log", return_value={"lottery_id": 5}) as gather:
            with TestClient(self.module.app) as client:
                response = client.get("/lotteries/5/vrf-log")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["lottery_id"], 5)
        gather.assert_called_once()

    def test_chat_rest_roundtrip(self) -> None:
        with TestClient(self.module.app) as client:
            empty = client.get("/chat/messages")
            self.assertEqual(empty.status_code, 200)
            self.assertEqual(empty.json(), [])

            created = client.post(
                "/chat/messages",
                json={
                    "address": "0xABC",
                    "body": "Привет всем!",
                    "room": "global",
                    "metadata": {"lottery": "1"},
                },
            )
            self.assertEqual(created.status_code, 201)
            self.assertEqual(created.json()["sender_address"], "0xabc")

            messages = client.get("/chat/messages")
            self.assertEqual(len(messages.json()), 1)
            self.assertEqual(messages.json()[0]["body"], "Привет всем!")

            announcement = client.post(
                "/chat/announcements",
                json={
                    "title": "Новая лотерея",
                    "body": "Запуск через час",
                    "lottery_id": "2",
                },
            )
            self.assertEqual(announcement.status_code, 201)

            ann_list = client.get("/chat/announcements", params={"lottery_id": "2"})
            self.assertEqual(len(ann_list.json()), 1)
            self.assertEqual(ann_list.json()[0]["title"], "Новая лотерея")

    def test_websocket_receives_broadcast(self) -> None:
        with TestClient(self.module.app) as client:
            with client.websocket_connect("/chat/ws/global") as websocket:
                response = client.post(
                    "/chat/messages",
                    json={"address": "0xDEF", "body": "Вебсокет", "room": "global"},
                )
                self.assertEqual(response.status_code, 201)
                payload = websocket.receive_json()
                self.assertEqual(payload["body"], "Вебсокет")

    def test_commands_list_returns_sorted_metadata(self) -> None:
        fake_commands = [
            ("beta", "supra.beta", "Beta command"),
            ("alpha", "supra.alpha", "Alpha command"),
        ]

        with mock.patch.object(self.module.cli, "iter_commands", return_value=fake_commands):
            with TestClient(self.module.app) as client:
                response = client.get("/commands")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.json(),
            [
                {"name": "alpha", "module": "supra.alpha", "description": "Alpha command"},
                {"name": "beta", "module": "supra.beta", "description": "Beta command"},
            ],
        )

    def test_accounts_profile_roundtrip(self) -> None:
        with TestClient(self.module.app) as client:
            payload = {
                "nickname": "Игрок",
                "avatar": {"kind": "external", "value": "https://example.com/avatar.png"},
                "telegram": "lotto_player",
                "settings": {"auto_buy": True},
            }

            created = client.put("/accounts/0xABC", json=payload)
            self.assertEqual(created.status_code, 200)
            self.assertEqual(created.json()["address"], "0xabc")
            self.assertEqual(created.json()["nickname"], "Игрок")

            fetched = client.get("/accounts/0xabc")
            self.assertEqual(fetched.status_code, 200)
            body = fetched.json()
            self.assertEqual(body["telegram"], "lotto_player")
            self.assertEqual(body["settings"], {"auto_buy": True})

    def test_progress_checklist_and_achievements(self) -> None:
        with TestClient(self.module.app) as client:
            task_payload = {
                "title": "День 1",
                "description": "Ознакомьтесь с правилами",
                "day_index": 0,
                "reward_kind": "ticket",
                "reward_value": {"lottery_id": "jackpot"},
                "metadata": {"group": "daily"},
                "is_active": True,
            }
            created_task = client.put("/progress/checklist/day1", json=task_payload)
            self.assertEqual(created_task.status_code, 200)

            checklist = client.get("/progress/0xABC/checklist")
            self.assertEqual(checklist.status_code, 200)
            self.assertEqual(len(checklist.json()["tasks"]), 1)
            self.assertFalse(checklist.json()["tasks"][0]["completed"])

            completion = client.post(
                "/progress/0xabc/checklist/day1/complete",
                json={"metadata": {"source": "api"}},
            )
            self.assertEqual(completion.status_code, 201)
            self.assertTrue(completion.json()["completed"])

            achievement_payload = {
                "title": "Коллекционер",
                "description": "Купите 10 билетов",
                "points": 10,
                "metadata": {"threshold": 10},
                "is_active": True,
            }
            achievement = client.put("/progress/achievements/collector", json=achievement_payload)
            self.assertEqual(achievement.status_code, 200)

            unlocked = client.post(
                "/progress/0xabc/achievements/collector/unlock",
                json={"progress_value": 10},
            )
            self.assertEqual(unlocked.status_code, 201)
            self.assertTrue(unlocked.json()["unlocked"])

            achievements = client.get("/progress/0xabc/achievements")
            self.assertEqual(achievements.status_code, 200)
            self.assertTrue(achievements.json()["achievements"][0]["unlocked"])

    def test_support_articles_and_tickets(self) -> None:
        with TestClient(self.module.app) as client:
            upsert = client.put(
                "/support/articles/faq-wallet",
                json={
                    "slug": "faq-wallet",
                    "title": "Как подключить кошелёк",
                    "body": "Инструкция",
                    "locale": "ru",
                    "tags": {"category": "wallet"},
                },
            )
            self.assertEqual(upsert.status_code, 200)
            self.assertEqual(upsert.json()["slug"], "faq-wallet")

            listing = client.get("/support/articles", params={"locale": "ru"})
            self.assertEqual(listing.status_code, 200)
            self.assertEqual(listing.json()["articles"][0]["title"], "Как подключить кошелёк")

            fetched = client.get("/support/articles/faq-wallet")
            self.assertEqual(fetched.status_code, 200)

            ticket = client.post(
                "/support/tickets",
                json={
                    "address": "0xABC",
                    "email": "user@example.com",
                    "subject": "Помощь",
                    "body": "Нужна помощь",
                },
            )
            self.assertEqual(ticket.status_code, 201)
            self.assertEqual(ticket.json()["status"], "new")


if __name__ == "__main__":
    unittest.main()
