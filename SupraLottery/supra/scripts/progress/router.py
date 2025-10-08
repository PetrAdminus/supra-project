"""FastAPI-роутер подсистемы прогресса."""
from __future__ import annotations

from fastapi import APIRouter, HTTPException, status

from .schemas import (
    AchievementPayload,
    AchievementProgressResponse,
    AchievementResponse,
    AchievementStatusResponse,
    AchievementUnlockRequest,
    ChecklistCompleteRequest,
    ChecklistProgressResponse,
    ChecklistStatusResponse,
    ChecklistTaskPayload,
    ChecklistTaskResponse,
)
from .service import (
    AchievementNotFoundError,
    TaskNotFoundError,
    complete_checklist_task,
    get_checklist_for_address,
    list_achievements_for_address,
    unlock_achievement,
    upsert_achievement,
    upsert_checklist_task,
)
from .tables import Achievement, AchievementProgress, ChecklistProgress, ChecklistTask

router = APIRouter(prefix="/progress", tags=["progress"])


def _task_to_response(task: ChecklistTask) -> ChecklistTaskResponse:
    return ChecklistTaskResponse(
        code=task.code,
        title=task.title,
        description=task.description,
        day_index=task.day_index,
        reward_kind=task.reward_kind,
        reward_value=task.reward_value,
        metadata=task.metadata,
        is_active=task.is_active,
        created_at=task.created_at,
        updated_at=task.updated_at,
    )


def _progress_to_response(task: ChecklistTask, progress: ChecklistProgress | None) -> ChecklistProgressResponse:
    return ChecklistProgressResponse(
        task=_task_to_response(task),
        completed=progress is not None,
        completed_at=progress.completed_at if progress else None,
        reward_claimed=progress.reward_claimed if progress else False,
        metadata=progress.metadata if progress else None,
    )


def _achievement_to_response(instance: Achievement) -> AchievementResponse:
    return AchievementResponse(
        code=instance.code,
        title=instance.title,
        description=instance.description,
        points=instance.points,
        metadata=instance.metadata,
        is_active=instance.is_active,
        created_at=instance.created_at,
        updated_at=instance.updated_at,
    )


def _achievement_progress_to_response(
    achievement: Achievement, progress: AchievementProgress | None
) -> AchievementProgressResponse:
    return AchievementProgressResponse(
        achievement=_achievement_to_response(achievement),
        unlocked=progress.unlocked_at is not None if progress else False,
        unlocked_at=progress.unlocked_at if progress else None,
        progress_value=progress.progress_value if progress else 0,
        metadata=progress.metadata if progress else None,
    )


@router.put("/checklist/{code}", response_model=ChecklistTaskResponse)
def put_checklist_task(code: str, payload: ChecklistTaskPayload) -> ChecklistTaskResponse:
    data = payload.dict()
    data["code"] = code
    task = upsert_checklist_task(data)
    return _task_to_response(task)


@router.get("/{address}/checklist", response_model=ChecklistStatusResponse)
def get_checklist(address: str) -> ChecklistStatusResponse:
    entries = [
        _progress_to_response(task, progress)
        for task, progress in get_checklist_for_address(address)
    ]
    return ChecklistStatusResponse(address=address.lower().strip(), tasks=entries)


@router.post(
    "/{address}/checklist/{code}/complete",
    response_model=ChecklistProgressResponse,
    status_code=status.HTTP_201_CREATED,
)
def complete_checklist(
    address: str, code: str, payload: ChecklistCompleteRequest
) -> ChecklistProgressResponse:
    try:
        progress = complete_checklist_task(
            address,
            code,
            metadata=payload.metadata,
            reward_claimed=payload.reward_claimed,
        )
    except TaskNotFoundError as exc:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Задание не найдено") from exc
    return _progress_to_response(progress.task, progress)


@router.put("/achievements/{code}", response_model=AchievementResponse)
def put_achievement(code: str, payload: AchievementPayload) -> AchievementResponse:
    data = payload.dict()
    data["code"] = code
    achievement = upsert_achievement(data)
    return _achievement_to_response(achievement)


@router.get("/{address}/achievements", response_model=AchievementStatusResponse)
def get_achievements(address: str) -> AchievementStatusResponse:
    entries = [
        _achievement_progress_to_response(achievement, progress)
        for achievement, progress in list_achievements_for_address(address)
    ]
    return AchievementStatusResponse(address=address.lower().strip(), achievements=entries)


@router.post(
    "/{address}/achievements/{code}/unlock",
    response_model=AchievementProgressResponse,
    status_code=status.HTTP_201_CREATED,
)
def post_unlock_achievement(
    address: str, code: str, payload: AchievementUnlockRequest
) -> AchievementProgressResponse:
    try:
        progress = unlock_achievement(
            address,
            code,
            progress_value=payload.progress_value,
            metadata=payload.metadata,
        )
    except AchievementNotFoundError as exc:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Достижение не найдено") from exc
    return _achievement_progress_to_response(progress.achievement, progress)


__all__ = ["router"]
