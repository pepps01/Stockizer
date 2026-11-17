"""Composition root: the one place that chooses concrete implementations and
wires them together behind their interfaces. Every other module depends on the
contracts in app/contracts/ only. Swapping an implementation (another price
source, an S3 artifact store, Postgres repositories) means changing this file."""

from dataclasses import dataclass

from app.analytics.ranking import RankingMetricRegistry
from app.analytics.search import RandomRefineSearch
from app.analytics.indicator_engine import IndicatorSignalEngine
from app.analytics.signal_engine import AlgebraicSignalEngine
from app.analytics.strategies import StrategyRegistry
from app.analytics.style import ExchangeRelativeStyleClassifier
from app.analytics.stats import ReturnStatistics
from app.analytics.technicals import TechnicalAnalyzer
from app.api.base import ApiErrorHandler, Controller, CorsPolicy
from app.api.controllers import (
    AccountController,
    AdminController,
    AdviserController,
    ArtifactController,
    AuthController,
    MarketsController,
    OptimizerController,
    SelectorController,
)
from app.api.realtime import RealtimeGateway
from app.contracts.analytics import ISignalEngine, IStrategyRegistry
from app.contracts.repositories import ICatalogRepository, IUnitOfWork, IUserRepository
from app.contracts.services import (
    IAccountService,
    IAdminService,
    IAdviserService,
    IArtifactStore,
    IAuthService,
    IEmailService,
    IMarketBoard,
    IMarketDataService,
    IOptimizerService,
    IPushService,
    ISelectorService,
)
from app.repositories.admin_repository import SqlAlchemyAdminRepository
from app.repositories.account_repositories import (
    SqlAlchemyAssumptionRepository,
    SqlAlchemyUserActionRepository,
    SqlAlchemyWatchlistRepository,
)
from app.repositories.bar_repository import SqlAlchemyBarRepository
from app.repositories.catalog_repository import SqlAlchemyCatalogRepository, TickerRefMapper
from app.repositories.device_repository import SqlAlchemyDeviceTokenRepository
from app.repositories.pipeline_repositories import (
    SqlAlchemyAdviserSessionRepository,
    SqlAlchemyArtifactRepository,
    SqlAlchemyOptimizerRunRepository,
    SqlAlchemySelectorRunRepository,
    SqlAlchemySignalRepository,
)
from app.repositories.unit_of_work import SqlAlchemyUnitOfWork
from app.repositories.user_repository import SqlAlchemyUserRepository
from app.services.account import AccountService
from app.services.admin import AdminService
from app.services.adviser import AdviserService
from app.services.artifact_store import LocalArtifactStore
from app.services.auth_service import AuthService
from app.services.market_board import MarketBoard
from app.services.market_data import MarketDataService
from app.services.optimizer import OptimizerService
from app.services.push import DisabledPushService, FcmPushService
from app.services.selector import SelectorService
from app.services.sendgrid_email_service import SendGridEmailService
from app.sources.synthetic import SyntheticFundamentalsProvider, SyntheticMarketModel, SyntheticPriceSource
from app.sources.yahoo import YahooFundamentalsProvider, YahooPriceSource


@dataclass
class Container:
    uow: IUnitOfWork
    catalog: ICatalogRepository
    users: IUserRepository
    engine: ISignalEngine
    strategies: IStrategyRegistry
    push: IPushService
    market_data: IMarketDataService
    board: IMarketBoard
    artifacts: IArtifactStore
    email: IEmailService
    auth: IAuthService
    selector: ISelectorService
    optimizer: IOptimizerService
    adviser: IAdviserService
    account: IAccountService
    admin: IAdminService
    cors: CorsPolicy

    def controllers(self) -> list[Controller]:
        return [
            AuthController(self.auth),
            MarketsController(self.catalog, self.board, self.market_data, self.adviser),
            SelectorController(self.selector),
            OptimizerController(self.optimizer),
            ArtifactController(self.artifacts),
            AdviserController(self.adviser),
            AccountController(self.account),
            AdminController(self.admin),
        ]

    def realtime_gateway(self) -> RealtimeGateway:
        return RealtimeGateway(self.cors, self.catalog, self.market_data, self.adviser, self.uow)

    def error_handler(self) -> ApiErrorHandler:
        return ApiErrorHandler(self.uow)


def build_container(config) -> Container:
    uow = SqlAlchemyUnitOfWork()
    catalog = SqlAlchemyCatalogRepository()
    users = SqlAlchemyUserRepository()
    optimizer_runs = SqlAlchemyOptimizerRunRepository()

    devices = SqlAlchemyDeviceTokenRepository()

    statistics = ReturnStatistics()
    strategies = StrategyRegistry([AlgebraicSignalEngine(statistics), IndicatorSignalEngine(statistics)])
    engine = strategies.default
    push = FcmPushService(config["FCM_SERVICE_ACCOUNT_FILE"]) if config.get("FCM_SERVICE_ACCOUNT_FILE") else DisabledPushService()

    market_data = MarketDataService(
        bars=SqlAlchemyBarRepository(),
        sources={"yahoo": YahooPriceSource(), "synthetic": SyntheticPriceSource(SyntheticMarketModel())},
        fundamentals={"yahoo": YahooFundamentalsProvider(), "synthetic": SyntheticFundamentalsProvider()},
        mapper=TickerRefMapper(force_synthetic=config["MARKET_DATA_MODE"] == "synthetic"),
    )
    artifacts = LocalArtifactStore(config["ARTIFACT_DIR"], SqlAlchemyArtifactRepository(), uow)
    email = SendGridEmailService(api_key=config["SENDGRID_API_KEY"], email_from=config["EMAIL_FROM"], frontend_url=config["FRONTEND_URL"])
    styles = ExchangeRelativeStyleClassifier()
    selector = SelectorService(catalog, market_data, artifacts, SqlAlchemySelectorRunRepository(), uow, statistics,
                               RankingMetricRegistry.default(), styles)

    return Container(
        uow=uow,
        catalog=catalog,
        users=users,
        engine=engine,
        strategies=strategies,
        push=push,
        market_data=market_data,
        board=MarketBoard(catalog, market_data, TechnicalAnalyzer(), styles),
        artifacts=artifacts,
        email=email,
        auth=AuthService(
            users, catalog, email, uow,
            secret_key=config["SECRET_KEY"],
            salt=config["EMAIL_VERIFICATION_SALT"],
            max_age_seconds=config["EMAIL_VERIFICATION_MAX_AGE_SECONDS"],
            require_verification=config["REQUIRE_EMAIL_VERIFICATION"],
        ),
        selector=selector,
        optimizer=OptimizerService(
            catalog, market_data, artifacts, optimizer_runs, selector, uow, strategies,
            search_factory=lambda e: RandomRefineSearch(samples=150, refine_steps=60, initial=e.default_params()),
        ),
        adviser=AdviserService(
            catalog, market_data, strategies, SqlAlchemyAdviserSessionRepository(), SqlAlchemySignalRepository(),
            optimizer_runs, users, email, push, devices, uow,
        ),
        account=AccountService(catalog, market_data, SqlAlchemyWatchlistRepository(), SqlAlchemyUserActionRepository(), devices,
                               SqlAlchemyAssumptionRepository(), uow),
        admin=AdminService(
            SqlAlchemyAdminRepository(), users, catalog, push, uow,
            market_data_mode=config["MARKET_DATA_MODE"],
            email_enabled=bool(config["SENDGRID_API_KEY"]),
            adviser_worker=bool(config.get("ADVISER_WORKER")),
        ),
        cors=CorsPolicy(config["CORS_ORIGINS"]),
    )
