from app.contracts.repositories import ICatalogRepository, IUnitOfWork, IUserActionRepository, IWatchlistRepository
from app.contracts.services import IAccountService, IMarketDataService
from app.domain.errors import NotFoundError, ValidationError
from app.models.user import USER_ACTIONS


class AccountService(IAccountService):
    """A user's watchlist and their own buy/sell/hold journal (never orders)."""

    def __init__(
        self,
        catalog: ICatalogRepository,
        market_data: IMarketDataService,
        watchlist: IWatchlistRepository,
        actions: IUserActionRepository,
        uow: IUnitOfWork,
    ):
        self._catalog = catalog
        self._data = market_data
        self._watchlist = watchlist
        self._actions = actions
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

    def _require_ticker(self, symbol: str):
        ticker = self._catalog.ticker(symbol or "")
        if ticker is None:
            raise NotFoundError("Symbol not found")
        return ticker
