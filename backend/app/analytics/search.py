from typing import Callable

import numpy as np

from app.contracts.analytics import IParameterSearch


class RandomRefineSearch(IParameterSearch):
    """Seeded random sampling over the bounds, then a shrinking Gaussian local
    search around the incumbent. Deterministic for a given seed."""

    def __init__(self, *, samples: int = 150, refine_steps: int = 60, initial: dict | None = None):
        self._samples = samples
        self._refine_steps = refine_steps
        self._initial = initial

    def search(self, objective: Callable[[dict], float], bounds: dict, seed: int) -> tuple[float, dict, int]:
        rng = np.random.default_rng(seed)
        names = list(bounds)

        candidates = [dict(self._initial)] if self._initial else []
        candidates += [{n: rng.uniform(*bounds[n]) for n in names} for _ in range(self._samples)]
        scored = [(objective(c), c) for c in candidates]
        best_score, best = max(scored, key=lambda item: item[0])

        for step in range(self._refine_steps):
            scale = 0.15 * (1 - step / self._refine_steps) + 0.02
            trial = {
                n: float(np.clip(best[n] + rng.normal(0, scale * (bounds[n][1] - bounds[n][0])), *bounds[n]))
                for n in names
            }
            score = objective(trial)
            if score > best_score:
                best_score, best = score, trial
        return best_score, best, len(candidates) + self._refine_steps
