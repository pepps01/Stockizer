"""Selector implementation backed by real fundamentals (see
app/repositories/local_fundamentals_repository.py, ~6k tickers across
Dow/S&P500/Nasdaq/Russell). Classification into Growth/Value/Equity and the
ranking-within-a-bucket are still placeholder heuristics pending the real
algebraic selection algorithm from the product spec (Figure 1) — but they now
run over real revenue-growth, ROE/ROA, leverage, and cash/debt data instead of
a single P/E number on a tiny mock list.

Live yfinance data (price, name, sector, description) is fetched only for the
final top_n candidates *after* ranking — running it over the full ~6k universe
per request would be far too slow.
"""

from app.contracts.repositories import FundamentalsRepository
from app.contracts.services import IMarketDataProvider, IStockSelector

GROWTH_REVENUE_GROWTH_THRESHOLD = 15.0
VALUE_RETURN_ON_EQUITY_THRESHOLD = 12.0


def _classify(record: dict) -> str:
    revenue_growth = record.get("quarterly_revenue_growth") or 0
    return_on_equity = record.get("return_on_equity") or 0
    total_cash = record.get("total_cash") or 0
    total_debt = record.get("total_debt") or 0

    if revenue_growth >= GROWTH_REVENUE_GROWTH_THRESHOLD:
        return "growth"
    if return_on_equity >= VALUE_RETURN_ON_EQUITY_THRESHOLD and total_cash >= total_debt:
        return "value"
    return "equity"


class MockStockSelector(IStockSelector):
    def __init__(self, fundamentals_repository: FundamentalsRepository, market_data: IMarketDataProvider):
        self._fundamentals = fundamentals_repository
        self._market_data = market_data

    def select(self, *, stock_type: str, top_n: int = 10) -> list[dict]:
        stock_type = stock_type.lower()

        candidates = [r for r in self._fundamentals.list_all() if _classify(r) == stock_type]
        candidates.sort(key=lambda r: (r.get("score") or 0, r.get("return_on_equity") or 0), reverse=True)
        top_candidates = candidates[:top_n]

        symbols = [c["symbol"] for c in top_candidates]
        quotes = self._market_data.get_quotes(symbols)
        profiles = self._market_data.get_company_profiles_batch(symbols)

        results = []
        for candidate in top_candidates:
            symbol = candidate["symbol"]
            quote = quotes.get(symbol, {})
            profile = profiles.get(symbol, {})
            change_percent = quote.get("change_percent") or 0
            action = "buy" if change_percent > 0 else "sell" if change_percent < 0 else "hold"

            results.append(
                {
                    "symbol": symbol,
                    "name": profile.get("name") or symbol,
                    "description": profile.get("description"),
                    "sector": profile.get("sector"),
                    "country": profile.get("country"),
                    "index_memberships": candidate["index_memberships"],
                    "stock_type": stock_type,
                    "price": quote.get("price"),
                    "change_percent": quote.get("change_percent"),
                    "score": candidate.get("score"),
                    "recommended_action": action,
                }
            )

        return results
