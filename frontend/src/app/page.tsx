"use client";

import Link from "next/link";
import { api } from "@/lib/api";
import { useAuth } from "@/lib/auth-context";
import { useAsync } from "@/lib/use-async";
import { useLiveQuotes } from "@/lib/realtime";
import { PREFS, sortWatchlist, useBrowserPref } from "@/lib/preferences";
import {
  changeClass,
  formatDateTime,
  formatInterval,
  formatNumber,
  formatPercent,
  formatPrice,
  symbolHref,
} from "@/lib/format";
import { SignalBadge, SourceBadge } from "@/components/ui/Badges";
import { PageShell, Skeleton } from "@/components/ui/primitives";
import { Landing } from "@/components/landing/Landing";

const STEPS = [
  {
    n: 1,
    title: "Select",
    href: "/selector",
    text: "Rank an exchange’s stocks over a period and keep the top performers.",
  },
  {
    n: 2,
    title: "Optimize",
    href: "/optimizer",
    text: "Tune the signal on history, then test it on a period it has never seen.",
  },
  {
    n: 3,
    title: "Advise",
    href: "/adviser",
    text: "Watch the market live and get a BUY, SELL or HOLD the moment it changes.",
  },
];

function greeting(now: Date) {
  const h = now.getHours();
  return h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening";
}

export default function HomePage() {
  const { user, isLoading } = useAuth();
  if (isLoading) {
    return (
      <PageShell>
        <Skeleton className="h-40" />
      </PageShell>
    );
  }
  return user ? <SignedInHome /> : <Landing />;
}

function SignedInHome() {
  const { user, token } = useAuth();
  const { data, loading } = useAsync(() => api.indices(), []);
  const headline = data?.indices.slice(0, 8) ?? [];
  const live = useLiveQuotes(headline.map((r) => r.symbol));

  return (
    <PageShell>
      <div className="flex flex-col gap-10">
        {user ? (
          <header className="flex flex-col gap-1">
            <span className="text-sm text-muted-foreground">
              {new Date().toLocaleDateString(undefined, {
                weekday: "long",
                day: "numeric",
                month: "long",
              })}
            </span>
            <h1 className="text-3xl font-bold tracking-tight">
              {greeting(new Date())}, {user.first_name}
            </h1>
          </header>
        ) : (
          <header className="flex flex-wrap items-end justify-between gap-6">
            <div className="flex flex-col gap-4">
              <h1 className="text-5xl font-light leading-[1.05] tracking-tight sm:text-6xl">
                Signals,
                <br />
                <span className="font-black">not noise.</span>
              </h1>
              <p className="max-w-lg text-lg leading-relaxed text-muted-foreground">
                Stockiser ranks an exchange, tunes a strategy on its history,
                then watches the market and tells you when to act.
              </p>
            </div>
            <div className="flex gap-2">
              <Link href="/register" className="btn-primary">
                Create account
              </Link>
              <Link href="/login" className="btn-secondary">
                Log in
              </Link>
            </div>
          </header>
        )}

        <section
          aria-label="Indices"
          className="grid grid-cols-[repeat(auto-fill,minmax(190px,1fr))] border-y border-border"
        >
          {loading &&
            !headline.length &&
            Array.from({ length: 4 }).map((_, i) => (
              <Skeleton key={i} className="my-5 mr-5 h-16" />
            ))}
          {headline.map((row) => {
            const q = live[row.symbol] ?? row.quote;
            return (
              <Link
                key={row.symbol}
                href={symbolHref(row.symbol)}
                className="group flex flex-col gap-1 py-5 pr-5"
              >
                <span className="flex items-center gap-2 truncate text-[13px] font-bold text-muted-foreground group-hover:text-foreground">
                  {row.name}
                  <SourceBadge source={row.data_source} />
                </span>
                <span className="tabular text-2xl font-light tracking-tight">
                  {formatNumber(q?.price)}
                </span>
                <span
                  className={`tabular text-[13px] font-bold ${changeClass(q?.change_percent)}`}
                >
                  {formatPercent(q?.change_percent)}
                </span>
              </Link>
            );
          })}
        </section>

        {user && token ? <Dashboard token={token} /> : <Pipeline />}
      </div>
    </PageShell>
  );
}

function Pipeline() {
  return (
    <section className="flex flex-col gap-6">
      <h2 className="label-caps">How it works</h2>
      <ol className="grid gap-8 md:grid-cols-3">
        {STEPS.map((s) => (
          <li
            key={s.n}
            className="flex flex-col gap-3 border-t border-border pt-5"
          >
            <span className="text-sm font-bold text-brand">0{s.n}</span>
            <Link href={s.href} className="text-xl font-bold hover:text-brand">
              {s.title}
            </Link>
            <p className="leading-relaxed text-muted-foreground">{s.text}</p>
          </li>
        ))}
      </ol>
      <Link href="/markets" className="btn-secondary self-start">
        Explore 37 exchanges
      </Link>
    </section>
  );
}

function Dashboard({ token }: { token: string }) {
  const signals = useAsync(() => api.signals(token), [token]);
  const sessions = useAsync(() => api.sessions(token), [token]);
  const runs = useAsync(() => api.selectorRuns(token), [token]);
  const watch = useAsync(() => api.watchlist(token), [token]);
  const recent = signals.data?.signals.slice(0, 8) ?? [];
  const active =
    sessions.data?.sessions.filter((s) => s.status === "active") ?? [];
  const lastRun = runs.data?.runs[0];
  const watchSort = useBrowserPref(PREFS.watchlistSort);
  const showWatchlist = useBrowserPref(PREFS.homeWatchlist) === "show";
  const live = useLiveQuotes((watch.data?.items ?? []).map((r) => r.symbol));
  const watchRows = sortWatchlist(watch.data?.items ?? [], watchSort, live);

  return (
    <div className="flex flex-wrap items-start gap-12">
      <section className="flex min-w-0 flex-[2_1_520px] flex-col gap-3">
        <div className="flex items-baseline justify-between">
          <h2 className="text-xl font-bold">Latest signals</h2>
          <Link href="/adviser" className="text-sm font-bold text-brand">
            All signals
          </Link>
        </div>
        {signals.loading && !recent.length ? (
          <Skeleton className="h-48" />
        ) : recent.length ? (
          <div className="overflow-x-auto">
            <table className="tabular w-full min-w-[540px] text-sm">
              <thead>
                <tr className="label-caps text-left">
                  <th className="border-b border-border py-2.5 font-bold">
                    Time
                  </th>
                  <th className="border-b border-border py-2.5 font-bold">
                    Ticker
                  </th>
                  <th className="border-b border-border py-2.5 font-bold">
                    Signal
                  </th>
                  <th className="border-b border-border py-2.5 text-right font-bold">
                    Price
                  </th>
                  <th className="border-b border-border py-2.5 text-right font-bold">
                    Confidence
                  </th>
                </tr>
              </thead>
              <tbody>
                {recent.map((s) => (
                  <tr key={s.id}>
                    <td className="border-b border-border py-3.5 text-muted-foreground">
                      {formatDateTime(s.emitted_at)}
                    </td>
                    <td className="border-b border-border py-3.5">
                      <Link
                        href={symbolHref(s.symbol)}
                        className="font-bold hover:text-brand"
                      >
                        {s.display_symbol}
                      </Link>{" "}
                      <span className="text-muted-foreground">· {s.name}</span>
                    </td>
                    <td className="border-b border-border py-3.5">
                      <SignalBadge type={s.signal_type} size="sm" />
                    </td>
                    <td className="border-b border-border py-3.5 text-right">
                      {formatPrice(s.price, s.currency)}
                    </td>
                    <td className="border-b border-border py-3.5 text-right">
                      {Math.round(s.confidence * 100)}%
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <p className="border-y border-border py-8 text-center text-sm text-muted-foreground">
            No signals yet. Monitor a ticker with the{" "}
            <Link href="/adviser" className="font-bold text-brand">
              Adviser
            </Link>{" "}
            to start receiving them.
          </p>
        )}
      </section>

      <div className="flex min-w-0 flex-[1_1_300px] flex-col gap-9">
        <section className="panel flex flex-col gap-4 p-5">
          <h2 className="label-caps">Your strategy</h2>
          <ol className="flex flex-col gap-3.5">
            <StepRow
              done={!!lastRun}
              title="Selector"
              detail={
                lastRun
                  ? `${lastRun.exchange} · top ${lastRun.top_n}`
                  : "Not run yet"
              }
            />
            <StepRow
              done={!!lastRun}
              title="Optimizer"
              detail={
                lastRun ? "Tune from your ticker file" : "Needs a ticker file"
              }
            />
            <StepRow
              live={active.length > 0}
              title="Adviser"
              detail={
                active.length
                  ? `${active.length} live · every ${formatInterval(active[0].interval_sec)}`
                  : "Nothing monitored"
              }
            />
          </ol>
          <Link
            href={lastRun ? "/optimizer" : "/selector"}
            className="btn-primary"
          >
            {lastRun ? "Continue to Optimizer" : "Run your first selection"}
          </Link>
        </section>

        {showWatchlist && (
          <section className="flex flex-col">
            <div className="flex items-baseline justify-between pb-1.5">
              <h2 className="text-xl font-bold">Watchlist</h2>
              <Link href="/watchlist" className="text-sm font-bold text-brand">
                Edit
              </Link>
            </div>
            {watchRows.length === 0 && !watch.loading && (
              <p className="border-y border-border py-5 text-sm text-muted-foreground">
                Star a ticker to keep it here.
              </p>
            )}
            {watchRows.slice(0, 6).map((row) => {
              const q = live[row.symbol] ?? row.quote;
              return (
                <Link
                  key={row.symbol}
                  href={symbolHref(row.symbol)}
                  className="flex items-center gap-3 border-b border-border py-3"
                >
                  <span className="flex min-w-0 flex-1 flex-col">
                    <span className="text-[15px] font-bold">
                      {row.display_symbol}
                    </span>
                    <span className="truncate text-xs text-muted-foreground">
                      {row.name}
                    </span>
                  </span>
                  <span className="tabular flex flex-col items-end">
                    <span className="text-[15px]">
                      {formatNumber(q?.price)}
                    </span>
                    <span
                      className={`text-xs font-bold ${changeClass(q?.change_percent)}`}
                    >
                      {formatPercent(q?.change_percent)}
                    </span>
                  </span>
                </Link>
              );
            })}
          </section>
        )}
      </div>
    </div>
  );
}

function StepRow({
  title,
  detail,
  done,
  live,
}: {
  title: string;
  detail: string;
  done?: boolean;
  live?: boolean;
}) {
  return (
    <li className="flex items-center gap-3">
      <span className="flex h-[22px] w-[22px] items-center justify-center">
        {done ? (
          <span className="flex h-[22px] w-[22px] items-center justify-center rounded-full bg-ink text-ink-foreground">
            <svg
              aria-hidden
              width="12"
              height="12"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="3"
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              <path d="M5 12l5 5 9-10" />
            </svg>
          </span>
        ) : live ? (
          <span className="h-3 w-3 rounded-full bg-brand shadow-[0_0_0_4px_var(--brand-soft)]" />
        ) : (
          <span className="h-[22px] w-[22px] rounded-full border-2 border-border" />
        )}
      </span>
      <span className="flex-1 text-[15px] font-bold">{title}</span>
      <span className="text-[13px] text-muted-foreground">{detail}</span>
    </li>
  );
}
