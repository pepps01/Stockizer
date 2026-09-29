# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Stockizer (the app is branded "Tickizer") is a stock-market app with three independent projects that share one REST API:

- `backend/` — Flask API (Python 3.11, venv at `backend/venv`), SQLite via Flask-SQLAlchemy, JWT auth, SendGrid email verification, yfinance for live market data.
- `frontend/` — Next.js 16 (App Router, React 19, Tailwind v4, TypeScript), charts via `lightweight-charts`.
- `mobile/` — Flutter app (`provider` for state, `http`, `fl_chart`).

Both clients call the backend on `http://localhost:5000` and mirror each other's screens (markets, exchange tickers, ticker detail, financials, selector, login/register/verify-email, profile).

## Commands

Backend (run from `backend/`):
```
./venv/Scripts/python.exe -m pip install -r requirements.txt
./venv/Scripts/python.exe wsgi.py                          # dev server on :5000
./venv/Scripts/python.exe -m pytest tests/ -q              # all tests
./venv/Scripts/python.exe -m pytest tests/test_auth.py::test_register_verify_login_flow   # single test
./venv/Scripts/python.exe -m data.seed.generate_market_data   # rebuild data/data.json
```
Copy `.env.example` to `.env` for local config. Tests use `create_app("testing")` (in-memory SQLite).

Frontend (run from `frontend/`): `npm run dev` (:3000), `npm run build`, `npm run lint`. API URL comes from `NEXT_PUBLIC_API_URL` in `.env.local`.

Mobile (run from `mobile/`): `flutter run`, `flutter test`, `flutter analyze`. Override the API host with `--dart-define=API_BASE_URL=http://<lan-ip>:5000`; Android emulators default to `http://10.0.2.2:5000`.

## Backend architecture

- **App factory** `app/__init__.py:create_app` registers blueprints from `app/api/` (auth, markets, selector, optimizer, adviser, all under `/api/...`) and calls `db.create_all()` on startup. `migrations/` exists but is empty, so the schema comes from `create_all`.
- **Ports and adapters.** Abstract contracts live in `app/contracts/` (`repositories.py`, `services.py`). Concrete implementations live in `app/repositories/` and `app/services/`.
- **Composition root** `app/container.py` is the only place that instantiates implementations. Blueprints get dependencies via `get_container()` and never construct repositories or services themselves. To swap an implementation (e.g. a different data provider, a real optimizer), change only `build_container`.
- **Market data comes from two sources.** yfinance can't list an exchange's tickers, so exchanges, trading hours and the curated ticker universe are static JSON in `backend/data/` (`data.json`, `fundamentals.json`), read by the `Local*Repository` classes. Live prices, history and fundamentals are fetched from yfinance at request time (`YFinanceMarketDataProvider`). Seed scripts in `data/seed/` regenerate the JSON from `data/raw/*.csv`.
- **Algorithm pipeline is stubbed.** The Selector (ranks tickers as growth/value/equity), Optimizer and Adviser (buy/sell/hold signal) are `Mock*` classes that stand in for real algorithms still to be written. Keep the `IStockSelector`/`IOptimizer`/`IAdviser` interfaces stable when replacing them.
- Users record ticker actions (`UserAction`, validated against `VALID_ACTIONS`) through JWT-protected endpoints.
- `app/scripts/data.py` is an unused legacy scratch script that imports packages not in `requirements.txt`.

## Frontend notes

- `frontend/AGENTS.md` (pulled in by `frontend/CLAUDE.md`) warns that this Next.js version has breaking changes compared with older releases. Read the relevant guide in `frontend/node_modules/next/dist/docs/` before writing Next.js code, and follow its deprecation notices.
- All API calls go through `src/lib/api.ts` (`apiFetch`, `ApiError`). Auth state lives in `src/lib/auth-context.tsx`, and shared response types are in `src/lib/types.ts`.
- The mobile counterparts are `lib/services/api_client.dart`, `lib/state/auth_provider.dart` and `lib/models/`. An API change usually means updating both clients.
