import time
from datetime import time as dtime

import click
from flask import Flask
from werkzeug.security import generate_password_hash

from app.contracts.repositories import IUnitOfWork, IUserRepository
from app.extensions import db
from app.models import Country, Exchange, Ticker


class CatalogSeeder:
    """Upserts the global market catalog from data/seed/catalog.py. Idempotent:
    re-running updates names/hours/order without duplicating rows."""

    def __init__(self, uow: IUnitOfWork):
        self._uow = uow

    def seed(self) -> dict:
        from data.seed.catalog import COUNTRIES, EXCHANGES, INDICES, STOCKS

        for code, name, region, currency in COUNTRIES:
            country = db.session.get(Country, code) or Country(code=code)
            country.name, country.region, country.currency = name, region, currency
            db.session.add(country)
        self._uow.flush()

        exchanges = {spec["code"]: (self._upsert_exchange(spec), spec) for spec in EXCHANGES}
        self._uow.flush()

        stock_count = 0
        for code, rows in STOCKS.items():
            exchange, spec = exchanges[code]
            for position, (display, name, sector, base_price) in enumerate(rows):
                symbol = display + spec["suffix"] if spec["source"] == "yahoo" else f"{display}.{code}"
                self._upsert_ticker(symbol, exchange_id=exchange.id, display_symbol=display, company_name=name, sector=sector,
                                    kind="stock", currency=spec["currency"], data_source=spec["source"],
                                    base_price=base_price, display_order=position)
                stock_count += 1

        for position, (display, yahoo_symbol, name, code, base_price) in enumerate(INDICES):
            exchange, spec = exchanges[code]
            self._upsert_ticker(yahoo_symbol or f"{display}.{code}.IDX", exchange_id=exchange.id, display_symbol=display,
                                company_name=name, sector=None, kind="index", currency=spec["currency"],
                                data_source="yahoo" if yahoo_symbol else "synthetic", base_price=base_price, display_order=position)

        self._uow.commit()
        return {"countries": len(COUNTRIES), "exchanges": len(EXCHANGES), "stocks": stock_count, "indices": len(INDICES)}

    @staticmethod
    def _upsert_exchange(spec: dict) -> Exchange:
        exchange = Exchange.query.filter_by(code=spec["code"]).first() or Exchange(code=spec["code"])
        exchange.name = spec["name"]
        exchange.country_code = spec["country"]
        exchange.timezone = spec["timezone"]
        exchange.opens_at = dtime.fromisoformat(spec["opens_at"])
        exchange.closes_at = dtime.fromisoformat(spec["closes_at"])
        exchange.trading_days = spec["trading_days"]
        exchange.currency = spec["currency"]
        exchange.data_source = spec["source"]
        db.session.add(exchange)
        return exchange

    @staticmethod
    def _upsert_ticker(symbol: str, **fields) -> None:
        ticker = Ticker.query.filter_by(symbol=symbol).first()
        if ticker is None:
            # New listings start active; existing ones keep whatever an admin set.
            ticker = Ticker(symbol=symbol, active=True)
        for name, value in fields.items():
            setattr(ticker, name, value)
        db.session.add(ticker)


class DemoUserFactory:
    EMAIL = "demo@algizer.app"
    PASSWORD = "demo-password"

    def __init__(self, users: IUserRepository, uow: IUnitOfWork):
        self._users = users
        self._uow = uow

    def ensure(self) -> bool:
        """Creates the verified demo account; returns False if it already exists."""
        if self._users.get_by_email(self.EMAIL):
            return False
        self._users.create(first_name="Demo", last_name="Trader", email=self.EMAIL,
                           password_hash=generate_password_hash(self.PASSWORD), is_verified=True)
        self._uow.commit()
        return True


def register_cli(app: Flask, container) -> None:
    @app.cli.command("seed")
    @click.option("--demo-user", is_flag=True, help="Also create a verified demo@algizer.app account.")
    def seed(demo_user: bool):
        """Upsert the global market catalog (countries, exchanges, tickers, indices)."""
        counts = CatalogSeeder(container.uow).seed()
        click.echo(f"Seeded {counts['countries']} countries, {counts['exchanges']} exchanges, "
                   f"{counts['stocks']} stocks, {counts['indices']} indices.")
        if demo_user:
            created = DemoUserFactory(container.users, container.uow).ensure()
            click.echo(f"{'Created' if created else 'Existing'} demo user: {DemoUserFactory.EMAIL} / {DemoUserFactory.PASSWORD}")

    @app.cli.command("make-admin")
    @click.argument("email")
    @click.option("--revoke", is_flag=True, help="Remove admin rights instead of granting them.")
    def make_admin(email: str, revoke: bool):
        """Grant (or revoke) access to the web admin area."""
        user = container.users.get_by_email(email)
        if user is None:
            raise click.ClickException(f"No account with email {email}")
        container.users.update(user.id, is_admin=not revoke)
        container.uow.commit()
        click.echo(f"{user.email} is {'no longer' if revoke else 'now'} an admin.")

    @app.cli.command("fetch-logos")
    @click.option("--refresh", is_flag=True, help="Look up every Yahoo stock again, not only those without a website.")
    def fetch_logos(refresh: bool):
        """Store each Yahoo stock's company website, which gives its logo."""
        query = Ticker.query.filter(Ticker.kind == "stock", Ticker.data_source == "yahoo", Ticker.active.is_(True))
        if not refresh:
            query = query.filter(Ticker.website.is_(None))
        tickers = query.all()
        click.echo(f"Looking up {len(tickers)} companies…")
        found = 0
        for start in range(0, len(tickers), 40):
            batch = tickers[start : start + 40]
            data = container.market_data.fundamentals_many(batch)
            for ticker in batch:
                website = (data.get(ticker.symbol) or {}).get("website")
                if website:
                    ticker.website = website[:200]
                    found += 1
            db.session.commit()
        click.echo(f"Stored {found} websites; {len(tickers) - found} have none on Yahoo.")

    @app.cli.command("adviser-worker")
    def adviser_worker():
        """Run the Adviser monitoring loop in the foreground."""
        from app.workers import AdviserWorker

        worker = AdviserWorker(app, container.adviser, container.uow)
        worker.start()
        try:
            while worker.is_alive():
                time.sleep(1)
        except KeyboardInterrupt:
            worker.stop()
