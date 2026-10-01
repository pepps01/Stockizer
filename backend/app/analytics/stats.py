"""Return-series statistics shared by the Selector (ranking) and Optimizer (objectives)."""

import numpy as np
import pandas as pd

from app.contracts.analytics import IReturnStatistics


class ReturnStatistics(IReturnStatistics):
    TRADING_DAYS = 252
    KEYS = ("total_return", "cagr", "volatility", "sharpe", "sortino", "max_drawdown", "calmar")

    def from_series(self, returns: pd.Series) -> dict:
        return self.from_array(returns.dropna().to_numpy(dtype=float))

    def from_array(self, returns: np.ndarray) -> dict:
        if returns.size == 0:
            return {k: 0.0 for k in self.KEYS}

        equity = np.cumprod(1 + returns)
        final = float(equity[-1])
        years = returns.size / self.TRADING_DAYS
        cagr = final ** (1 / years) - 1 if years > 0 and final > 0 else -1.0
        std = float(returns.std(ddof=1)) if returns.size > 1 else 0.0
        mean = float(returns.mean())
        annualise = np.sqrt(self.TRADING_DAYS)
        sharpe = mean / std * annualise if std > 0 else 0.0
        downside = returns[returns < 0]
        downside_std = float(np.sqrt((downside**2).mean())) if downside.size else 0.0
        sortino = mean / downside_std * annualise if downside_std > 0 else 0.0
        mdd = float((equity / np.maximum.accumulate(equity) - 1).min())
        return {
            "total_return": final - 1,
            "cagr": float(cagr),
            "volatility": std * annualise,
            "sharpe": float(sharpe),
            "sortino": float(sortino),
            "max_drawdown": mdd,
            "calmar": float(cagr / abs(mdd)) if mdd < 0 else 0.0,
        }
