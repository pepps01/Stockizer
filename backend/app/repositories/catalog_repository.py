from sqlalchemy import func, or_

from app.contracts.market_data import SessionInfo, TickerRef
from app.contracts.repositories import ICatalogRepository
from app.extensions import db
from app.models import Country, Exchange, Ticker


class TickerRefMapper:
    """Maps ORM exchanges/tickers to the value objects price sources consume."""

    def __init__(self, *, force_synthetic: bool = False):
        self._force_synthetic = force_synthetic

    @staticmethod
    def session(exchange: Exchange) -> SessionInfo:
        return SessionInfo(
            timezone=exchange.timezone,
            opens_at=exchange.opens_at,
            closes_at=exchange.closes_at,
            trading_days=tuple(exchange.trading_days),
        )

    def source_of(self, ticker: Ticker) -> str:
        return "synthetic" if self._force_synthetic else ticker.data_source

    def ref(self, ticker: Ticker) -> TickerRef:
        return TickerRef(
            symbol=ticker.symbol,
            kind=ticker.kind,
            data_source=self.source_of(ticker),
            exchange_code=ticker.exchange.code,
            base_price=float(ticker.base_price) if ticker.base_price is not None else None,
            session=self.session(ticker.exchange),
        )


class SqlAlchemyCatalogRepository(ICatalogRepository):
    def countries(self) -> list[dict]:
        counts = dict(
            db.session.query(Exchange.country_code, func.count(Exchange.id)).group_by(Exchange.country_code).all()
        )
        rows = Country.query.order_by(Country.name).all()
        return [{**c.to_dict(), "exchange_count": counts[c.code]} for c in rows if counts.get(c.code)]

    def exchanges(self, *, country_code: str | None = None) -> list[Exchange]:
        query = Exchange.query
        if country_code:
            query = query.filter(Exchange.country_code == country_code.upper())
        return query.order_by(Exchange.code).all()

    def exchange(self, code: str) -> Exchange | None:
        return Exchange.query.filter(func.upper(Exchange.code) == code.upper()).first()

    def stock_counts(self) -> dict[str, int]:
        return dict(
            db.session.query(Ticker.exchange_id, func.count(Ticker.id))
            .filter(Ticker.kind == "stock", Ticker.active.is_(True))
            .group_by(Ticker.exchange_id)
            .all()
        )

    def tickers(self, *, kind: str | None = None, exchange_code: str | None = None, country_code: str | None = None) -> list[Ticker]:
        query = Ticker.query.join(Exchange).filter(Ticker.active.is_(True))
        if kind:
            query = query.filter(Ticker.kind == kind)
        if exchange_code:
            query = query.filter(func.upper(Exchange.code) == exchange_code.upper())
        if country_code:
            query = query.filter(Exchange.country_code == country_code.upper())
        return query.order_by(Ticker.display_order, Ticker.display_symbol).all()

    def ticker(self, symbol: str) -> Ticker | None:
        return Ticker.query.filter(func.upper(Ticker.symbol) == symbol.upper()).first()

    def tickers_by_symbols(self, symbols: list[str]) -> list[Ticker]:
        return Ticker.query.filter(func.upper(Ticker.symbol).in_([s.upper() for s in symbols])).all()

    def search(self, text: str, limit: int = 12) -> list[Ticker]:
        text = text.strip()
        query = (
            Ticker.query.join(Exchange)
            .filter(Ticker.active.is_(True))
            .filter(
                or_(
                    Ticker.display_symbol.ilike(f"{text}%"),
                    Ticker.symbol.ilike(f"{text}%"),
                    Ticker.company_name.ilike(f"%{text}%"),
                )
            )
            .order_by(Ticker.kind.desc(), func.length(Ticker.display_symbol), Ticker.display_symbol)
        )
        return query.limit(limit).all()
