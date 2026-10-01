from app.contracts.repositories import IUnitOfWork
from app.extensions import db


class SqlAlchemyUnitOfWork(IUnitOfWork):
    def commit(self) -> None:
        db.session.commit()

    def rollback(self) -> None:
        db.session.rollback()

    def flush(self) -> None:
        db.session.flush()

    def close(self) -> None:
        db.session.remove()
