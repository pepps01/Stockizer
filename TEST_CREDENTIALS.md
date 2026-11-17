# Test credentials

Accounts for testing Stockiser on a local development setup (MySQL on port 3316, API on :5000). They exist only in your local database, and none of them works on a live deployment.

| Role | Email | Password | Where to sign in |
|---|---|---|---|
| Superadmin | `admin@stockiser.app` | `Stk-scBH6PcbURrGoc` | Web: `/admin/login` |
| Investor (demo) | `demo@algizer.app` | `demo-password` | Web: `/login` · Mobile: login screen |

- **Superadmin:** verified, full admin rights. It opens the admin console (users, Adviser sessions, catalog, audit log) and is web only; the mobile app has no admin area.
- **Demo investor:** verified, not an admin. It has a sample strategy: Selector runs, tuned stocks, live Adviser sessions, a watchlist and assumed positions.

## Recreating them

On a fresh database, run these from `backend/`:

```
./venv/Scripts/python.exe -m flask seed --demo-user                 # catalog + demo@algizer.app / demo-password
./venv/Scripts/python.exe -m flask make-admin admin@stockiser.app   # grant admin rights to an existing account
```

`make-admin` only grants rights to an existing account. Register `admin@stockiser.app` first (web `/register`, then verify the email), or use any account you already have. `flask make-admin EMAIL --revoke` removes the rights.

## Where the apps point

- **Web:** `NEXT_PUBLIC_API_URL` in `frontend/.env.local` (default `http://localhost:5000`).
- **Android emulator:** `http://10.0.2.2:5000` (built in).
- **Physical phone:** build with `--dart-define=API_BASE_URL=http://<your-LAN-IP>:5000`.

Change these passwords before the database is reachable by anyone else.
