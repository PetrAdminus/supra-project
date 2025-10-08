"""Прикладная логика центра поддержки."""
from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..accounts.db import get_session
from .tables import SupportArticle, SupportTicket


def _normalize_address(address: str) -> str:
    return address.lower().strip()


def list_articles(locale: str | None = None) -> list[SupportArticle]:
    with get_session() as session:
        statement = select(SupportArticle).order_by(SupportArticle.created_at.asc())
        if locale:
            statement = statement.filter(SupportArticle.locale == locale)
        return list(session.scalars(statement))


def get_article_by_slug(slug: str) -> SupportArticle | None:
    with get_session() as session:
        statement = select(SupportArticle).where(SupportArticle.slug == slug)
        return session.scalars(statement).first()


def create_or_update_article(payload: dict[str, str | dict[str, object]]) -> SupportArticle:
    with get_session() as session:
        article = _upsert_article(session, payload)
        session.commit()
        session.refresh(article)
        return article


def _upsert_article(session: Session, payload: dict[str, str | dict[str, object]]) -> SupportArticle:
    slug = str(payload["slug"])
    statement = select(SupportArticle).where(SupportArticle.slug == slug)
    instance = session.scalars(statement).first()
    if instance is None:
        instance = SupportArticle(slug=slug)
        session.add(instance)
    instance.title = str(payload.get("title", instance.title))
    instance.body = str(payload.get("body", instance.body))
    instance.locale = str(payload.get("locale", instance.locale or "ru"))
    instance.tags = dict(payload.get("tags", instance.tags or {}))
    return instance


def create_ticket(payload: dict[str, object]) -> SupportTicket:
    with get_session() as session:
        ticket = SupportTicket(
            address=_normalize_address(str(payload.get("address", ""))),
            email=str(payload.get("email")) if payload.get("email") else None,
            subject=str(payload.get("subject", "")),
            body=str(payload.get("body", "")),
            metadata=dict(payload.get("metadata", {})),
        )
        session.add(ticket)
        session.commit()
        session.refresh(ticket)
        return ticket


__all__ = [
    "list_articles",
    "get_article_by_slug",
    "create_or_update_article",
    "create_ticket",
]
