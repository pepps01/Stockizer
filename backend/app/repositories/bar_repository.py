import time
from datetime import date

import numpy as np
import pandas as pd
from sqlalchemy import func
from sqlalchemy.exc import OperationalError

from app.contracts.market_data import BAR_COLUMNS, empty_bars
from app.contracts.repositories import IBarRepository
from app.extensions import db
from app.models import MarketData
from app.models.base import utcnow


class SqlAlchemyBarRepository(IBarRepository):
    """Daily OHLCV cache in the market_data table. Upserts commit immediately:
    the cache is independent of any business transaction."""

    DEADLOCK_RETRIES = 3
    READ_BATCH = 5000  # rows fetched per round trip while streaming
    RETRYABLE_MYSQL_ERRORS = {1213, 1205}  # deadlock found; lock wait timeout

    def coverage(self, ticker_ids: list[str]) -> dict[str, tuple[date, date]]:
        if not ticker_ids:
            return {}
        rows = (
            db.session.query(MarketData.ticker_id, func.min(MarketData.ts), func.max(MarketData.ts))
            .filter(MarketData.ticker_id.in_(ticker_ids))
            .group_by(MarketData.ticker_id)
            .all()
        )
        return {ticker_id: (lo, hi) for ticker_id, lo, hi in rows}

    def upsert(self, ticker_id: str, frame: pd.DataFrame, source: str) -> None:
        if frame is None or frame.empty:
            return
        now = utcnow()
        rows = [
            {
                "ticker_id": ticker_id,
                "ts": ts,
                "open": round(float(row.open), 6),
                "high": round(float(row.high), 6),
                "low": round(float(row.low), 6),
                "close": round(float(row.close), 6),
                "volume": round(float(row.volume), 2),
                "source": source,
                "fetched_at": now,
            }
            for ts, row in frame.iterrows()
        ]
        dialect = db.engine.dialect.name
        if dialect == "mysql":
            from sqlalchemy.dialects.mysql import insert

            stmt = insert(MarketData)
            stmt = stmt.on_duplicate_key_update(
                {c: stmt.inserted[c] for c in ("open", "high", "low", "close", "volume", "source", "fetched_at")}
            )
        else:
            from sqlalchemy.dialects.sqlite import insert

            stmt = insert(MarketData)
            stmt = stmt.on_conflict_do_update(
                index_elements=["ticker_id", "ts"],
                set_={c: stmt.excluded[c] for c in ("open", "high", "low", "close", "volume", "source", "fetched_at")},
            )
        # The cache warmer and page requests can top up the same ticker at once;
        # MySQL may then pick one upsert as a deadlock victim. The upsert is
        # idempotent, so roll back and try again.
        for attempt in range(self.DEADLOCK_RETRIES + 1):
            try:
                db.session.execute(stmt, rows)
                db.session.commit()
                return
            except OperationalError as exc:
                db.session.rollback()
                code = exc.orig.args[0] if exc.orig is not None and exc.orig.args else None
                if code not in self.RETRYABLE_MYSQL_ERRORS or attempt == self.DEADLOCK_RETRIES:
                    raise
                time.sleep(0.05 * (attempt + 1))

    def read(self, ticker_ids: list[str], start: date, end: date) -> dict[str, pd.DataFrame]:
        if not ticker_ids:
            return {}
        # Streamed in batches and kept as plain floats per ticker: a Selector run
        # reads years of bars for a whole exchange, and holding every row (prices
        # as Decimal objects) plus a converted copy was the API's biggest spike.
        query = (
            db.session.query(
                MarketData.ticker_id,
                MarketData.ts,
                MarketData.open,
                MarketData.high,
                MarketData.low,
                MarketData.close,
                MarketData.volume,
            )
            .filter(MarketData.ticker_id.in_(ticker_ids), MarketData.ts >= start, MarketData.ts <= end)
            .order_by(MarketData.ticker_id, MarketData.ts)
            .yield_per(self.READ_BATCH)
        )
        columns: dict[str, tuple[list, ...]] = {}
        for tid, ts, o, h, lo, c, v in query:
            acc = columns.get(tid)
            if acc is None:
                acc = columns[tid] = ([], [], [], [], [], [])
            acc[0].append(ts)
            acc[1].append(float(o))
            acc[2].append(float(h))
            acc[3].append(float(lo))
            acc[4].append(float(c))
            acc[5].append(float(v))
        out = {tid: empty_bars() for tid in ticker_ids}
        for tid, (ts, o, h, lo, c, v) in columns.items():
            out[tid] = pd.DataFrame(
                {name: np.asarray(values, dtype=float) for name, values in zip(BAR_COLUMNS, (o, h, lo, c, v))},
                index=ts,
            )
        return out
