"use client";

import { useEffect, useState } from "react";
import { api } from "@/lib/api";
import type { SelectorResult, StockType } from "@/lib/types";
import { TickerCard } from "@/components/selector/TickerCard";

const STOCK_TYPES: { type: StockType; label: string; hint: string }[] = [
  { type: "growth", label: "Growth", hint: "Higher P/E — priced for future earnings growth" },
  { type: "value", label: "Value", hint: "Lower P/E — potentially undervalued" },
  { type: "equity", label: "Equity", hint: "Blend of growth and value characteristics" },
];

export default function SelectorPage() {
  const [stockType, setStockType] = useState<StockType>("growth");
  const [results, setResults] = useState<SelectorResult[] | null>(null);

  useEffect(() => {
    setResults(null);
    api.runSelector(stockType).then(({ results }) => setResults(results));
  }, [stockType]);

  return (
    <main className="mx-auto w-full max-w-4xl flex-1 px-4 py-8 sm:px-6">
      <h1 className="mb-1 text-2xl font-semibold">Selector</h1>
      <p className="mb-6 text-sm text-muted-foreground">
        Top-ranked tickers by stock type. Recommendations are placeholders pending the real Selector algorithm.
      </p>

      <div className="mb-6 flex flex-wrap gap-2">
        {STOCK_TYPES.map(({ type, label, hint }) => (
          <button
            key={type}
            title={hint}
            onClick={() => setStockType(type)}
            className={`rounded-full border px-4 py-1.5 text-sm font-medium transition-colors ${
              stockType === type
                ? "border-brand bg-brand text-brand-foreground"
                : "border-border text-muted-foreground hover:text-foreground"
            }`}
          >
            {label}
          </button>
        ))}
      </div>

      {!results ? (
        <p className="text-sm text-muted-foreground">Loading…</p>
      ) : results.length === 0 ? (
        <p className="text-sm text-muted-foreground">No tickers currently match this category.</p>
      ) : (
        <div className="flex flex-col gap-3">
          {results.map((result) => (
            <TickerCard key={result.symbol} result={result} />
          ))}
        </div>
      )}
    </main>
  );
}
