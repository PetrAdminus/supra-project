"""Тесты подсистемы поддержки пользователей."""
from __future__ import annotations

import os
import unittest
from unittest import mock

try:  # pragma: no cover - SQLAlchemy может отсутствовать в минимальной среде
    import sqlalchemy  # type: ignore[unused-ignore]
except ImportError:  # pragma: no cover - используем skipIf
    sqlalchemy = None  # type: ignore[assignment]


@unittest.skipIf(sqlalchemy is None, "sqlalchemy не установлена")
class SupportServiceTests(unittest.TestCase):
    def setUp(self) -> None:
        patcher = mock.patch.dict(
            os.environ,
            {
                "SUPRA_ACCOUNTS_DB_URL": "sqlite:///./test_support.db",
            },
            clear=True,
        )
        patcher.start()
        self.addCleanup(patcher.stop)

        from supra.scripts.accounts import get_config_from_env, init_engine, reset_engine
        from supra.scripts.support import service

        self.service = service
        config = get_config_from_env()
        init_engine(config)
        self.addCleanup(reset_engine)

    def tearDown(self) -> None:
        try:
            os.remove("test_support.db")
        except FileNotFoundError:
            pass

    def test_article_roundtrip(self) -> None:
        created = self.service.create_or_update_article(
            {
                "slug": "faq-wallet",
                "title": "Как подключить кошелёк",
                "body": "Инструкция по подключению",
                "locale": "ru",
            }
        )
        self.assertEqual(created.slug, "faq-wallet")

        fetched = self.service.get_article_by_slug("faq-wallet")
        self.assertIsNotNone(fetched)
        assert fetched is not None
        self.assertEqual(fetched.title, "Как подключить кошелёк")

        listing = self.service.list_articles(locale="ru")
        self.assertEqual(len(listing), 1)
        self.assertEqual(listing[0].slug, "faq-wallet")

    def test_ticket_creation(self) -> None:
        ticket = self.service.create_ticket(
            {
                "address": "0xABC",
                "email": "user@example.com",
                "subject": "Проблема с билетом",
                "body": "Не пришло подтверждение",
                "metadata": {"lottery_id": "1"},
            }
        )
        self.assertGreater(ticket.id, 0)
        self.assertEqual(ticket.address, "0xabc")
        self.assertEqual(ticket.status, "new")
