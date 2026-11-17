"""Growth vs value, judged against the other stocks on the same exchange.

P/E levels differ a lot between markets (NGX vs Nasdaq), so fixed thresholds
would leave some exchanges with no growth or no value stocks. Instead each
stock is ranked within its exchange on:

    value factors   earnings yield (1 / P/E, profitable firms only), book-to-price
                    (1 / P/B) and dividend yield — high means cheap
    growth factors  revenue growth, earnings growth and the expected EPS growth
                    implied by trailing vs forward P/E — high means fast-growing

value_pct and growth_pct are the mean percentile ranks (0–1) of whichever
factors a stock reports, and style_score = growth_pct − value_pct ∈ [−1, 1].
The top third by style score is "growth", the bottom third "value", the middle
"blend". Stocks with no usable factor on either side stay unclassified.
"""

import math

import pandas as pd

from app.contracts.analytics import IStyleClassifier

STYLES = ("growth", "value", "blend")

# The three stock types investors screen by, shown in the Selector and in an
# index's Financials panel. Equity is the umbrella: growth and value are both equities.
STOCK_TYPES = {
    "growth": {
        "label": "Growth stocks",
        "definition": "Shares in companies expected to grow faster than the rest of the market. They usually reinvest "
                      "their profits in research, expansion and acquisitions instead of paying dividends.",
        "traits": ["High P/E", "Fast revenue & earnings growth", "Little or no dividend", "Often tech, biotech, emerging sectors"],
    },
    "value": {
        "label": "Value stocks",
        "definition": "Shares that appear to trade for less than their intrinsic or book value. Investors buy them "
                      "believing the market is undervaluing the company.",
        "traits": ["Low P/E", "Low price-to-book", "Steady cash flows", "Often pay dividends"],
    },
    "equity": {
        "label": "Equity stocks",
        "definition": "Ownership in a corporation: a claim on the company's assets and earnings. Equity is the umbrella "
                      "term that includes both growth and value stocks, and both common and preferred shares.",
        "traits": ["Every listed stock", "Growth, value and blend", "Common & preferred shares"],
    },
}


class ExchangeRelativeStyleClassifier(IStyleClassifier):
    MIN_STOCKS = 3

    def classify(self, fundamentals: dict[str, dict]) -> dict[str, dict]:
        frame = pd.DataFrame({symbol: self._factors(f or {}) for symbol, f in fundamentals.items()}).T.astype(float)
        result = {symbol: {"style": None, "style_score": None} for symbol in fundamentals}
        if frame.empty:
            return result

        ranks = frame.rank(pct=True)
        value_pct = ranks[["earnings_yield", "book_to_price", "dividend_yield"]].mean(axis=1, skipna=True)
        growth_pct = ranks[["revenue_growth", "earnings_growth", "eps_growth_implied"]].mean(axis=1, skipna=True)
        score = (growth_pct.fillna(0.5) - value_pct.fillna(0.5)).where(value_pct.notna() | growth_pct.notna())
        score = score.dropna()
        if len(score) < self.MIN_STOCKS:
            for symbol, value in score.items():
                result[symbol] = {"style": "blend", "style_score": round(float(value), 4)}
            return result

        order = score.rank(method="first")
        third = len(score) / 3
        for symbol, value in score.items():
            position = order[symbol]
            style = "value" if position <= third else "growth" if position > 2 * third else "blend"
            result[symbol] = {"style": style, "style_score": round(float(value), 4)}
        return result

    @classmethod
    def _factors(cls, f: dict) -> dict:
        pe, forward_pe, pb = cls._num(f.get("pe_ratio")), cls._num(f.get("forward_pe")), cls._num(f.get("price_to_book"))
        return {
            "earnings_yield": 1 / pe if pe and pe > 0 else None,
            "book_to_price": 1 / pb if pb and pb > 0 else None,
            "dividend_yield": cls._num(f.get("dividend_yield")),
            "revenue_growth": cls._num(f.get("revenue_growth")),
            "earnings_growth": cls._num(f.get("earnings_growth")),
            "eps_growth_implied": pe / forward_pe - 1 if pe and forward_pe and pe > 0 and forward_pe > 0 else None,
        }

    @staticmethod
    def _num(value) -> float | None:
        try:
            value = float(value)
        except (TypeError, ValueError):
            return None
        return value if math.isfinite(value) else None
