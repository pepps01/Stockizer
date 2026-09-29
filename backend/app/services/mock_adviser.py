"""Placeholder Adviser implementation. Real algebraic decision-signal generation
(see product spec Figure 1) is not yet implemented — this stub keeps the IAdviser
contract and /api/adviser endpoint stable so the frontend and future work can
integrate against it now."""

from app.contracts.services import IAdviser


class MockAdviser(IAdviser):
    def get_signal(self, *, symbol: str) -> dict:
        return {
            "symbol": symbol.upper(),
            "signal": "hold",
            "confidence": None,
            "status": "not_implemented",
            "message": "Adviser module is a placeholder pending the real algorithmic decision-signal engine.",
        }
