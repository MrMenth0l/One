from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from one_api.api.deps import UserContext, get_user_context
from one_api.db.repositories import CategoryRepository
from one_api.db.session import get_db
from one_api.schemas import CategoryCreateRequest, CategoryResponse

router = APIRouter(prefix="/categories", tags=["categories"])


@router.get("", response_model=list[CategoryResponse])
def list_categories(
    ctx: UserContext = Depends(get_user_context),
    db: Session = Depends(get_db),
):
    rows = CategoryRepository(db).list_for_user(ctx.user_id)
    return [CategoryResponse.model_validate(row) for row in rows]


@router.post("", response_model=CategoryResponse, status_code=status.HTTP_201_CREATED)
def create_category(
    payload: CategoryCreateRequest,
    ctx: UserContext = Depends(get_user_context),
    db: Session = Depends(get_db),
):
    row = CategoryRepository(db).create(
        ctx.user_id,
        name=payload.name,
        icon=payload.icon,
        color=payload.color,
    )
    db.commit()
    return CategoryResponse.model_validate(row)


@router.delete("/{category_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_category(
    category_id: str,
    ctx: UserContext = Depends(get_user_context),
    db: Session = Depends(get_db),
):
    deleted = CategoryRepository(db).delete(ctx.user_id, category_id)
    if not deleted:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Category not found")
    db.commit()
