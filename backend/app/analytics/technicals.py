"""TradingView-style technical rating from daily OHLC bars.

Moving averages vote +1 (price above) / -1 (price below); oscillators vote by
their classic buy/sell conditions. Each group's rating is the mean vote in
[-1, 1]; the summary is the mean of both groups.
"""

from datetime import date, timedelta

import numpy as np
import pandas as pd

from app.contracts.analytics import ITechnicalAnalyzer


class TechnicalAnalyzer(ITechnicalAnalyzer):
    MA_PERIODS = (10, 20, 30, 50, 100, 200)
    MIN_BARS = 30

    @staticmethod
    def label(value: float | None) -> str | None:
        if value is None or np.isnan(value):
            return None
        if value > 0.5:
            return "Strong buy"
        if value > 0.1:
            return "Buy"
        if value >= -0.1:
            return "Neutral"
        if value >= -0.5:
            return "Sell"
        return "Strong sell"

    def rating(self, bars: pd.DataFrame | None) -> dict:
        if bars is None or len(bars) < self.MIN_BARS:
            return {"summary": None, "moving_averages": None, "oscillators": None, "label": None,
                    "ma_label": None, "osc_label": None, "indicators": {}}

        close = bars["close"]
        ma_votes, indicators = self._moving_average_votes(close)
        osc_votes, osc_indicators = self._oscillator_votes(bars)
        indicators.update(osc_indicators)

        ma_rating = float(np.mean(ma_votes)) if ma_votes else 0.0
        osc_rating = float(np.mean(osc_votes))
        summary = (ma_rating + osc_rating) / 2
        return {
            "summary": round(summary, 4),
            "moving_averages": round(ma_rating, 4),
            "oscillators": round(osc_rating, 4),
            "label": self.label(summary),
            "ma_label": self.label(ma_rating),
            "osc_label": self.label(osc_rating),
            "indicators": indicators,
        }

    def performance(self, bars: pd.DataFrame | None) -> dict:
        if bars is None or bars.empty:
            return {}
        close = bars["close"]
        last_day = close.index[-1]
        price = close.iloc[-1]

        def since(start: date) -> float | None:
            prior = close[close.index <= start]
            return None if prior.empty else float((price / prior.iloc[-1] - 1) * 100)

        returns = np.log(close).diff().dropna().tail(21)
        return {
            "perf_1w": since(last_day - timedelta(days=7)),
            "perf_1m": since(last_day - timedelta(days=30)),
            "perf_3m": since(last_day - timedelta(days=91)),
            "perf_6m": since(last_day - timedelta(days=182)),
            "perf_ytd": since(date(last_day.year - 1, 12, 31)),
            "perf_1y": since(last_day - timedelta(days=365)),
            "volatility_1m": float(returns.std() * np.sqrt(252) * 100) if len(returns) > 5 else None,
        }

    # ---- internals -----------------------------------------------------------------------

    def _moving_average_votes(self, close: pd.Series) -> tuple[list[int], dict]:
        price = close.iloc[-1]
        votes, indicators = [], {}
        for period in self.MA_PERIODS:
            if len(close) < period:
                continue
            sma = close.rolling(period).mean().iloc[-1]
            ema = close.ewm(span=period, adjust=False).mean().iloc[-1]
            votes += [self._vote(price > sma, price < sma), self._vote(price > ema, price < ema)]
            indicators[f"sma{period}"] = float(sma)
            indicators[f"ema{period}"] = float(ema)
        return votes, indicators

    def _oscillator_votes(self, bars: pd.DataFrame) -> tuple[list[int], dict]:
        close, high, low = bars["close"], bars["high"], bars["low"]
        rsi = self._rsi(close)
        lowest, highest = low.rolling(14).min(), high.rolling(14).max()
        stoch_k = (100 * (close - lowest) / (highest - lowest)).rolling(3).mean()
        stoch_d = stoch_k.rolling(3).mean()
        typical = (high + low + close) / 3
        cci = (typical - typical.rolling(20).mean()) / (0.015 * self._mean_abs_deviation(typical, 20))
        macd = close.ewm(span=12, adjust=False).mean() - close.ewm(span=26, adjust=False).mean()
        macd_signal = macd.ewm(span=9, adjust=False).mean()
        momentum = close - close.shift(10)
        williams = -100 * (highest - close) / (highest - lowest)

        v = self._vote
        votes = [
            v(rsi.iloc[-1] < 30 and rsi.iloc[-1] > rsi.iloc[-2], rsi.iloc[-1] > 70 and rsi.iloc[-1] < rsi.iloc[-2]),
            v(stoch_k.iloc[-1] < 20 and stoch_k.iloc[-1] > stoch_d.iloc[-1], stoch_k.iloc[-1] > 80 and stoch_k.iloc[-1] < stoch_d.iloc[-1]),
            v(cci.iloc[-1] < -100 and cci.iloc[-1] > cci.iloc[-2], cci.iloc[-1] > 100 and cci.iloc[-1] < cci.iloc[-2]),
            v(macd.iloc[-1] > macd_signal.iloc[-1], macd.iloc[-1] < macd_signal.iloc[-1]),
            v(momentum.iloc[-1] > momentum.iloc[-2], momentum.iloc[-1] < momentum.iloc[-2]),
            v(williams.iloc[-1] < -80 and williams.iloc[-1] > williams.iloc[-2], williams.iloc[-1] > -20 and williams.iloc[-1] < williams.iloc[-2]),
        ]
        if len(close) >= 34:
            median = (high + low) / 2
            awesome = median.rolling(5).mean() - median.rolling(34).mean()
            votes.append(v(awesome.iloc[-1] > 0 and awesome.iloc[-1] > awesome.iloc[-2], awesome.iloc[-1] < 0 and awesome.iloc[-1] < awesome.iloc[-2]))

        indicators = {
            "rsi14": self._f(rsi.iloc[-1]),
            "stoch_k": self._f(stoch_k.iloc[-1]),
            "cci20": self._f(cci.iloc[-1]),
            "macd": self._f(macd.iloc[-1]),
            "macd_signal": self._f(macd_signal.iloc[-1]),
            "momentum10": self._f(momentum.iloc[-1]),
            "williams_r": self._f(williams.iloc[-1]),
        }
        return votes, indicators

    @staticmethod
    def _vote(buy: bool, sell: bool) -> int:
        return 1 if buy else -1 if sell else 0

    @staticmethod
    def _rsi(close: pd.Series, period: int = 14) -> pd.Series:
        delta = close.diff()
        gain = delta.clip(lower=0).ewm(alpha=1 / period, adjust=False).mean()
        loss = (-delta.clip(upper=0)).ewm(alpha=1 / period, adjust=False).mean()
        return 100 - 100 / (1 + gain / loss.replace(0, np.nan))

    @staticmethod
    def _mean_abs_deviation(series: pd.Series, window: int) -> pd.Series:
        values = series.to_numpy(dtype=float)
        out = np.full(len(values), np.nan)
        if len(values) >= window:
            windows = np.lib.stride_tricks.sliding_window_view(values, window)
            out[window - 1 :] = np.abs(windows - windows.mean(axis=1, keepdims=True)).mean(axis=1)
        return pd.Series(out, index=series.index)

    @staticmethod
    def _f(value) -> float | None:
        return None if value is None or pd.isna(value) else float(value)
