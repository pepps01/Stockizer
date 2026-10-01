"use client";

import Link from "next/link";
import { useState } from "react";
import type { MarketRow, Movers } from "@/lib/types";
import { changeClass, currencyLabel, formatNumber, formatPercent, symbolHref } from "@/lib/format";
import { useLiveQuotes } from "@/lib/realtime";
import { Flag } from "@/components/ui/Flag";
import { SourceBadge } from "@/components/ui/Badges";
import { Segmented, Skeleton } from "@/components/ui/primitives";

/** Highest volume · Most volatile · Gainers · Losers, as on TradingView's market pages. */
export function MoversBoard({ movers, loading }: { movers: Movers | null; loading: boolean }) {
  const symbols = movers ? [...movers.highest_volume, ...movers.most_volatile, ...movers.gainers, ...movers.losers].map((r) => r.symbol) : [];
  const live = useLiveQuotes(symbols);
  const [gainersLosers, setGainersLosers] = useState<"gainers" | "losers">("gainers");

  if (loading && !movers) {
    return (
      <div className="grid gap-6 lg:grid-cols-2">
        {[0, 1].map((i) => (
          <Skeleton key={i} className="h-72" />
        ))}
      </div>
    );
  }
  if (!movers) return null;

  return (
    <div className="grid gap-6 lg:grid-cols-2">
      <MoverList title="Highest volume stocks" rows={movers.highest_volume} live={live} detail="volume" />
      <MoverList title="Most volatile stocks" rows={movers.most_volatile} live={live} detail="change" />
      <div className="lg:col-span-2">
        <div className="mb-3 flex items-center justify-between">
          <h3 className="text-lg font-semibold">{gainersLosers === "gainers" ? "Stock gainers" : "Stock losers"}</h3>
          <Segmented
            value={gainersLosers}
            onChange={setGainersLosers}
            options={[
              { value: "gainers", label: "Gainers" },
              { value: "losers", label: "Losers" },
            ]}
          />
        </div>
        <div className="card divide-y divide-border/70 px-4">
          {(gainersLosers === "gainers" ? movers.gainers : movers.losers).map((row) => {
            const q = live[row.symbol] ?? row.quote;
            const pct = q?.change_percent;
            return (
              <Link key={row.symbol} href={symbolHref(row.symbol)} className="flex items-center gap-3 py-3 hover:opacity-80">
                <Identity row={row} />
                <span className="tabular ml-auto text-sm">
                  {formatNumber(q?.price)} <span className="text-[10px] text-muted-foreground">{currencyLabel(row.currency)}</span>
                </span>
                <span className={`tabular w-24 rounded-md px-2 py-1 text-right text-sm font-semibold text-white ${pct != null && pct >= 0 ? "bg-gain" : "bg-loss"}`}>
                  {formatPercent(pct)}
                </span>
              </Link>
            );
          })}
          {!(gainersLosers === "gainers" ? movers.gainers : movers.losers).length && (
            <p className="py-6 text-center text-sm text-muted-foreground">No {gainersLosers} in this market right now.</p>
          )}
        </div>
      </div>
    </div>
  );
}

function MoverList({ title, rows, live, detail }: { title: string; rows: MarketRow[]; live: Record<string, MarketRow["quote"]>; detail: "volume" | "change" }) {
  return (
    <div>
      <h3 className="mb-3 text-lg font-semibold">{title}</h3>
      <div className="card grid grid-cols-1 gap-x-6 px-4 sm:grid-cols-2 lg:grid-cols-1">
        {rows.map((row) => {
          const q = live[row.symbol] ?? row.quote;
          return (
            <Link key={row.symbol} href={symbolHref(row.symbol)} className="flex items-center gap-3 border-b border-border/70 py-3 hover:opacity-80">
              <Identity row={row} />
              <span className="tabular ml-auto shrink-0 whitespace-nowrap text-right text-sm">
                {formatNumber(q?.price)} <span className="text-[10px] text-muted-foreground">{currencyLabel(row.currency)}</span>
                <span className={`block text-xs ${changeClass(q?.change_percent)}`}>
                  {detail === "volume" ? `Vol ${Intl.NumberFormat("en-US", { notation: "compact" }).format(q?.volume ?? 0)} · ` : ""}
                  {formatPercent(q?.change_percent)}
                </span>
              </span>
            </Link>
          );
        })}
      </div>
    </div>
  );
}

function Identity({ row }: { row: MarketRow }) {
  return (
    <span className="flex min-w-0 items-center gap-3">
      <Flag code={row.country_code} size={30} />
      <span className="min-w-0">
        <span className="block truncate text-sm font-medium">{row.name}</span>
        <span className="mt-0.5 flex items-center gap-1.5">
          <span className="rounded bg-surface-muted px-1.5 py-0.5 text-[10px] font-semibold">{row.display_symbol}</span>
          <span className="text-[10px] text-muted-foreground">{row.exchange}</span>
          <SourceBadge source={row.data_source} />
        </span>
      </span>
    </span>
  );
}
