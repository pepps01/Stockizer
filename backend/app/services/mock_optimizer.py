"""Placeholder Optimizer implementation. Real parameter-estimation logic for the
algorithmic adviser (see product spec Figure 1) is not yet implemented — this
stub keeps the IOptimizer contract and /api/optimizer endpoint stable so the
frontend and future work can integrate against it now."""

from app.contracts.services import IOptimizer


class MockOptimizer(IOptimizer):
    def optimize(self, *, symbol: str, historical_period: str, param_bounds: dict | None = None) -> dict:
        return {
            "symbol": symbol.upper(),
            "historical_period": historical_period,
            "status": "not_implemented",
            "optimal_parameters": {},
            "message": "Optimizer module is a placeholder pending the real parameter-estimation algorithm.",
        }
