from app.contracts.repositories import (
    IAssumptionRepository,
    ICatalogRepository,
    IDeviceTokenRepository,
    IUnitOfWork,
    IUserActionRepository,
    IWatchlistRepository,
)
from app.contracts.services import IAccountService, IMarketDataService
from app.domain.errors import NotFoundError, ValidationError
from app.models.user import DEVICE_PLATFORMS, STANCES, USER_ACTIONS


class AccountService(IAccountService):
    """A user's watchlist and their own buy/sell/hold journal (never orders)."""

    def __init__(
        self,
        catalog: ICatalogRepository,
        market_data: IMarketDataService,
        watchlist: IWatchlistRepository,
        actions: IUserActionRepository,
        devices: IDeviceTokenRepository,
        assumptions: IAssumptionRepository,
        uow: IUnitOfWork,
    ):
        self._catalog = catalog
        self._data = market_data
        self._watchlist = watchlist
        self._actions = actions
        self._devices = devices
        self._assumptions = assumptions
        self._uow = uow

    def watchlist(self, user_id: str) -> list[dict]:
        tickers = [item.ticker for item in self._watchlist.list_for_user(user_id)]
        quotes = self._data.quotes(tickers)
        return [{**t.to_dict(), "quote": quotes.get(t.symbol)} for t in tickers]

    def add_to_watchlist(self, user_id: str, symbol: str) -> str:
        ticker = self._require_ticker(symbol)
        self._watchlist.add(user_id, ticker.id)
        self._uow.commit()
        return ticker.symbol

    def remove_from_watchlist(self, user_id: str, symbol: str) -> None:
        ticker = self._catalog.ticker(symbol)
        if ticker is not None:
            self._watchlist.remove(user_id, ticker.id)
            self._uow.commit()

    def record_action(self, user_id: str, symbol: str, action: str) -> dict:
        if action not in USER_ACTIONS:
            raise ValidationError(f"action must be one of {', '.join(USER_ACTIONS)}")
        ticker = self._require_ticker(symbol)
        entry = self._actions.add(user_id, ticker.id, action)
        entry.ticker = ticker
        self._uow.commit()
        return entry.to_dict()

    def actions(self, user_id: str) -> list[dict]:
        return [e.to_dict() for e in self._actions.list_for_user(user_id)]

    def assumptions(self, user_id: str) -> list[dict]:
        entries = self._assumptions.list_for_user(user_id)
        quotes = self._data.quotes([e.ticker for e in entries])
        out = []
        for e in entries:
            data = e.to_dict()
            quote = quotes.get(e.ticker.symbol)
            now = quote.get("price") if quote else None
            then = data["price"]
            data["quote"] = quote
            data["change_since_percent"] = (now / then - 1) * 100 if now and then else None
            out.append(data)
        return out

    def set_assumption(self, user_id: str, symbol: str, stance: str) -> dict:
        if stance not in STANCES:
            raise ValidationError(f"stance must be one of {', '.join(STANCES)}")
        ticker = self._require_ticker(symbol)
        quote = self._data.quotes([ticker]).get(ticker.symbol)
        entry = self._assumptions.upsert(user_id, ticker.id, stance, quote.get("price") if quote else None)
        entry.ticker = ticker
        self._uow.commit()
        return entry.to_dict()

    def clear_assumption(self, user_id: str, symbol: str) -> None:
        ticker = self._catalog.ticker(symbol or "")
        if ticker is not None:
            self._assumptions.remove(user_id, ticker.id)
            self._uow.commit()

    MAX_TOKEN_LENGTH = 512

    def register_device(self, user_id: str, token: str, platform: str) -> None:
        token = (token or "").strip()
        if not token or len(token) > self.MAX_TOKEN_LENGTH:
            raise ValidationError("token is required")
        if platform not in DEVICE_PLATFORMS:
            raise ValidationError(f"platform must be one of {', '.join(DEVICE_PLATFORMS)}")
        self._devices.upsert(user_id, token, platform)
        self._uow.commit()

    def unregister_device(self, user_id: str, token: str) -> None:
        self._devices.remove((token or "").strip(), user_id=user_id)
        self._uow.commit()

    def _require_ticker(self, symbol: str):
        ticker = self._catalog.ticker(symbol or "")
        if ticker is None:
            raise NotFoundError("Symbol not found")
        return ticker
