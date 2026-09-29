import logging
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
from zoneinfo import ZoneInfo

import yfinance as yf

MAX_WORKERS = 8

from app.contracts.services import IMarketDataProvider

logger = logging.getLogger(__name__)


def _safe_float(value) -> float | None:
    try:
        return float(value) if value is not None else None
    except (TypeError, ValueError):
        return None


class YFinanceMarketDataProvider(IMarketDataProvider):
    def get_quote(self, symbol: str) -> dict:
        try:
            info = yf.Ticker(symbol).fast_info
            price = _safe_float(getattr(info, "last_price", None))
            prev_close = _safe_float(getattr(info, "previous_close", None))
            change = price - prev_close if price is not None and prev_close is not None else None
            change_percent = (change / prev_close * 100) if change is not None and prev_close else None
            return {
                "symbol": symbol.upper(),
                "price": price,
                "previous_close": prev_close,
                "change": change,
                "change_percent": change_percent,
                "currency": getattr(info, "currency", None),
            }
        except Exception:
            logger.warning("yfinance quote lookup failed for %s", symbol, exc_info=True)
            return {
                "symbol": symbol.upper(),
                "price": None,
                "previous_close": None,
                "change": None,
                "change_percent": None,
                "currency": None,
            }

    def get_quotes(self, symbols: list[str]) -> dict[str, dict]:
        if not symbols:
            return {}
        with ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
            quotes = list(pool.map(self.get_quote, symbols))
        return {quote["symbol"]: quote for quote in quotes}

    def get_financials_batch(self, symbols: list[str]) -> dict[str, dict]:
        if not symbols:
            return {}
        with ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
            results = list(pool.map(self.get_financials, symbols))
        return {result["symbol"]: result for result in results}

    def get_financials(self, symbol: str) -> dict:
        try:
            info = yf.Ticker(symbol).get_info()
        except Exception:
            logger.warning("yfinance financials lookup failed for %s", symbol, exc_info=True)
            info = {}

        return {
            "symbol": symbol.upper(),
            "pe_ratio": _safe_float(info.get("trailingPE")),
            "forward_pe": _safe_float(info.get("forwardPE")),
            "market_cap": _safe_float(info.get("marketCap")),
            "eps": _safe_float(info.get("trailingEps")),
            "dividend_yield": _safe_float(info.get("dividendYield")),
            "fifty_two_week_high": _safe_float(info.get("fiftyTwoWeekHigh")),
            "fifty_two_week_low": _safe_float(info.get("fiftyTwoWeekLow")),
        }

    def get_history(self, symbol: str, *, period: str = "1mo", interval: str = "1d") -> list[dict]:
        try:
            hist = yf.Ticker(symbol).history(period=period, interval=interval)
            points = []
            for index, row in hist.iterrows():
                value = _safe_float(row["Close"])
                if value is not None:
                    points.append({"time": index.strftime("%Y-%m-%d"), "value": value})
            return points
        except Exception:
            logger.warning("yfinance history lookup failed for %s", symbol, exc_info=True)
            return []

    def get_company_profile(self, symbol: str) -> dict:
        try:
            info = yf.Ticker(symbol).get_info()
        except Exception:
            logger.warning("yfinance profile lookup failed for %s", symbol, exc_info=True)
            info = {}

        description = info.get("longBusinessSummary")
        return {
            "symbol": symbol.upper(),
            "name": info.get("shortName") or info.get("longName"),
            "sector": info.get("sector"),
            "country": info.get("country"),
            "description": (description[:280] + "…") if description and len(description) > 280 else description,
        }

    def get_company_profiles_batch(self, symbols: list[str]) -> dict[str, dict]:
        if not symbols:
            return {}
        with ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
            profiles = list(pool.map(self.get_company_profile, symbols))
        return {profile["symbol"]: profile for profile in profiles}

    def is_market_open(self, exchange: dict) -> bool:
        try:
            tz = ZoneInfo(exchange["timezone"])
            now = datetime.now(tz)
            if now.weekday() not in exchange.get("trading_days", [0, 1, 2, 3, 4]):
                return False

            open_h, open_m = map(int, exchange["open_time"].split(":"))
            close_h, close_m = map(int, exchange["close_time"].split(":"))
            open_minutes = open_h * 60 + open_m
            close_minutes = close_h * 60 + close_m
            now_minutes = now.hour * 60 + now.minute
            return open_minutes <= now_minutes < close_minutes
        except Exception:
            logger.warning("market-open check failed for exchange %s", exchange.get("code"), exc_info=True)
            return False
