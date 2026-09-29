"""Builds backend/data/fundamentals.json from the raw index-constituent fundamental
summaries in backend/data/raw/*.csv (Dow, S&P 500, Nasdaq, Russell). This is the
real ticker universe the Selector ranks over — a large step up from the small
curated data.json used for exchange-browsing pages.

Each CSV has columns: ticker, Qurt_RevGrw, Tot_Cash, Tot_Debt, Retrn_Asst,
Retrn_Eqty, Lev_frCshFlw, PE_value, PB_value, Net_Income, Net_Cash, Score.
PE_value/PB_value are always 0.0 in the source data (unpopulated upstream), so
they're dropped here — live P/E is fetched from yfinance instead when a ticker
is actually displayed. A ticker appearing in multiple index files (e.g. an S&P
500 company that's also in the Nasdaq list) is deduplicated into one record with
a combined `index_memberships` list.

Run with:  python -m data.seed.build_fundamentals
"""

import csv
import os

RAW_DIR = os.path.join(os.path.dirname(__file__), "..", "raw")
OUT_PATH = os.path.join(os.path.dirname(__file__), "..", "fundamentals.json")

SOURCES = {
    "dow_summary.csv": "dow",
    "sp500_summary.csv": "sp500",
    "nasdaq_summary.csv": "nasdaq",
    "rus_summary.csv": "russell",
}


def _float_or_none(value: str) -> float | None:
    try:
        parsed = float(value)
        return parsed
    except (TypeError, ValueError):
        return None


def main():
    records: dict[str, dict] = {}

    for filename, index_name in SOURCES.items():
        path = os.path.join(RAW_DIR, filename)
        with open(path, encoding="utf-8") as f:
            for row in csv.DictReader(f):
                symbol = row["ticker"].strip().upper()
                if not symbol:
                    continue

                if symbol in records:
                    records[symbol]["index_memberships"].append(index_name)
                    continue

                records[symbol] = {
                    "symbol": symbol,
                    "index_memberships": [index_name],
                    "quarterly_revenue_growth": _float_or_none(row["Qurt_RevGrw"]),
                    "total_cash": _float_or_none(row["Tot_Cash"]),
                    "total_debt": _float_or_none(row["Tot_Debt"]),
                    "return_on_assets": _float_or_none(row["Retrn_Asst"]),
                    "return_on_equity": _float_or_none(row["Retrn_Eqty"]),
                    "leveraged_free_cash_flow": _float_or_none(row["Lev_frCshFlw"]),
                    "net_income": _float_or_none(row["Net_Income"]),
                    "net_cash": _float_or_none(row["Net_Cash"]),
                    "score": _float_or_none(row["Score"]),
                }

    out = sorted(records.values(), key=lambda r: r["symbol"])
    with open(OUT_PATH, "w", encoding="utf-8") as f:
        import json

        json.dump(out, f, indent=2)

    print(f"Wrote {len(out)} unique tickers (from {sum(len(v['index_memberships']) for v in out)} index rows) to {OUT_PATH}")


if __name__ == "__main__":
    main()
