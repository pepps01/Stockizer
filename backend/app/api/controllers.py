"""REST controllers. Each receives the service interfaces it needs through its
constructor and exposes them as JSON endpoints under /api."""

from flask import send_file

from app.api.base import Controller
from app.contracts.repositories import ICatalogRepository
from app.contracts.services import (
    IAccountService,
    IAdminService,
    IAdviserService,
    IArtifactStore,
    IAuthService,
    IMarketBoard,
    IMarketDataService,
    IOptimizerService,
    ISelectorService,
)
from app.domain.errors import NotFoundError


class AuthController(Controller):
    name, url_prefix = "auth", "/api/auth"

    def __init__(self, auth: IAuthService):
        self._auth = auth
        super().__init__()

    def register_routes(self) -> None:
        self.route("/register", self.register, methods=["POST"], limit="10 per minute")
        self.route("/verify-email", self.verify_email)
        self.route("/login", self.login, methods=["POST"], limit="10 per minute")
        self.route("/me", self.me, auth=True)
        self.route("/me", self.update_me, methods=["PUT"], auth=True)

    def register(self):
        data = self.params.json()
        user = self._auth.register(
            first_name=data.get("first_name") or "",
            last_name=data.get("last_name") or "",
            email=data.get("email") or "",
            password=data.get("password") or "",
        )
        return self.ok(user=user, code=201)

    def verify_email(self):
        return self.ok(user=self._auth.verify_email(self.params.arg("token") or ""))

    def login(self):
        data = self.params.json()
        return self.ok(self._auth.login(email=data.get("email") or "", password=data.get("password") or ""))

    def me(self):
        return self.ok(user=self._auth.get_profile(self.user_id()))

    def update_me(self):
        return self.ok(user=self._auth.update_profile(self.user_id(), self.params.json()))


class MarketsController(Controller):
    name, url_prefix = "markets", "/api"

    def __init__(self, catalog: ICatalogRepository, board: IMarketBoard, market_data: IMarketDataService, adviser: IAdviserService):
        self._catalog = catalog
        self._board = board
        self._data = market_data
        self._adviser = adviser
        super().__init__()

    def register_routes(self) -> None:
        self.route("/health", self.health)
        self.route("/countries", self.countries)
        self.route("/exchanges", self.exchanges)
        self.route("/exchanges/<code>", self.exchange)
        self.route("/indices", self.indices)
        self.route("/movers", self.movers)
        self.route("/search", self.search)
        self.route("/symbols/<path:symbol>/history", self.history)
        self.route("/symbols/<path:symbol>/signal", self.signal)
        self.route("/symbols/<path:symbol>/members", self.index_members)
        self.route("/symbols/<path:symbol>/financials", self.index_financials, limit="30 per minute")
        self.route("/symbols/<path:symbol>", self.symbol)

    def health(self):
        return self.ok(status="ok")

    def countries(self):
        return self.ok(countries=self._catalog.countries())

    def exchanges(self):
        counts = self._catalog.stock_counts()
        rows = self._catalog.exchanges(country_code=self.params.arg("country"))
        return self.ok(exchanges=[{**e.to_dict(), **self._data.market_status(e), "stock_count": counts.get(e.id, 0)} for e in rows])

    def exchange(self, code):
        return self.ok(self._board.exchange_listing(code))

    def indices(self):
        return self.ok(indices=self._board.indices(country_code=self.params.arg("country")))

    def movers(self):
        limit = self.params.int(self.params.arg("limit"), "limit", 6, low=1, high=25)
        return self.ok(self._board.movers(country_code=self.params.arg("country"), exchange_code=self.params.arg("exchange"), limit=limit))

    def search(self):
        text = (self.params.arg("q") or "").strip()
        return self.ok(results=[t.to_dict() for t in self._catalog.search(text)] if text else [])

    def symbol(self, symbol):
        return self.ok(self._board.symbol_detail(symbol))

    def index_members(self, symbol):
        return self.ok(self._board.index_members(symbol))

    def index_financials(self, symbol):
        return self.ok(self._board.index_financials(symbol))

    def history(self, symbol):
        return self.ok(self._board.history(symbol, self.params.arg("range") or "1Y"))

    def signal(self, symbol):
        """Current Adviser signal for any symbol: the caller's latest optimised
        parameters for this ticker when signed in, otherwise engine defaults."""
        return self.ok(self._adviser.signal_for(symbol, user_id=self.optional_user_id(), optimizer_run_id=self.params.arg("optimizer_run_id")))


class SelectorController(Controller):
    name, url_prefix = "selector", "/api/selector"

    def __init__(self, selector: ISelectorService):
        self._selector = selector
        super().__init__()

    def register_routes(self) -> None:
        self.route("/options", self.options)
        self.route("/runs", self.create_run, methods=["POST"], auth=True, limit="20 per minute")
        self.route("/runs", self.list_runs, auth=True)
        self.route("/runs/<run_id>", self.get_run, auth=True)

    def options(self):
        return self.ok(self._selector.options())

    def create_run(self):
        data = self.params.json()
        start, end = self._selector.default_period()
        run = self._selector.run(
            user_id=self.user_id(),
            exchange_code=data.get("exchange") or "",
            period_start=self.params.date(data.get("period_start"), "period_start", start),
            period_end=self.params.date(data.get("period_end"), "period_end", end),
            metric=data.get("metric") or "sharpe",
            top_n=self.params.int(data.get("top_n"), "top_n", 10),
            stock_type=data.get("stock_type") or "equity",
        )
        return self.ok(run=run.to_dict(), code=201)

    def list_runs(self):
        return self.ok(runs=[r.to_dict(with_results=False) for r in self._selector.list_runs(self.user_id())])

    def get_run(self, run_id):
        run = self._selector.get_run(self.user_id(), run_id)
        if run is None:
            raise NotFoundError("Selector run not found")
        return self.ok(run=run.to_dict())


class OptimizerController(Controller):
    name, url_prefix = "optimizer", "/api/optimizer"

    def __init__(self, optimizer: IOptimizerService):
        self._optimizer = optimizer
        super().__init__()

    def register_routes(self) -> None:
        self.route("/options", self.options)
        self.route("/runs", self.create_runs, methods=["POST"], auth=True, limit="10 per minute")
        self.route("/runs", self.list_runs, auth=True)
        self.route("/runs/<run_id>", self.get_run, auth=True)

    def options(self):
        return self.ok(self._optimizer.options())

    def create_runs(self):
        data = self.params.json()
        symbols = data.get("symbols") or ([data["symbol"]] if data.get("symbol") else [])
        runs = self._optimizer.run(
            user_id=self.user_id(),
            symbols=symbols,
            selector_run_id=data.get("selector_run_id"),
            top_k=self.params.int(data.get("top_k"), "top_k", 0) or None,
            training_start=self.params.date(data.get("training_start"), "training_start"),
            training_end=self.params.date(data.get("training_end"), "training_end"),
            objective=data.get("objective") or "sharpe",
            bounds=data.get("bounds"),
            strategy=data.get("strategy") or "algebraic",
        )
        return self.ok(runs=[r.to_dict() for r in runs], code=201)

    def list_runs(self):
        return self.ok(runs=[r.to_dict() for r in self._optimizer.list_runs(self.user_id(), symbol=self.params.arg("symbol"))])

    def get_run(self, run_id):
        run = self._optimizer.get_run(self.user_id(), run_id)
        if run is None:
            raise NotFoundError("Optimizer run not found")
        return self.ok(run=run.to_dict(with_curves=True))


class ArtifactController(Controller):
    name, url_prefix = "artifacts", "/api/artifacts"

    def __init__(self, store: IArtifactStore):
        self._store = store
        super().__init__()

    def register_routes(self) -> None:
        self.route("/<artifact_id>/download", self.download, auth=True)

    def download(self, artifact_id):
        artifact = self._store.get_owned(artifact_id, self.user_id())
        if artifact is None:
            raise NotFoundError("File not found")
        return send_file(self._store.path(artifact), mimetype=artifact.content_type, as_attachment=True, download_name=artifact.filename)


class AdviserController(Controller):
    name, url_prefix = "adviser", "/api/adviser"

    def __init__(self, adviser: IAdviserService):
        self._adviser = adviser
        super().__init__()

    def register_routes(self) -> None:
        self.route("/sessions", self.list_sessions, auth=True)
        self.route("/sessions", self.create_session, methods=["POST"], auth=True, limit="30 per minute")
        self.route("/sessions/<session_id>", self.update_session, methods=["PATCH"], auth=True)
        self.route("/sessions/<session_id>/evaluate", self.evaluate_session, methods=["POST"], auth=True, limit="30 per minute")
        self.route("/signals", self.list_signals, auth=True)

    def list_sessions(self):
        return self.ok(sessions=[s.to_dict() for s in self._adviser.list_sessions(self.user_id())])

    def create_session(self):
        data = self.params.json()
        session = self._adviser.create_session(
            user_id=self.user_id(),
            symbol=data.get("symbol") or "",
            interval_sec=self.params.int(data.get("interval_sec"), "interval_sec", 300),
            optimizer_run_id=data.get("optimizer_run_id"),
        )
        return self.ok(session=session.to_dict(), code=201)

    def update_session(self, session_id):
        session = self._adviser.get_session(self.user_id(), session_id)
        data = self.params.json()
        if "status" in data:
            self._adviser.set_status(session, data["status"])
        return self.ok(session=session.to_dict())

    def evaluate_session(self, session_id):
        session = self._adviser.get_session(self.user_id(), session_id)
        signal = self._adviser.evaluate_session(session)
        return self.ok(session=session.to_dict(), signal=signal.to_dict() if signal else None)

    def list_signals(self):
        signals = self._adviser.signals(
            self.user_id(),
            session_id=self.params.arg("session_id"),
            limit=self.params.int(self.params.arg("limit"), "limit", 50, low=1, high=200),
        )
        return self.ok(signals=[s.to_dict() for s in signals])


class AccountController(Controller):
    name, url_prefix = "account", "/api"

    def __init__(self, account: IAccountService):
        self._account = account
        super().__init__()

    def register_routes(self) -> None:
        self.route("/watchlist", self.watchlist, auth=True)
        self.route("/watchlist", self.add_to_watchlist, methods=["POST"], auth=True)
        self.route("/watchlist/<path:symbol>", self.remove_from_watchlist, methods=["DELETE"], auth=True)
        self.route("/actions", self.record_action, methods=["POST"], auth=True)
        self.route("/actions", self.actions, auth=True)
        self.route("/assumptions", self.assumptions, auth=True)
        self.route("/assumptions/<path:symbol>", self.set_assumption, methods=["PUT"], auth=True, limit="60 per minute")
        self.route("/assumptions/<path:symbol>", self.clear_assumption, methods=["DELETE"], auth=True)
        self.route("/devices", self.register_device, methods=["POST"], auth=True, limit="30 per minute")
        self.route("/devices", self.unregister_device, methods=["DELETE"], auth=True)

    def watchlist(self):
        return self.ok(items=self._account.watchlist(self.user_id()))

    def add_to_watchlist(self):
        return self.ok(symbol=self._account.add_to_watchlist(self.user_id(), self.params.json().get("symbol") or ""), code=201)

    def remove_from_watchlist(self, symbol):
        self._account.remove_from_watchlist(self.user_id(), symbol)
        return "", 204

    def record_action(self):
        data = self.params.json()
        return self.ok(action=self._account.record_action(self.user_id(), data.get("symbol") or "", data.get("action") or ""), code=201)

    def actions(self):
        return self.ok(actions=self._account.actions(self.user_id()))

    def assumptions(self):
        return self.ok(assumptions=self._account.assumptions(self.user_id()))

    def set_assumption(self, symbol):
        return self.ok(assumption=self._account.set_assumption(self.user_id(), symbol, self.params.json().get("stance") or ""))

    def clear_assumption(self, symbol):
        self._account.clear_assumption(self.user_id(), symbol)
        return "", 204

    def register_device(self):
        data = self.params.json()
        self._account.register_device(self.user_id(), data.get("token") or "", data.get("platform") or "android")
        return "", 204

    def unregister_device(self):
        self._account.unregister_device(self.user_id(), self.params.json().get("token") or "")
        return "", 204


class AdminController(Controller):
    """Web admin area. Every route requires an active admin account."""

    name, url_prefix = "admin", "/api/admin"

    def __init__(self, admin: IAdminService):
        self._admin = admin
        super().__init__()

    def register_routes(self) -> None:
        self.route("/overview", self.overview, admin=True)
        self.route("/users", self.users, admin=True)
        self.route("/users/<user_id>", self.update_user, methods=["PATCH"], admin=True, limit="60 per minute")
        self.route("/sessions", self.sessions, admin=True)
        self.route("/sessions/<session_id>", self.update_session, methods=["PATCH"], admin=True, limit="60 per minute")
        self.route("/exchanges", self.exchanges, admin=True)
        self.route("/exchanges/<code>/tickers", self.tickers, admin=True)
        self.route("/tickers/<path:symbol>", self.update_ticker, methods=["PATCH"], admin=True, limit="120 per minute")
        self.route("/audit", self.audit, admin=True)

    def overview(self):
        return self.ok(self._admin.overview())

    def users(self):
        return self.ok(self._admin.list_users(
            query=self.params.arg("q"),
            page=self.params.int(self.params.arg("page"), "page", 1, low=1),
            page_size=self.params.int(self.params.arg("page_size"), "page_size", 25, low=1, high=100),
        ))

    def update_user(self, user_id):
        return self.ok(user=self._admin.update_user(self.user_id(), user_id, self.params.json()))

    def sessions(self):
        return self.ok(sessions=self._admin.list_sessions(status=self.params.arg("status") or None))

    def update_session(self, session_id):
        return self.ok(session=self._admin.set_session_status(self.user_id(), session_id, self.params.json().get("status") or ""))

    def exchanges(self):
        return self.ok(exchanges=self._admin.exchanges())

    def tickers(self, code):
        return self.ok(tickers=self._admin.tickers(code))

    def update_ticker(self, symbol):
        return self.ok(ticker=self._admin.set_ticker_active(self.user_id(), symbol, self.params.json().get("active")))

    def audit(self):
        return self.ok(actions=self._admin.audit_log(self.params.int(self.params.arg("limit"), "limit", 100, low=1, high=500)))
