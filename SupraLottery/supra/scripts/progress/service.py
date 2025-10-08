"""Прикладная логика чек-листов и достижений."""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..accounts.db import get_session
from .tables import (
    Achievement,
    AchievementProgress,
    ChecklistProgress,
    ChecklistTask,
)


class TaskNotFoundError(LookupError):
    """Задание чек-листа не найдено или отключено."""


class AchievementNotFoundError(LookupError):
    """Достижение не найдено или отключено."""


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _normalize_address(address: str) -> str:
    return address.lower().strip()


def _select_task_by_code(session: Session, code: str) -> ChecklistTask | None:
    statement = select(ChecklistTask).where(ChecklistTask.code == code)
    return session.scalars(statement).first()


def upsert_checklist_task(payload: dict[str, Any]) -> ChecklistTask:
    """Создаёт или обновляет запись чек-листа."""

    with get_session() as session:
        task = _upsert_task(session, payload)
        session.commit()
        session.refresh(task)
        return task


def _upsert_task(session: Session, payload: dict[str, Any]) -> ChecklistTask:
    code = str(payload["code"]).strip().lower()
    statement = select(ChecklistTask).where(ChecklistTask.code == code)
    instance = session.scalars(statement).first()
    if instance is None:
        instance = ChecklistTask(code=code)
        session.add(instance)

    instance.title = str(payload.get("title", instance.title or ""))
    instance.description = str(payload.get("description", instance.description or ""))
    instance.day_index = int(payload.get("day_index", instance.day_index or 0))
    instance.reward_kind = str(payload.get("reward_kind", instance.reward_kind or "none"))
    if "reward_value" in payload:
        instance.reward_value = dict(payload.get("reward_value") or {})
    if "metadata" in payload:
        instance.metadata = dict(payload.get("metadata") or {})
    if "is_active" in payload:
        instance.is_active = bool(payload["is_active"])
    return instance


def get_checklist_for_address(address: str) -> list[tuple[ChecklistTask, ChecklistProgress | None]]:
    """Возвращает активные задания чек-листа и их статус для пользователя."""

    normalized = _normalize_address(address)
    with get_session() as session:
        tasks = list(
            session.scalars(
                select(ChecklistTask)
                .where(ChecklistTask.is_active.is_(True))
                .order_by(ChecklistTask.day_index.asc(), ChecklistTask.id.asc())
            )
        )
        progress_map = {
            row.task_id: row
            for row in session.scalars(
                select(ChecklistProgress).where(ChecklistProgress.address == normalized)
            )
        }
        return [(task, progress_map.get(task.id)) for task in tasks]


def complete_checklist_task(
    address: str,
    code: str,
    metadata: dict[str, Any] | None = None,
    reward_claimed: bool | None = None,
) -> ChecklistProgress:
    """Отмечает выполнение задания пользователем."""

    normalized = _normalize_address(address)
    with get_session() as session:
        task = _select_task_by_code(session, code.strip().lower())
        if task is None or not task.is_active:
            raise TaskNotFoundError(code)

        statement = select(ChecklistProgress).where(
            ChecklistProgress.address == normalized,
            ChecklistProgress.task_id == task.id,
        )
        progress = session.scalars(statement).first()
        if progress is None:
            progress = ChecklistProgress(address=normalized, task=task)
            session.add(progress)
        if metadata is not None:
            progress.metadata = dict(metadata)
        if reward_claimed is not None:
            progress.reward_claimed = bool(reward_claimed)
        if not progress.completed_at:
            progress.completed_at = _utcnow()

        session.commit()
        session.refresh(progress)
        return progress


def upsert_achievement(payload: dict[str, Any]) -> Achievement:
    """Создаёт или обновляет определение достижения."""

    with get_session() as session:
        achievement = _upsert_achievement(session, payload)
        session.commit()
        session.refresh(achievement)
        return achievement


def _upsert_achievement(session: Session, payload: dict[str, Any]) -> Achievement:
    code = str(payload["code"]).strip().lower()
    statement = select(Achievement).where(Achievement.code == code)
    instance = session.scalars(statement).first()
    if instance is None:
        instance = Achievement(code=code)
        session.add(instance)

    instance.title = str(payload.get("title", instance.title or ""))
    instance.description = str(payload.get("description", instance.description or ""))
    if "points" in payload:
        instance.points = int(payload.get("points") or 0)
    if "metadata" in payload:
        instance.metadata = dict(payload.get("metadata") or {})
    if "is_active" in payload:
        instance.is_active = bool(payload["is_active"])
    return instance


def list_achievements_for_address(
    address: str,
) -> list[tuple[Achievement, AchievementProgress | None]]:
    """Возвращает достижения и прогресс пользователя."""

    normalized = _normalize_address(address)
    with get_session() as session:
        achievements = list(
            session.scalars(
                select(Achievement)
                .where(Achievement.is_active.is_(True))
                .order_by(Achievement.points.desc(), Achievement.id.asc())
            )
        )
        progress_map = {
            row.achievement_id: row
            for row in session.scalars(
                select(AchievementProgress).where(AchievementProgress.address == normalized)
            )
        }
        return [(achievement, progress_map.get(achievement.id)) for achievement in achievements]


def unlock_achievement(
    address: str,
    code: str,
    progress_value: int | None = None,
    metadata: dict[str, Any] | None = None,
) -> AchievementProgress:
    """Отмечает достижение выполненным."""

    normalized = _normalize_address(address)
    with get_session() as session:
        statement = select(Achievement).where(Achievement.code == code.strip().lower())
        achievement = session.scalars(statement).first()
        if achievement is None or not achievement.is_active:
            raise AchievementNotFoundError(code)

        progress_stmt = select(AchievementProgress).where(
            AchievementProgress.address == normalized,
            AchievementProgress.achievement_id == achievement.id,
        )
        progress = session.scalars(progress_stmt).first()
        if progress is None:
            progress = AchievementProgress(address=normalized, achievement=achievement)
            session.add(progress)
        if progress.unlocked_at is None:
            progress.unlocked_at = _utcnow()
        if progress_value is not None:
            progress.progress_value = int(progress_value)
        if metadata is not None:
            progress.metadata = dict(metadata)

        session.commit()
        session.refresh(progress)
        return progress


__all__ = [
    "TaskNotFoundError",
    "AchievementNotFoundError",
    "upsert_checklist_task",
    "get_checklist_for_address",
    "complete_checklist_task",
    "list_achievements_for_address",
    "unlock_achievement",
    "upsert_achievement",
]
