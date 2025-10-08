import os
import tempfile
import unittest

try:  # pragma: no cover - отсутствия SQLAlchemy не мешает сборке
    import sqlalchemy  # type: ignore[unused-ignore]
except ImportError:  # pragma: no cover - используем skipIf
    sqlalchemy = None  # type: ignore[assignment]

if sqlalchemy is not None:  # pragma: no branch - упрощённое ветвление импортов
    from supra.scripts.accounts import get_config_from_env, init_engine, reset_engine
    from supra.scripts.accounts.db import get_session
    from supra.scripts.accounts.service import AccountsService, ProfileUpdate
else:  # pragma: no cover - сценарий без SQLAlchemy
    get_config_from_env = init_engine = reset_engine = None  # type: ignore[assignment]
    get_session = None  # type: ignore[assignment]
    AccountsService = ProfileUpdate = None  # type: ignore[assignment]


@unittest.skipIf(sqlalchemy is None, "sqlalchemy не установлена, тесты аккаунтов пропущены")
class AccountsServiceTests(unittest.TestCase):
    def setUp(self) -> None:
        assert get_config_from_env is not None
        assert init_engine is not None
        assert reset_engine is not None
        assert get_session is not None
        assert AccountsService is not None
        assert ProfileUpdate is not None
        self.tmp = tempfile.NamedTemporaryFile(suffix=".db")
        os.environ["SUPRA_ACCOUNTS_DB_URL"] = f"sqlite:///{self.tmp.name}"
        config = get_config_from_env()
        init_engine(config)

    def tearDown(self) -> None:
        reset_engine()
        self.tmp.close()

    def test_upsert_and_fetch_profile(self) -> None:
        with get_session() as session:
            service = AccountsService(session)
            account = service.upsert_account(
                "0xABCDEF",
                ProfileUpdate(nickname="Player", telegram="user", settings={"auto": True}),
            )
            session.commit()

        with get_session() as session:
            service = AccountsService(session)
            loaded = service.get_account("0xabcdef")

        self.assertIsNotNone(loaded)
        assert loaded is not None
        self.assertEqual(loaded.nickname, "Player")
        self.assertEqual(loaded.telegram, "user")
        self.assertEqual(loaded.address, "0xabcdef")
        self.assertEqual(loaded.settings.get("auto"), True)


if __name__ == "__main__":
    unittest.main()
