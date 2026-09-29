"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { use } from "react";
import { api } from "@/lib/api";
import type { Exchange, Ticker } from "@/lib/types";
import { ExchangeStatusBadge } from "@/components/market/ExchangeStatusBadge";
import { changeColorClass, formatPercent, formatPrice } from "@/lib/format";

export default function ExchangeTickersPage({ params }: { params: Promise<{ exchange: string }> }) {
  const { exchange: exchangeCode } = use(params);
  const [exchange, setExchange] = useState<Exchange | null>(null);
  const [tickers, setTickers] = useState<Ticker[] | null>(null);

  useEffect(() => {
    api.getExchangeTickers(exchangeCode).then(({ exchange, tickers }) => {
      setExchange(exchange);
      setTickers(tickers);
    });
  }, [exchangeCode]);

  return (
    <main className="mx-auto w-full max-w-5xl flex-1 px-4 py-8 sm:px-6">
      <Link href="/markets" className="text-sm text-muted-foreground hover:text-foreground">
        ← Exchanges
      </Link>

      {exchange && (
        <div className="mt-2 mb-6 flex items-center gap-3">
          <h1 className="text-2xl font-semibold">{exchange.name}</h1>
          <ExchangeStatusBadge isOpen={exchange.is_open} />
        </div>
      )}

      {!tickers ? (
        <p className="text-sm text-muted-foreground">Loading…</p>
      ) : (
        <div className="overflow-x-auto rounded-xl border border-border bg-surface">
          <table className="w-full text-sm">
            <thead className="border-b border-border text-left text-muted-foreground">
              <tr>
                <th className="px-4 py-3 font-medium">Symbol</th>
                <th className="hidden px-4 py-3 font-medium sm:table-cell">Name</th>
                <th className="px-4 py-3 text-right font-medium">Price</th>
                <th className="px-4 py-3 text-right font-medium">Change</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {tickers.map((ticker) => (
                <tr key={ticker.symbol}>
                  <td className="px-4 py-3">
                    <Link
                      href={`/ticker/${ticker.symbol}`}
                      className="font-medium text-brand hover:underline"
                    >
                      {ticker.symbol}
                    </Link>
                  </td>
                  <td className="hidden px-4 py-3 text-muted-foreground sm:table-cell">{ticker.name}</td>
                  <td className="px-4 py-3 text-right">{formatPrice(ticker.price)}</td>
                  <td className={`px-4 py-3 text-right ${changeColorClass(ticker.change_percent)}`}>
                    {formatPercent(ticker.change_percent)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </main>
  );
}
