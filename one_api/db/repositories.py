from __future__ import annotations

from datetime import UTC, date, datetime
from uuid import uuid4

from sqlalchemy import and_, delete, select
from sqlalchemy.orm import Session

from one.models import DEFAULT_CATEGORY_ICONS, DEFAULT_CATEGORY_NAMES
from one_api.db import models


class UserRepository:
    def __init__(self, db: Session):
        self.db = db

    def get(self, user_id: str) -> models.UserModel | None:
        return self.db.get(models.UserModel, user_id)

    def get_by_email(self, email: str) -> models.UserModel | None:
        stmt = select(models.UserModel).where(models.UserModel.email == email)
        return self.db.execute(stmt).scalar_one_or_none()

    def upsert(self, *, user_id: str, email: str, display_name: str, timezone: str, apple_sub: str | None = None) -> models.UserModel:
        row = self.get(user_id)
        if row is None:
            row = models.UserModel(
                id=user_id,
                email=email,
                display_name=display_name,
                timezone=timezone,
                apple_sub=apple_sub,
            )
            self.db.add(row)
        else:
            row.email = email
            row.display_name = display_name or row.display_name
            row.timezone = timezone or row.timezone
            if apple_sub:
                row.apple_sub = apple_sub
            row.updated_at = datetime.now(UTC)

        return row


class CategoryRepository:
    def __init__(self, db: Session):
        self.db = db

    def list_for_user(self, user_id: str) -> list[models.CategoryModel]:
        stmt = (
            select(models.CategoryModel)
            .where(models.CategoryModel.user_id == user_id)
            .order_by(models.CategoryModel.sort_order.asc(), models.CategoryModel.created_at.asc())
        )
        return list(self.db.execute(stmt).scalars().all())

    def get(self, user_id: str, category_id: str) -> models.CategoryModel | None:
        stmt = select(models.CategoryModel).where(
            and_(models.CategoryModel.id == category_id, models.CategoryModel.user_id == user_id)
        )
        return self.db.execute(stmt).scalar_one_or_none()

    def create(self, user_id: str, *, name: str, icon: str = "circle", color: str = "#5B8DEF") -> models.CategoryModel:
        current = self.list_for_user(user_id)
        row = models.CategoryModel(
            id=str(uuid4()),
            user_id=user_id,
            name=name,
            icon=icon,
            color=color,
            sort_order=len(current),
            is_default=False,
        )
        self.db.add(row)
        return row

    def create_defaults(self, user_id: str) -> list[models.CategoryModel]:
        existing = self.list_for_user(user_id)
        if existing:
            return existing

        created: list[models.CategoryModel] = []
        for index, name in enumerate(DEFAULT_CATEGORY_NAMES):
            row = models.CategoryModel(
                id=str(uuid4()),
                user_id=user_id,
                name=name,
                icon=DEFAULT_CATEGORY_ICONS.get(name, "circle"),
                sort_order=index,
                is_default=True,
            )
            self.db.add(row)
            created.append(row)
        return created

    def delete(self, user_id: str, category_id: str) -> bool:
        row = self.get(user_id, category_id)
        if row is None:
            return False
        self.db.delete(row)
        return True


class HabitRepository:
    def __init__(self, db: Session):
        self.db = db

    def list_for_user(self, user_id: str) -> list[models.HabitModel]:
        stmt = select(models.HabitModel).where(models.HabitModel.user_id == user_id)
        return list(self.db.execute(stmt).scalars().all())

    def get(self, user_id: str, habit_id: str) -> models.HabitModel | None:
        stmt = select(models.HabitModel).where(
            and_(models.HabitModel.id == habit_id, models.HabitModel.user_id == user_id)
        )
        return self.db.execute(stmt).scalar_one_or_none()

    def create(self, row: models.HabitModel) -> models.HabitModel:
        self.db.add(row)
        return row

    def delete(self, user_id: str, habit_id: str) -> bool:
        row = self.get(user_id, habit_id)
        if row is None:
            return False
        self.db.delete(row)
        return True


class TodoRepository:
    def __init__(self, db: Session):
        self.db = db

    def list_for_user(self, user_id: str) -> list[models.TodoModel]:
        stmt = select(models.TodoModel).where(models.TodoModel.user_id == user_id)
        return list(self.db.execute(stmt).scalars().all())

    def get(self, user_id: str, todo_id: str) -> models.TodoModel | None:
        stmt = select(models.TodoModel).where(
            and_(models.TodoModel.id == todo_id, models.TodoModel.user_id == user_id)
        )
        return self.db.execute(stmt).scalar_one_or_none()

    def create(self, row: models.TodoModel) -> models.TodoModel:
        self.db.add(row)
        return row

    def delete(self, user_id: str, todo_id: str) -> bool:
        row = self.get(user_id, todo_id)
        if row is None:
            return False
        self.db.delete(row)
        return True


class CompletionLogRepository:
    def __init__(self, db: Session):
        self.db = db

    def list_for_user(self, user_id: str) -> list[models.CompletionLogModel]:
        stmt = select(models.CompletionLogModel).where(models.CompletionLogModel.user_id == user_id)
        return list(self.db.execute(stmt).scalars().all())

    def list_for_date(self, user_id: str, target: date) -> list[models.CompletionLogModel]:
        stmt = select(models.CompletionLogModel).where(
            and_(
                models.CompletionLogModel.user_id == user_id,
                models.CompletionLogModel.date_local == target,
            )
        )
        return list(self.db.execute(stmt).scalars().all())

    def upsert(
        self,
        *,
        user_id: str,
        item_type: str,
        item_id: str,
        date_local: date,
        state: str,
        completed_at: datetime | None,
        source: str,
    ) -> models.CompletionLogModel:
        stmt = select(models.CompletionLogModel).where(
            and_(
                models.CompletionLogModel.user_id == user_id,
                models.CompletionLogModel.item_type == item_type,
                models.CompletionLogModel.item_id == item_id,
                models.CompletionLogModel.date_local == date_local,
            )
        )
        row = self.db.execute(stmt).scalar_one_or_none()
        now = datetime.now(UTC)
        if row is None:
            row = models.CompletionLogModel(
                id=str(uuid4()),
                user_id=user_id,
                item_type=item_type,
                item_id=item_id,
                date_local=date_local,
                state=state,
                completed_at=completed_at,
                source=source,
                created_at=now,
                updated_at=now,
            )
            self.db.add(row)
            return row

        row.state = state
        row.completed_at = completed_at
        row.source = source
        row.updated_at = now
        return row


class TodayOrderOverrideRepository:
    def __init__(self, db: Session):
        self.db = db

    def list_for_date(self, user_id: str, target: date) -> list[models.TodayOrderOverrideModel]:
        stmt = select(models.TodayOrderOverrideModel).where(
            and_(
                models.TodayOrderOverrideModel.user_id == user_id,
                models.TodayOrderOverrideModel.date_local == target,
            )
        )
        return list(self.db.execute(stmt).scalars().all())

    def replace_for_date(
        self,
        *,
        user_id: str,
        target: date,
        items: list[tuple[str, str, int]],
    ) -> list[models.TodayOrderOverrideModel]:
        self.db.execute(
            delete(models.TodayOrderOverrideModel).where(
                and_(
                    models.TodayOrderOverrideModel.user_id == user_id,
                    models.TodayOrderOverrideModel.date_local == target,
                )
            )
        )
        rows: list[models.TodayOrderOverrideModel] = []
        now = datetime.now(UTC)
        for item_type, item_id, order_index in items:
            row = models.TodayOrderOverrideModel(
                id=str(uuid4()),
                user_id=user_id,
                date_local=target,
                item_type=item_type,
                item_id=item_id,
                order_index=order_index,
                created_at=now,
                updated_at=now,
            )
            self.db.add(row)
            rows.append(row)
        return rows


class ReflectionRepository:
    def __init__(self, db: Session):
        self.db = db

    def get(self, user_id: str, reflection_id: str) -> models.ReflectionNoteModel | None:
        stmt = select(models.ReflectionNoteModel).where(
            and_(
                models.ReflectionNoteModel.id == reflection_id,
                models.ReflectionNoteModel.user_id == user_id,
            )
        )
        return self.db.execute(stmt).scalar_one_or_none()

    def list_for_user(self, user_id: str, period_type: str | None = None) -> list[models.ReflectionNoteModel]:
        stmt = select(models.ReflectionNoteModel).where(models.ReflectionNoteModel.user_id == user_id)
        if period_type:
            stmt = stmt.where(models.ReflectionNoteModel.period_type == period_type)
        stmt = stmt.order_by(
            models.ReflectionNoteModel.period_start.desc(),
            models.ReflectionNoteModel.created_at.desc(),
        )
        return list(self.db.execute(stmt).scalars().all())

    def create(
        self,
        *,
        user_id: str,
        period_type: str,
        period_start: date,
        period_end: date,
        content: str,
        sentiment: str,
        tags: list[str],
    ) -> models.ReflectionNoteModel:
        now = datetime.now(UTC)
        row = models.ReflectionNoteModel(
            id=str(uuid4()),
            user_id=user_id,
            period_type=period_type,
            period_start=period_start,
            period_end=period_end,
            content=content,
            sentiment=sentiment,
            tags=tags,
            created_at=now,
            updated_at=now,
        )
        self.db.add(row)
        return row

    def delete(self, user_id: str, reflection_id: str) -> bool:
        row = self.get(user_id, reflection_id)
        if row is None:
            return False
        self.db.delete(row)
        return True


class PreferencesRepository:
    def __init__(self, db: Session):
        self.db = db

    def get(self, user_id: str) -> models.UserPreferencesModel | None:
        stmt = select(models.UserPreferencesModel).where(models.UserPreferencesModel.user_id == user_id)
        return self.db.execute(stmt).scalar_one_or_none()

    def get_or_create(self, user_id: str) -> models.UserPreferencesModel:
        row = self.get(user_id)
        if row:
            return row

        row = models.UserPreferencesModel(
            id=str(uuid4()),
            user_id=user_id,
            notification_flags={
                "habit_reminders": True,
                "todo_reminders": True,
                "reflection_prompts": True,
                "weekly_summary": True,
            },
        )
        self.db.add(row)
        return row


class CoachCardRepository:
    def __init__(self, db: Session):
        self.db = db

    def list_active(self, target: date, locale: str = "en") -> list[models.CoachCardModel]:
        stmt = select(models.CoachCardModel).where(models.CoachCardModel.is_active.is_(True))
        rows = list(self.db.execute(stmt).scalars().all())
        filtered = []
        for row in rows:
            if row.locale != locale:
                continue
            if row.active_from and target < row.active_from:
                continue
            if row.active_to and target > row.active_to:
                continue
            filtered.append(row)
        return filtered


class ReminderRepository:
    def __init__(self, db: Session):
        self.db = db

    def list_for_user(self, user_id: str) -> list[models.ReminderModel]:
        stmt = select(models.ReminderModel).where(models.ReminderModel.user_id == user_id)
        return list(self.db.execute(stmt).scalars().all())


class PurgeRepository:
    def __init__(self, db: Session):
        self.db = db

    def clear_user_data(self, user_id: str) -> None:
        self.db.execute(delete(models.CompletionLogModel).where(models.CompletionLogModel.user_id == user_id))
        self.db.execute(delete(models.TodoModel).where(models.TodoModel.user_id == user_id))
        self.db.execute(delete(models.HabitModel).where(models.HabitModel.user_id == user_id))
        self.db.execute(delete(models.CategoryModel).where(models.CategoryModel.user_id == user_id))
