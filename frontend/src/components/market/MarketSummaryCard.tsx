"use client";

import { useEffect, useState } from "react";
import { api } from "@/lib/api";
import { changeColorClass, formatPercent, formatPrice } from "@/lib/format";
import { AreaChart } from "./AreaChart";

export function MarketSummaryCard({
  symbol,
  label,
  period = "1mo",
  compact = false,
  height,
}: {
  symbol: string;
  label: string;
  period?: string;
  compact?: boolean;
  height?: number;
}) {
  const [history, setHistory] = useState<{ time: string; value: number }[] | null>(null);
  const [quote, setQuote] = useState<{ price: number | null; change_percent: number | null } | null>(null);

  useEffect(() => {
    let cancelled = false;
    api.getTickerHistory(symbol, period).then(({ history }) => {
      if (!cancelled) setHistory(history);
    });
    api.getTicker(symbol).then(({ ticker }) => {
      if (!cancelled) setQuote({ price: ticker.price ?? null, change_percent: ticker.change_percent ?? null });
    });
    return () => {
      cancelled = true;
    };
  }, [symbol, period]);

  return (
    <div className="rounded-xl border border-border bg-surface p-4 sm:p-5">
      <div className="flex items-start justify-between gap-4">
        <div>
          <p className="text-sm font-medium text-muted-foreground">{label}</p>
          <div className="mt-1 flex items-baseline gap-2">
            <span className={compact ? "text-lg font-semibold" : "text-2xl font-semibold"}>
              {quote ? formatPrice(quote.price) : "—"}
            </span>
            <span className={`text-sm font-medium ${quote ? changeColorClass(quote.change_percent) : ""}`}>
              {quote ? formatPercent(quote.change_percent) : ""}
            </span>
          </div>
        </div>
      </div>
      <div className="mt-3">
        {history ? (
          <AreaChart data={history} compact={compact} height={height ?? (compact ? 100 : 320)} />
        ) : (
          <div style={{ height: height ?? (compact ? 100 : 320) }} className="animate-pulse rounded bg-surface-muted" />
        )}
      </div>
    </div>
  );
}
