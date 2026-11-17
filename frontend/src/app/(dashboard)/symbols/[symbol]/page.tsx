"use client";

import Link from "next/link";
import { use, useState, useSyncExternalStore } from "react";
import { api } from "@/lib/api";
import { useAuth } from "@/lib/auth-context";
import { useAsync } from "@/lib/use-async";
import { useLiveQuotes } from "@/lib/realtime";
import { useResolvedTheme } from "@/lib/theme";
import {
  currencyLabel,
  formatCompact,
  formatNumber,
  formatPercent,
  changeClass,
} from "@/lib/format";
import type { Stance } from "@/lib/types";
import { useTickerMarks } from "@/lib/use-ticker-marks";
import { PriceChart, type ChartStyle } from "@/components/charts/PriceChart";
import { SignalCard } from "@/components/symbol/SignalCard";
import { TechnicalsCard } from "@/components/symbol/TechnicalsCard";
import { IndexMembers } from "@/components/symbol/IndexMembers";
import { Flag } from "@/components/ui/Flag";
import { MarketStatus, SourceBadge } from "@/components/ui/Badges";
import {
  Card,
  Change,
  ErrorNote,
  PageShell,
  Segmented,
  Skeleton,
  Stat,
} from "@/components/ui/primitives";

const RANGES = ["1M", "3M", "6M", "YTD", "1Y", "5Y"] as const;

// Index pages have two tabs: the stock list first (the default), then the chart.
// "#chart" in the URL links straight to the second.
type IndexTab = "chart" | "stocks";
const subscribeHash = (onChange: () => void) => {
  window.addEventListener("hashchange", onChange);
  return () => window.removeEventListener("hashchange", onChange);
};
const readTab = (): IndexTab =>
  window.location.hash === "#chart" ? "chart" : "stocks";
function showTab(tab: IndexTab) {
  history.replaceState(
    null,
    "",
    tab === "chart"
      ? "#chart"
      : window.location.pathname + window.location.search,
  );
  window.dispatchEvent(new HashChangeEvent("hashchange"));
}

export default function SymbolPage({
  params,
}: {
  params: Promise<{ symbol: string }>;
}) {
  const symbol = decodeURIComponent(use(params).symbol);
  const [range, setRange] = useState<(typeof RANGES)[number]>("1Y");
  const [style, setStyle] = useState<ChartStyle>("candles");
  const detail = useAsync(() => api.symbol(symbol), [symbol]);
  const history = useAsync(() => api.history(symbol, range), [symbol, range]);
  const live = useLiveQuotes([symbol]);
  const theme = useResolvedTheme();

  const d = detail.data;
  const isIndex = d?.ticker.kind === "index";
  const members = useAsync(
    () => (isIndex ? api.indexMembers(symbol) : Promise.resolve(null)),
    [symbol, isIndex],
  );
  const tab = useSyncExternalStore(
    subscribeHash,
    readTab,
    () => "stocks" as IndexTab,
  );
  const quote = live[symbol.toUpperCase()] ?? d?.quote;
  const unit =
    d?.ticker.kind === "index" ? "" : currencyLabel(d?.ticker.currency);

  return (
    <PageShell>
      <ErrorNote message={detail.error} />
      {!d ? (
        <Skeleton className="h-24 w-full" />
      ) : (
        <header className="flex flex-wrap items-start justify-between gap-6">
          <div className="flex items-start gap-4">
            <div>
              <div className="flex flex-wrap items-center gap-2 text-sm text-muted-foreground">
                <Flag code={d.ticker.country_code} size={18} />
                <span className="font-bold text-foreground">
                  {d.ticker.display_symbol}
                </span>
                <span>·</span>
                <Link
                  href={`/markets/${d.exchange.code}`}
                  className="underline decoration-border underline-offset-4 hover:text-foreground"
                >
                  {d.exchange.name}
                </Link>
                {d.ticker.sector && <span>· {d.ticker.sector}</span>}
                <SourceBadge source={d.ticker.data_source} />
              </div>
              <h1 className="mt-2 text-[28px] font-bold leading-tight sm:text-[32px]">
                {d.ticker.name}
              </h1>
              <div className="mt-3 flex flex-wrap items-baseline gap-3">
                <span className="tabular text-5xl font-light tracking-tight">
                  {formatNumber(quote?.price)}
                </span>
                <span className="text-sm text-muted-foreground">{unit}</span>
                <Change
                  value={quote?.change ?? null}
                  percent={quote?.change_percent ?? null}
                  className="text-lg font-bold"
                />
              </div>
              <div className="mt-2 flex flex-wrap items-center gap-3">
                <MarketStatus
                  open={Boolean(quote?.market_open)}
                  localTime={d.exchange.local_time}
                />
                <span className="text-xs text-muted-foreground">
                  As of {quote?.as_of}
                  {d.ticker.data_source === "yahoo"
                    ? " · Yahoo Finance (may be delayed)"
                    : " · simulated feed"}
                </span>
              </div>
            </div>
          </div>
          <SymbolActions symbol={d.ticker.symbol} />
        </header>
      )}

      {d?.ticker.data_source === "synthetic" && (
        <p className="mt-4 rounded-xl bg-hold-soft px-4 py-3 text-sm text-hold">
          No free live data feed covers {d.exchange.name}, so this price series
          is generated by a deterministic model for demonstration. Don&apos;t
          trade on it.
        </p>
      )}

      {isIndex && (
        <nav
          aria-label="Index views"
          className="mt-6 flex gap-1 border-b border-border"
        >
          {(
            [
              ["stocks", "Stocks", members.data?.stocks.length ?? null],
              ["chart", "Chart & signal", null],
            ] as [IndexTab, string, number | null][]
          ).map(([key, label, count]) => (
            <button
              key={key}
              type="button"
              aria-current={tab === key ? "page" : undefined}
              onClick={() => showTab(key)}
              className={`-mb-px flex items-center gap-2 border-b-2 px-4 pb-3 text-[15px] font-bold transition-colors ${
                tab === key
                  ? "border-foreground text-foreground"
                  : "border-transparent text-muted-foreground hover:text-foreground"
              }`}
            >
              {label}
              {count != null && (
                <span
                  className={`tabular rounded-full px-2 py-0.5 text-xs ${tab === key ? "bg-ink text-ink-foreground" : "bg-surface-muted"}`}
                >
                  {count}
                </span>
              )}
            </button>
          ))}
        </nav>
      )}

      {isIndex && tab === "stocks" ? (
        <div className="mt-6">
          <IndexMembers
            symbol={d.ticker.symbol}
            indexName={d.ticker.name}
            data={members.data}
            loading={members.loading}
            error={members.error}
          />
        </div>
      ) : (
        <div className="mt-6 grid gap-6 lg:grid-cols-[1fr_22rem]">
          <div className="space-y-6">
            <Card
              title={
                <Segmented
                  value={range}
                  onChange={setRange}
                  options={RANGES.map((r) => ({ value: r, label: r }))}
                />
              }
              action={
                <Segmented
                  value={style}
                  onChange={setStyle}
                  options={[
                    { value: "candles", label: "Candles" },
                    { value: "area", label: "Line" },
                  ]}
                />
              }
            >
              {history.data?.bars.length ? (
                <PriceChart key={theme} bars={history.data.bars} style={style} />
              ) : (
                <Skeleton className="h-[420px]" />
              )}
            </Card>

            {d && (
              <Card title="Key statistics">
                <dl className="grid grid-cols-2 gap-4 text-sm sm:grid-cols-4">
                  <Stat label="Open" value={formatNumber(quote?.open)} />
                  <Stat
                    label="Day range"
                    value={`${formatNumber(quote?.low)} – ${formatNumber(quote?.high)}`}
                  />
                  <Stat
                    label="52-week range"
                    value={`${formatNumber(d.fundamentals.fifty_two_week_low)} – ${formatNumber(d.fundamentals.fifty_two_week_high)}`}
                  />
                  <Stat label="Volume" value={formatCompact(quote?.volume)} />
                  {d.ticker.kind === "stock" && (
                    <>
                      <Stat
                        label="Market cap"
                        value={`${formatCompact(d.fundamentals.market_cap)} ${unit}`}
                      />
                      <Stat
                        label="P/E (TTM)"
                        value={formatNumber(d.fundamentals.pe_ratio, 2)}
                      />
                      <Stat
                        label="EPS (TTM)"
                        value={formatNumber(d.fundamentals.eps)}
                      />
                      <Stat
                        label="Dividend yield"
                        value={
                          d.fundamentals.dividend_yield != null
                            ? `${d.fundamentals.dividend_yield.toFixed(2)}%`
                            : "—"
                        }
                      />
                      <Stat
                        label="Beta"
                        value={formatNumber(d.fundamentals.beta, 2)}
                      />
                      <Stat
                        label="Avg volume (30D)"
                        value={formatCompact(d.fundamentals.avg_volume_30d)}
                      />
                      <Stat
                        label="Employees"
                        value={formatCompact(d.fundamentals.employees)}
                      />
                      <Stat
                        label="Industry"
                        value={d.fundamentals.industry ?? "—"}
                      />
                    </>
                  )}
                </dl>
                <h3 className="label-caps mt-8">Performance</h3>
                <div className="mt-3 grid grid-cols-3 border-y border-border sm:grid-cols-6">
                  {(
                    [
                      "perf_1w",
                      "perf_1m",
                      "perf_3m",
                      "perf_6m",
                      "perf_ytd",
                      "perf_1y",
                    ] as const
                  ).map((k) => (
                    <div key={k} className="py-3">
                      <div className="text-xs uppercase text-muted-foreground">
                        {k.replace("perf_", "")}
                      </div>
                      <div
                        className={`tabular mt-0.5 font-bold ${changeClass(d.performance[k])}`}
                      >
                        {formatPercent(d.performance[k])}
                      </div>
                    </div>
                  ))}
                </div>
                {d.fundamentals.description && (
                  <>
                    <h3 className="label-caps mt-8">About</h3>
                    <p className="mt-3 max-w-prose text-sm leading-relaxed text-muted-foreground">
                      {d.fundamentals.description}
                    </p>
                  </>
                )}
              </Card>
            )}
          </div>

          <aside className="space-y-6">
            {d && <SignalCard ticker={d.ticker} />}
            {d && <TechnicalsCard technicals={d.technicals} />}
          </aside>
        </div>
      )}
    </PageShell>
  );
}

// Written out in full so Tailwind generates every class.
const ASSUME_TONE: Record<Stance, { on: string; off: string }> = {
  buy: { on: "bg-gain text-white", off: "text-gain" },
  hold: { on: "bg-hold text-white", off: "text-hold" },
  sell: { on: "bg-loss text-white", off: "text-loss" },
};

/** Watchlist star plus the investor's assumed call on this symbol (never an order). */
function SymbolActions({ symbol }: { symbol: string }) {
  const { token } = useAuth();
  const marks = useTickerMarks(token);
  const [note, setNote] = useState<string | null>(null);

  if (!token) return null;

  const stance = marks.stanceOf(symbol);
  const watching = marks.isWatching(symbol);
  const assume = (a: Stance) => {
    const next = stance === a ? null : a;
    marks.assume(symbol, next);
    setNote(next ? `Assumed ${next}. Track it in your Investor profile. Stockiser never places orders.` : "Assumption cleared.");
  };

  return (
    <div className="flex flex-col items-end gap-2">
      <button type="button" onClick={() => marks.toggleWatch(symbol)} className="btn-secondary">
        {watching ? "★ Watching" : "☆ Add to watchlist"}
      </button>
      <div className="flex gap-1.5" role="group" aria-label="Assume a position">
        {(["buy", "hold", "sell"] as const).map((a) => {
          const active = stance === a;
          const tone = ASSUME_TONE[a];
          return (
            <button
              key={a}
              type="button"
              aria-pressed={active}
              onClick={() => assume(a)}
              className={`rounded-full px-4 py-1.5 text-xs font-bold transition-colors ${
                active ? tone.on : `bg-surface-muted hover:bg-border ${tone.off}`
              }`}
            >
              {active ? `Assumed ${a}` : `Assume ${a}`}
            </button>
          );
        })}
      </div>
      {(note || marks.error) && <p className="max-w-xs text-right text-xs text-muted-foreground">{marks.error ?? note}</p>}
    </div>
  );
}
