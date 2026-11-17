from app.contracts.repositories import IDeviceTokenRepository
from app.extensions import db
from app.models import DeviceToken
from app.models.base import utcnow


class SqlAlchemyDeviceTokenRepository(IDeviceTokenRepository):
    def upsert(self, user_id: str, token: str, platform: str) -> None:
        device = DeviceToken.query.filter_by(token=token).first()
        if device is None:
            db.session.add(DeviceToken(user_id=user_id, token=token, platform=platform))
            return
        # A token moves with the phone: re-assign it if another account signed in.
        device.user_id = user_id
        device.platform = platform
        device.last_seen_at = utcnow()

    def remove(self, token: str, *, user_id: str | None = None) -> None:
        query = DeviceToken.query.filter_by(token=token)
        if user_id is not None:
            query = query.filter_by(user_id=user_id)
        query.delete()

    def tokens_for_user(self, user_id: str) -> list[str]:
        return [d.token for d in DeviceToken.query.filter_by(user_id=user_id).all()]
