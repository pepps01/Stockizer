from flask import Blueprint, jsonify, request

from app.container import get_container

bp = Blueprint("markets", __name__, url_prefix="/api")


@bp.get("/exchanges")
def list_exchanges():
    container = get_container()
    exchanges = container.exchange_repository.list_all()
    return jsonify(
        exchanges=[
            {**exchange, "is_open": container.market_data.is_market_open(exchange)} for exchange in exchanges
        ]
    )


@bp.get("/exchanges/<code>/tickers")
def list_exchange_tickers(code):
    container = get_container()
    exchange = container.exchange_repository.get_by_code(code)
    if exchange is None:
        return jsonify(error="Exchange not found"), 404

    tickers = container.ticker_repository.list_by_exchange(code)
    quotes = container.market_data.get_quotes([t["symbol"] for t in tickers])

    return jsonify(
        exchange={**exchange, "is_open": container.market_data.is_market_open(exchange)},
        tickers=[{**ticker, **quotes.get(ticker["symbol"], {})} for ticker in tickers],
    )


def _resolve_ticker_meta(container, symbol: str) -> dict | None:
    """Looks up display metadata (name/sector/country/description) for a symbol.
    Checks the curated directory first (exchange-listed tickers + indices), then
    falls back to a live yfinance company-profile lookup so any symbol from the
    larger fundamentals universe (see Selector) is viewable too."""

    ticker = container.ticker_repository.get_by_symbol(symbol)
    if ticker is not None:
        return ticker

    profile = container.market_data.get_company_profile(symbol)
    if not profile.get("name"):
        return None

    return {
        "symbol": symbol.upper(),
        "name": profile["name"],
        "exchange": None,
        "sector": profile.get("sector"),
        "country": profile.get("country"),
        "description": profile.get("description"),
    }


@bp.get("/tickers/<symbol>")
def get_ticker(symbol):
    container = get_container()
    ticker = _resolve_ticker_meta(container, symbol)
    if ticker is None:
        return jsonify(error="Ticker not found"), 404

    quote = container.market_data.get_quote(symbol)
    financials = container.market_data.get_financials(symbol)
    return jsonify(ticker={**ticker, **quote, **financials})


@bp.get("/tickers/<symbol>/history")
def get_ticker_history(symbol):
    period = request.args.get("period", "1mo")
    interval = request.args.get("interval", "1d")
    history = get_container().market_data.get_history(symbol, period=period, interval=interval)
    return jsonify(symbol=symbol.upper(), period=period, interval=interval, history=history)


@bp.get("/tickers/<symbol>/financials")
def get_ticker_financials(symbol):
    financials = get_container().market_data.get_financials(symbol)
    return jsonify(symbol=symbol.upper(), financials=financials)
