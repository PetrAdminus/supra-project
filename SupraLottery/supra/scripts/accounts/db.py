"""Инициализация подключения к базе данных аккаунтов."""
from __future__ import annotations

from contextlib import contextmanager
from typing import Iterator

from sqlalchemy import create_engine
from sqlalchemy.engine import Engine
from sqlalchemy.orm import Session, sessionmaker

from .config import AccountsConfig
from .tables import Base

# Импортируем таблицы дополнительных подсистем (real-time, support), чтобы
# при инициализации создавались все структуры одной БД. Импорт выполнен
# здесь, чтобы избежать циклов в момент определения Base.
try:  # pragma: no cover - модули могут отсутствовать в урезанной среде
    from ..progress import tables as _progress_tables  # noqa: F401
    from ..realtime import tables as _realtime_tables  # noqa: F401
    from ..support import tables as _support_tables  # noqa: F401
except ImportError:  # pragma: no cover - модули не обязательны в минимальной среде
    _progress_tables = None  # type: ignore[assignment]
    _realtime_tables = None  # type: ignore[assignment]
    _support_tables = None  # type: ignore[assignment]

_ENGINE: Engine | None = None
_SESSION_FACTORY: sessionmaker[Session] | None = None


def init_engine(config: AccountsConfig) -> None:
    """Создаёт движок и проводит миграции (создание таблиц)."""

    global _ENGINE, _SESSION_FACTORY

    if _ENGINE is not None:
        _ENGINE.dispose()

    connect_args = {"check_same_thread": False} if config.database_url.startswith("sqlite") else {}
    engine = create_engine(config.database_url, future=True, connect_args=connect_args)
    Base.metadata.create_all(engine)

    _ENGINE = engine
    _SESSION_FACTORY = sessionmaker(engine, expire_on_commit=False, future=True)


@contextmanager
def get_session() -> Iterator[Session]:
    """Возвращает сессию SQLAlchemy для работы с профилями."""

    if _SESSION_FACTORY is None:
        raise RuntimeError("Движок аккаунтов не инициализирован")

    session = _SESSION_FACTORY()
    try:
        yield session
    finally:
        session.close()


def reset_engine() -> None:
    """Сбрасывает движок (используется в тестах)."""

    global _ENGINE, _SESSION_FACTORY
    if _ENGINE is not None:
        _ENGINE.dispose()
    _ENGINE = None
    _SESSION_FACTORY = None


__all__ = ["init_engine", "get_session", "reset_engine"]
