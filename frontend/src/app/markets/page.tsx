"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { api } from "@/lib/api";
import type { Exchange } from "@/lib/types";
import { ExchangeStatusBadge } from "@/components/market/ExchangeStatusBadge";

export default function MarketsPage() {
  const [exchanges, setExchanges] = useState<Exchange[] | null>(null);

  useEffect(() => {
    api.listExchanges().then(({ exchanges }) => setExchanges(exchanges));
  }, []);

  return (
    <main className="mx-auto w-full max-w-5xl flex-1 px-4 py-8 sm:px-6">
      <h1 className="mb-6 text-2xl font-semibold">Exchanges</h1>

      {!exchanges ? (
        <p className="text-sm text-muted-foreground">Loading…</p>
      ) : (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          {exchanges.map((exchange) => (
            <Link
              key={exchange.code}
              href={`/markets/${exchange.code}`}
              className="rounded-xl border border-border bg-surface p-4 hover:border-brand transition-colors"
            >
              <div className="flex items-center justify-between">
                <div>
                  <p className="font-medium">{exchange.name}</p>
                  <p className="text-sm text-muted-foreground">{exchange.country}</p>
                </div>
                <ExchangeStatusBadge isOpen={exchange.is_open} />
              </div>
            </Link>
          ))}
        </div>
      )}
    </main>
  );
}
