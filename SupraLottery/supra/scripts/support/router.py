"""FastAPI-роутер центра поддержки."""
from __future__ import annotations

from fastapi import APIRouter, HTTPException, status

from .schemas import (
    SupportArticleCreate,
    SupportArticleListResponse,
    SupportArticleResponse,
    SupportTicketCreate,
    SupportTicketResponse,
)
from .service import create_or_update_article, create_ticket, get_article_by_slug, list_articles

router = APIRouter(prefix="/support", tags=["support"])


@router.get("/articles", response_model=SupportArticleListResponse)
def get_articles(locale: str | None = None) -> SupportArticleListResponse:
    """Возвращает список статей базы знаний."""

    articles = [
        SupportArticleResponse(
            slug=item.slug,
            title=item.title,
            body=item.body,
            locale=item.locale,
            tags=item.tags,
            created_at=item.created_at,
            updated_at=item.updated_at,
        )
        for item in list_articles(locale=locale)
    ]
    return SupportArticleListResponse(articles=articles)


@router.get("/articles/{slug}", response_model=SupportArticleResponse)
def get_article(slug: str) -> SupportArticleResponse:
    article = get_article_by_slug(slug)
    if article is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Статья не найдена")
    return SupportArticleResponse(
        slug=article.slug,
        title=article.title,
        body=article.body,
        locale=article.locale,
        tags=article.tags,
        created_at=article.created_at,
        updated_at=article.updated_at,
    )


@router.put("/articles/{slug}", response_model=SupportArticleResponse)
def put_article(slug: str, payload: SupportArticleCreate) -> SupportArticleResponse:
    data = payload.dict()
    data["slug"] = slug
    article = create_or_update_article(data)
    return SupportArticleResponse(
        slug=article.slug,
        title=article.title,
        body=article.body,
        locale=article.locale,
        tags=article.tags,
        created_at=article.created_at,
        updated_at=article.updated_at,
    )


@router.post("/tickets", response_model=SupportTicketResponse, status_code=status.HTTP_201_CREATED)
def post_ticket(payload: SupportTicketCreate) -> SupportTicketResponse:
    ticket = create_ticket(payload.dict())
    return SupportTicketResponse(id=ticket.id, status=ticket.status, created_at=ticket.created_at)
