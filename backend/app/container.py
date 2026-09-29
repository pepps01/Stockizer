"""Composition root: the single place that wires concrete repository/service
implementations to their contracts. Blueprints pull dependencies from the
container via current_app.extensions["container"] — they never instantiate
repositories or services directly. Swapping an implementation (e.g. SQLite to
Postgres, yfinance to another provider) means changing only this file."""

from dataclasses import dataclass

from flask import current_app

from app.repositories.local_fundamentals_repository import LocalFundamentalsRepository
from app.repositories.local_market_repository import LocalExchangeRepository, LocalTickerRepository
from app.repositories.sqlalchemy_action_repository import SqlAlchemyUserActionRepository
from app.repositories.sqlalchemy_user_repository import SqlAlchemyUserRepository
from app.services.auth_service import AuthService
from app.services.mock_adviser import MockAdviser
from app.services.mock_optimizer import MockOptimizer
from app.services.mock_selector import MockStockSelector
from app.services.sendgrid_email_service import SendGridEmailService
from app.services.yfinance_market_data import YFinanceMarketDataProvider


@dataclass
class Container:
    user_repository: SqlAlchemyUserRepository
    action_repository: SqlAlchemyUserActionRepository
    exchange_repository: LocalExchangeRepository
    ticker_repository: LocalTickerRepository
    fundamentals_repository: LocalFundamentalsRepository
    market_data: YFinanceMarketDataProvider
    email_service: SendGridEmailService
    auth_service: AuthService
    selector: MockStockSelector
    optimizer: MockOptimizer
    adviser: MockAdviser


def build_container(config) -> Container:
    user_repository = SqlAlchemyUserRepository()
    action_repository = SqlAlchemyUserActionRepository()
    exchange_repository = LocalExchangeRepository(config["MARKET_DATA_PATH"])
    ticker_repository = LocalTickerRepository(config["MARKET_DATA_PATH"])
    fundamentals_repository = LocalFundamentalsRepository(config["FUNDAMENTALS_DATA_PATH"])
    market_data = YFinanceMarketDataProvider()

    email_service = SendGridEmailService(
        api_key=config["SENDGRID_API_KEY"],
        email_from=config["EMAIL_FROM"],
        frontend_url=config["FRONTEND_URL"],
    )

    auth_service = AuthService(
        user_repository,
        email_service,
        secret_key=config["SECRET_KEY"],
        salt=config["EMAIL_VERIFICATION_SALT"],
        max_age_seconds=config["EMAIL_VERIFICATION_MAX_AGE_SECONDS"],
    )

    selector = MockStockSelector(fundamentals_repository, market_data)
    optimizer = MockOptimizer()
    adviser = MockAdviser()

    return Container(
        user_repository=user_repository,
        action_repository=action_repository,
        exchange_repository=exchange_repository,
        ticker_repository=ticker_repository,
        fundamentals_repository=fundamentals_repository,
        market_data=market_data,
        email_service=email_service,
        auth_service=auth_service,
        selector=selector,
        optimizer=optimizer,
        adviser=adviser,
    )


def get_container() -> Container:
    return current_app.extensions["container"]
