from __future__ import annotations

from datetime import UTC, datetime
from uuid import uuid4

from fastapi import APIRouter, Depends, Header, HTTPException, status
from sqlalchemy.orm import Session

from one_api.api.deps import UserContext, get_user_context
from one_api.db import models
from one_api.db.repositories import TodoRepository
from one_api.db.session import get_db
from one_api.schemas import TodoCreateRequest, TodoResponse, TodoUpdateRequest
from one_api.services.task_service import TaskService

router = APIRouter(prefix="/todos", tags=["todos"])


@router.get("", response_model=list[TodoResponse])
def list_todos(
    ctx: UserContext = Depends(get_user_context),
    db: Session = Depends(get_db),
):
    rows = TodoRepository(db).list_for_user(ctx.user_id)
    return [TodoResponse.model_validate(row) for row in rows]


@router.post("", response_model=TodoResponse, status_code=status.HTTP_201_CREATED)
def create_todo(
    payload: TodoCreateRequest,
    ctx: UserContext = Depends(get_user_context),
    db: Session = Depends(get_db),
):
    now = datetime.now(UTC)
    row = models.TodoModel(
        id=str(uuid4()),
        user_id=ctx.user_id,
        category_id=payload.category_id,
        title=payload.title,
        notes=payload.notes,
        due_at=payload.due_at,
        priority=payload.priority,
        is_pinned=payload.is_pinned,
        status="open",
        created_at=now,
        updated_at=now,
    )
    TodoRepository(db).create(row)
    db.commit()
    return TodoResponse.model_validate(row)


@router.patch("/{todo_id}", response_model=TodoResponse)
def patch_todo(
    todo_id: str,
    payload: TodoUpdateRequest,
    x_client_updated_at: str | None = Header(default=None),
    ctx: UserContext = Depends(get_user_context),
    db: Session = Depends(get_db),
):
    repo = TodoRepository(db)
    row = repo.get(ctx.user_id, todo_id)
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Todo not found")

    updated = TaskService(db).apply_todo_patch(
        todo_row=row,
        payload=payload.model_dump(exclude_unset=True),
        client_updated_at=x_client_updated_at,
    )

    db.commit()
    return TodoResponse.model_validate(updated)


@router.delete("/{todo_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_todo(
    todo_id: str,
    ctx: UserContext = Depends(get_user_context),
    db: Session = Depends(get_db),
):
    deleted = TodoRepository(db).delete(ctx.user_id, todo_id)
    if not deleted:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Todo not found")
    db.commit()
