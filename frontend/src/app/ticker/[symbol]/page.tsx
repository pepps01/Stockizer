"use client";

import { use, useEffect, useState } from "react";
import Link from "next/link";
import { api } from "@/lib/api";
import type { Ticker, Financials } from "@/lib/types";
import { AreaChart } from "@/components/market/AreaChart";
import { ActionButtons } from "@/components/selector/ActionButtons";
import { changeColorClass, formatCompactNumber, formatPercent, formatPrice } from "@/lib/format";

export default function TickerDetailPage({ params }: { params: Promise<{ symbol: string }> }) {
  const { symbol } = use(params);
  const [ticker, setTicker] = useState<Ticker | null>(null);
  const [financials, setFinancials] = useState<Financials | null>(null);
  const [history, setHistory] = useState<{ time: string; value: number }[] | null>(null);

  useEffect(() => {
    api.getTicker(symbol).then(({ ticker }) => setTicker(ticker));
    api.getTickerFinancials(symbol).then(({ financials }) => setFinancials(financials));
    api.getTickerHistory(symbol, "3mo").then(({ history }) => setHistory(history));
  }, [symbol]);

  return (
    <main className="mx-auto w-full max-w-4xl flex-1 px-4 py-8 sm:px-6">
      <Link href="/markets" className="text-sm text-muted-foreground hover:text-foreground">
        ← Markets
      </Link>

      {ticker && (
        <div className="mt-2 mb-6">
          <div className="flex flex-wrap items-start justify-between gap-4">
            <div>
              <h1 className="text-2xl font-semibold">
                {ticker.symbol} <span className="text-muted-foreground font-normal">{ticker.name}</span>
              </h1>
              <div className="mt-1 flex items-baseline gap-2">
                <span className="text-xl font-semibold">{formatPrice(ticker.price, ticker.currency ?? "USD")}</span>
                <span className={`text-sm font-medium ${changeColorClass(ticker.change_percent)}`}>
                  {formatPercent(ticker.change_percent)}
                </span>
              </div>
            </div>
            <ActionButtons symbol={ticker.symbol} />
          </div>
          <p className="mt-3 max-w-2xl text-sm text-muted-foreground">{ticker.description}</p>
          <div className="mt-2 flex gap-4 text-sm text-muted-foreground">
            {ticker.sector && <span>Sector: {ticker.sector}</span>}
            {ticker.country && <span>Country: {ticker.country}</span>}
          </div>
        </div>
      )}

      <div className="rounded-xl border border-border bg-surface p-4 sm:p-5">
        {history ? <AreaChart data={history} height={360} /> : <div className="h-[360px] animate-pulse rounded bg-surface-muted" />}
      </div>

      {financials && (
        <dl className="mt-4 grid grid-cols-2 gap-4 rounded-xl border border-border bg-surface p-4 text-sm sm:grid-cols-3 sm:p-5">
          <Stat label="P/E ratio" value={financials.pe_ratio?.toFixed(2) ?? "—"} />
          <Stat label="Forward P/E" value={financials.forward_pe?.toFixed(2) ?? "—"} />
          <Stat label="Market cap" value={formatCompactNumber(financials.market_cap)} />
          <Stat label="EPS" value={formatPrice(financials.eps)} />
          <Stat label="Dividend yield" value={formatPercent(financials.dividend_yield)} />
          <Stat
            label="52w range"
            value={`${formatPrice(financials.fifty_two_week_low)} – ${formatPrice(financials.fifty_two_week_high)}`}
          />
        </dl>
      )}
    </main>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <dt className="text-xs text-muted-foreground">{label}</dt>
      <dd className="font-medium">{value}</dd>
    </div>
  );
}
