"""FastAPI-маршруты для работы с аккаунтами."""
from __future__ import annotations

from typing import Iterator

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from .config import get_config_from_env
from .db import get_session, init_engine
from .schemas import AccountProfile, AccountProfileUpdate, AvatarPayload
from .service import AccountsService, AvatarUpdate, ProfileUpdate

router = APIRouter(prefix="/accounts", tags=["accounts"])


def _ensure_engine() -> None:
    try:
        with get_session():
            return
    except RuntimeError:
        config = get_config_from_env()
        init_engine(config)


def _session_dependency() -> Iterator[Session]:
    _ensure_engine()
    with get_session() as session:
        yield session


@router.get("/{address}", response_model=AccountProfile)
def get_profile(address: str, session: Session = Depends(_session_dependency)) -> AccountProfile:
    service = AccountsService(session)
    account = service.get_account(address)
    if account is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Профиль не найден")
    return AccountProfile.model_validate(account)


def _build_avatar(update: AvatarPayload | None) -> AvatarUpdate | None:
    if update is None:
        return None
    return AvatarUpdate(kind=update.kind, value=update.value)


@router.put("/{address}", response_model=AccountProfile)
def upsert_profile(
    address: str,
    payload: AccountProfileUpdate,
    session: Session = Depends(_session_dependency),
) -> AccountProfile:
    service = AccountsService(session)
    account = service.upsert_account(
        address,
        ProfileUpdate(
            nickname=payload.nickname,
            avatar=_build_avatar(payload.avatar),
            telegram=payload.telegram,
            twitter=payload.twitter,
            settings=payload.settings,
        ),
    )
    session.commit()
    return AccountProfile.model_validate(account)


__all__ = ["router"]
