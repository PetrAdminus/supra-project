"""Загрузка конфигурации подсистемы аккаунтов из окружения."""
from __future__ import annotations

from dataclasses import dataclass
import os


@dataclass(frozen=True, slots=True)
class AccountsConfig:
    """Настройки подключения к базе данных аккаунтов."""

    database_url: str


_DEFAULT_DB_URL = "sqlite:///./supra_accounts.db"
_ENV_KEY = "SUPRA_ACCOUNTS_DB_URL"


def get_config_from_env(overrides: dict[str, str] | None = None) -> AccountsConfig:
    """Считывает конфигурацию, учитывая переопределения из API."""

    env = os.environ.copy()
    if overrides:
        env.update(overrides)

    database_url = env.get(_ENV_KEY, _DEFAULT_DB_URL).strip()
    if not database_url:
        raise ValueError("SUPRA_ACCOUNTS_DB_URL не может быть пустым")

    return AccountsConfig(database_url=database_url)


__all__ = ["AccountsConfig", "get_config_from_env"]
