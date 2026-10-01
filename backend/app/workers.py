import logging
import threading
from abc import ABC, abstractmethod

from flask import Flask

from app.contracts.repositories import IUnitOfWork
from app.contracts.services import IAdviserService, IMarketBoard

logger = logging.getLogger(__name__)


class PeriodicWorker(threading.Thread, ABC):
    """Runs `tick()` inside an app context every `interval` seconds until stopped."""

    def __init__(self, app: Flask, uow: IUnitOfWork, *, name: str, interval: float, run_immediately: bool = False):
        super().__init__(name=name, daemon=True)
        self._app = app
        self._uow = uow
        self._interval = interval
        self._run_immediately = run_immediately
        self._stop_event = threading.Event()

    @abstractmethod
    def tick(self) -> None: ...

    def run(self) -> None:
        logger.info("%s started (every %ss)", self.name, self._interval)
        if self._run_immediately:
            self._safe_tick()
        while not self._stop_event.wait(self._interval):
            self._safe_tick()

    def stop(self) -> None:
        self._stop_event.set()

    def _safe_tick(self) -> None:
        with self._app.app_context():
            try:
                self.tick()
            except Exception:
                logger.exception("%s tick failed", self.name)
                self._uow.rollback()
            finally:
                self._uow.close()


class AdviserWorker(PeriodicWorker):
    """Evaluates due Adviser sessions. Runs inside the API process for
    development (python wsgi.py) or standalone via `flask adviser-worker` —
    run exactly one per database."""

    def __init__(self, app: Flask, adviser: IAdviserService, uow: IUnitOfWork):
        super().__init__(app, uow, name="adviser-worker", interval=app.config["ADVISER_TICK_SECONDS"])
        self._adviser = adviser

    def tick(self) -> None:
        evaluated = self._adviser.run_due()
        if evaluated:
            logger.info("Adviser evaluated %d session(s)", evaluated)


class CacheWarmer(PeriodicWorker):
    """Keeps remote history/quotes warm for the market pages so visitors never
    wait on a cold download."""

    def __init__(self, app: Flask, board: IMarketBoard, uow: IUnitOfWork):
        super().__init__(app, uow, name="cache-warmer", interval=600, run_immediately=True)
        self._board = board

    def tick(self) -> None:
        self._board.warm()
        logger.info("Market caches warmed")
