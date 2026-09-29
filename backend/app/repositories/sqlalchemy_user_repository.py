from typing import Optional

from app.contracts.repositories import UserRepository
from app.extensions import db
from app.models.user import User


class SqlAlchemyUserRepository(UserRepository):
    def get_by_id(self, user_id: int) -> Optional[User]:
        return db.session.get(User, user_id)

    def get_by_email(self, email: str) -> Optional[User]:
        return User.query.filter_by(email=email.lower()).first()

    def create(self, *, first_name: str, last_name: str, email: str, password_hash: str) -> User:
        user = User(
            first_name=first_name,
            last_name=last_name,
            email=email.lower(),
            password_hash=password_hash,
            is_verified=False,
        )
        db.session.add(user)
        db.session.commit()
        return user

    def update_profile(self, user_id: int, *, first_name: Optional[str] = None, last_name: Optional[str] = None) -> Optional[User]:
        user = self.get_by_id(user_id)
        if user is None:
            return None
        if first_name is not None:
            user.first_name = first_name
        if last_name is not None:
            user.last_name = last_name
        db.session.commit()
        return user

    def mark_verified(self, user_id: int) -> Optional[User]:
        user = self.get_by_id(user_id)
        if user is None:
            return None
        user.is_verified = True
        db.session.commit()
        return user
