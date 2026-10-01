from typing import Optional

from app.contracts.repositories import IUserRepository
from app.extensions import db
from app.models import User


class SqlAlchemyUserRepository(IUserRepository):
    def get_by_id(self, user_id: str) -> Optional[User]:
        return db.session.get(User, user_id)

    def get_by_email(self, email: str) -> Optional[User]:
        return User.query.filter_by(email=email.strip().lower()).first()

    def create(self, *, first_name: str, last_name: str, email: str, password_hash: str, is_verified: bool = False) -> User:
        user = User(
            first_name=first_name.strip(),
            last_name=last_name.strip(),
            email=email.strip().lower(),
            password_hash=password_hash,
            is_verified=is_verified,
        )
        db.session.add(user)
        return user

    def update(self, user_id: str, **fields) -> Optional[User]:
        user = self.get_by_id(user_id)
        if user is None:
            return None
        for name, value in fields.items():
            setattr(user, name, value)
        return user
