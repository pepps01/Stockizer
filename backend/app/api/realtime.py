"""WebSocket gateway (/ws): live quotes for subscribed symbols and, for a
signed-in user, their Adviser signals the moment they are emitted.

Protocol (JSON text frames)
  client → server  {"type": "subscribe",   "symbols": ["AAPL", "DANGCEM.NGX"]}
                   {"type": "unsubscribe", "symbols": [...]}
                   {"type": "ping"}
  server → client  {"type": "welcome", "authenticated": bool}
                   {"type": "quotes",  "quotes": {symbol: quote}}   (only changed quotes)
                   {"type": "signal",  "signal": {...}}
                   {"type": "pong"} | {"type": "error", "message": str}

Browsers can't set headers on WebSocket upgrades, so the JWT (optional)
travels as ?token=… and the Origin header is checked against the CORS allow-list.
"""

import json
import logging
import time
from datetime import timedelta

from flask import request
from flask_jwt_extended import decode_token
from simple_websocket import ConnectionClosed

from app.api.base import CorsPolicy
from app.contracts.repositories import ICatalogRepository, IUnitOfWork
from app.contracts.services import IAdviserService, IMarketDataService
from app.models.base import utcnow

logger = logging.getLogger(__name__)


class RealtimeSession:
    """State and loop for one connected socket."""

    MAX_SYMBOLS = 100
    RECEIVE_TIMEOUT_SECONDS = 1.0
    QUOTE_INTERVAL_SECONDS = 3.0
    SIGNAL_INTERVAL_SECONDS = 2.0

    def __init__(self, ws, user_id: str | None, catalog: ICatalogRepository, market_data: IMarketDataService, adviser: IAdviserService, uow: IUnitOfWork):
        self._ws = ws
        self._user_id = user_id
        self._catalog = catalog
        self._data = market_data
        self._adviser = adviser
        self._uow = uow
        self._symbols: set[str] = set()
        self._last_sent: dict[str, tuple] = {}
        self._signals_since = utcnow() - timedelta(seconds=1)
        self._sent_signal_ids: set[str] = set()

    def run(self) -> None:
        self._send({"type": "welcome", "authenticated": self._user_id is not None})
        next_quotes = next_signals = 0.0
        try:
            while True:
                message = self._ws.receive(timeout=self.RECEIVE_TIMEOUT_SECONDS)
                if message is not None:
                    self._handle(message)
                now = time.monotonic()
                if self._symbols and now >= next_quotes:
                    next_quotes = now + self.QUOTE_INTERVAL_SECONDS
                    self._push_quotes()
                if self._user_id and now >= next_signals:
                    next_signals = now + self.SIGNAL_INTERVAL_SECONDS
                    self._push_signals()
                self._uow.close()
        except ConnectionClosed:
            pass

    def _handle(self, raw: str) -> None:
        try:
            message = json.loads(raw)
        except (TypeError, ValueError):
            return self._send({"type": "error", "message": "Messages must be JSON"})
        kind = message.get("type")
        symbols = {str(s).upper() for s in message.get("symbols") or []}
        if kind == "subscribe":
            self._symbols |= symbols
            if len(self._symbols) > self.MAX_SYMBOLS:
                self._symbols = set(list(self._symbols)[: self.MAX_SYMBOLS])
                self._send({"type": "error", "message": f"At most {self.MAX_SYMBOLS} symbols per connection"})
            self._push_quotes(force=symbols)
        elif kind == "unsubscribe":
            self._symbols -= symbols
            for symbol in symbols:
                self._last_sent.pop(symbol, None)
        elif kind == "ping":
            self._send({"type": "pong"})
        else:
            self._send({"type": "error", "message": f"Unknown message type '{kind}'"})

    def _push_quotes(self, force: set[str] | None = None) -> None:
        tickers = self._catalog.tickers_by_symbols(list(self._symbols))
        changed = {}
        for symbol, quote in self._data.quotes(tickers).items():
            fingerprint = (quote.get("price"), quote.get("volume"), quote.get("market_open"))
            if (force and symbol in force) or self._last_sent.get(symbol) != fingerprint:
                self._last_sent[symbol] = fingerprint
                changed[symbol] = quote
        if changed:
            self._send({"type": "quotes", "quotes": changed})

    def _push_signals(self) -> None:
        # Overlap the window by a second and de-duplicate by id, so signals
        # sharing a timestamp with the previous page are never skipped.
        fresh = [s for s in self._adviser.signals(self._user_id, since=self._signals_since) if s.id not in self._sent_signal_ids]
        for signal in reversed(fresh):
            self._send({"type": "signal", "signal": signal.to_dict()})
        if fresh:
            self._signals_since = fresh[0].emitted_at - timedelta(seconds=1)
            self._sent_signal_ids |= {s.id for s in fresh}
            if len(self._sent_signal_ids) > 1000:  # older ids have left the window
                self._sent_signal_ids = {s.id for s in fresh}

    def _send(self, payload: dict) -> None:
        self._ws.send(json.dumps(payload))


class RealtimeGateway:
    """Accepts /ws connections: validates Origin and the optional token, then
    hands the socket to a RealtimeSession."""

    PATH = "/ws"
    POLICY_VIOLATION = 1008

    def __init__(self, cors: CorsPolicy, catalog: ICatalogRepository, market_data: IMarketDataService, adviser: IAdviserService, uow: IUnitOfWork):
        self._cors = cors
        self._catalog = catalog
        self._data = market_data
        self._adviser = adviser
        self._uow = uow

    def register(self, sock) -> None:
        sock.route(self.PATH, endpoint="realtime")(self.handle)

    def handle(self, ws) -> None:
        if not self._cors.is_allowed_origin(request.headers.get("Origin")):
            ws.close(reason=self.POLICY_VIOLATION, message="Origin not allowed")
            return
        user_id = self._authenticate(request.args.get("token"))
        if user_id is False:
            ws.close(reason=self.POLICY_VIOLATION, message="Invalid token")
            return
        RealtimeSession(ws, user_id, self._catalog, self._data, self._adviser, self._uow).run()

    @staticmethod
    def _authenticate(token: str | None) -> str | None | bool:
        """User id for a valid token, None when anonymous, False when the token is bad."""
        if not token:
            return None
        try:
            return decode_token(token)["sub"]
        except Exception:
            return False
