"use client";

import { useEffect, useState } from "react";
import { api } from "@/lib/api";
import type { Exchange, Ticker } from "@/lib/types";
import { TickerAccordion } from "@/components/financials/TickerAccordion";

export default function FinancialsPage() {
  const [exchanges, setExchanges] = useState<Exchange[] | null>(null);
  const [selectedExchange, setSelectedExchange] = useState<string | null>(null);
  const [tickers, setTickers] = useState<Ticker[] | null>(null);

  useEffect(() => {
    api.listExchanges().then(({ exchanges }) => {
      setExchanges(exchanges);
      setSelectedExchange(exchanges[0]?.code ?? null);
    });
  }, []);

  useEffect(() => {
    if (!selectedExchange) return;
    setTickers(null);
    api.getExchangeTickers(selectedExchange).then(({ tickers }) => setTickers(tickers));
  }, [selectedExchange]);

  return (
    <main className="mx-auto w-full max-w-3xl flex-1 px-4 py-8 sm:px-6">
      <h1 className="mb-2 text-2xl font-semibold">Financials</h1>
      <p className="mb-6 text-sm text-muted-foreground">Select a ticker to view its key financial metrics.</p>

      {exchanges && (
        <div className="mb-4 flex flex-wrap gap-2">
          {exchanges.map((exchange) => (
            <button
              key={exchange.code}
              onClick={() => setSelectedExchange(exchange.code)}
              className={`rounded-full border px-3 py-1.5 text-sm transition-colors ${
                selectedExchange === exchange.code
                  ? "border-brand bg-brand text-brand-foreground"
                  : "border-border text-muted-foreground hover:text-foreground"
              }`}
            >
              {exchange.code}
            </button>
          ))}
        </div>
      )}

      {!tickers ? (
        <p className="text-sm text-muted-foreground">Loading…</p>
      ) : (
        <TickerAccordion tickers={tickers} />
      )}
    </main>
  );
}
