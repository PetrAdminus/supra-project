import importlib
import os
import unittest
from unittest import mock

try:
    from fastapi.testclient import TestClient
except ImportError:  # pragma: no cover - FastAPI optional for some environments
    TestClient = None  # type: ignore[assignment]


@unittest.skipIf(TestClient is None, "fastapi is not installed")
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
            },
            clear=True,
        )
        self.env_patch.start()
        from supra.scripts import api_server as api_server_module

        self.module = importlib.reload(api_server_module)

    def tearDown(self) -> None:
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


if __name__ == "__main__":
    unittest.main()
