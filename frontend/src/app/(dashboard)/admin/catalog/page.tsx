"use client";

import { useState } from "react";
import { api } from "@/lib/api";
import { useAuth } from "@/lib/auth-context";
import { errorMessage, useAsync } from "@/lib/use-async";
import type { AdminTicker } from "@/lib/types";
import { Tag, Toggle } from "@/components/admin/AdminBits";
import { SourceBadge } from "@/components/ui/Badges";
import { Flag } from "@/components/ui/Flag";
import { EmptyState, ErrorNote, Skeleton } from "@/components/ui/primitives";

export default function AdminCatalogPage() {
  const { token } = useAuth();
  const exchanges = useAsync(() => api.adminExchanges(token!), [token]);
  const [chosen, setChosen] = useState("");
  const code = chosen || exchanges.data?.exchanges[0]?.code || "";
  const tickers = useAsync(() => (code ? api.adminTickers(token!, code) : Promise.resolve({ tickers: [] as AdminTicker[] })), [token, code]);
  const [filter, setFilter] = useState("");
  const [pending, setPending] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const toggle = async (t: AdminTicker) => {
    setPending(t.symbol);
    setError(null);
    try {
      await api.adminSetTickerActive(token!, t.symbol, !t.active);
      tickers.reload();
      exchanges.reload();
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setPending(null);
    }
  };

  const shown = (tickers.data?.tickers ?? []).filter((t) => {
    const q = filter.trim().toLowerCase();
    return !q || t.display_symbol.toLowerCase().includes(q) || t.name.toLowerCase().includes(q);
  });

  return (
    <div className="grid gap-8 lg:grid-cols-[18rem_1fr]">
      <aside>
        <h2 className="label-caps mb-3">Exchanges</h2>
        {!exchanges.data ? (
          <Skeleton className="h-96" />
        ) : (
          <ul className="max-h-[70vh] divide-y divide-border overflow-y-auto border-y border-border">
            {exchanges.data.exchanges.map((e) => (
              <li key={e.code}>
                <button
                  type="button"
                  onClick={() => setChosen(e.code)}
                  aria-current={e.code === code ? "true" : undefined}
                  className={`flex w-full items-center gap-3 px-2 py-2.5 text-left text-sm transition-colors ${
                    e.code === code ? "bg-surface-muted" : "hover:bg-surface-muted"
                  }`}
                >
                  <Flag code={e.country_code} size={18} />
                  <span className="min-w-0 flex-1">
                    <span className="block font-bold">{e.code}</span>
                    <span className="block truncate text-xs text-muted-foreground">{e.name}</span>
                  </span>
                  <span className="tabular text-xs text-muted-foreground">
                    {e.active_stocks}/{e.total_stocks}
                  </span>
                </button>
              </li>
            ))}
          </ul>
        )}
      </aside>

      <section className="min-w-0">
        <div className="mb-4 flex flex-wrap items-end justify-between gap-3">
          <div>
            <h2 className="text-lg font-bold">{code || "Listings"}</h2>
            <p className="text-sm text-muted-foreground">Hidden listings disappear from markets, search and the Selector. Existing runs keep them.</p>
          </div>
          <input className="input max-w-56" placeholder="Filter" value={filter} onChange={(e) => setFilter(e.target.value)} aria-label="Filter listings" />
        </div>
        <ErrorNote message={error ?? tickers.error ?? exchanges.error} />
        {!tickers.data ? (
          <Skeleton className="h-96" />
        ) : !shown.length ? (
          <EmptyState title="No listings match" />
        ) : (
          <ul className="divide-y divide-border border-y border-border">
            {shown.map((t) => (
              <li key={t.symbol} className={`flex items-center gap-3 py-3 ${t.active ? "" : "opacity-60"}`}>
                <span className="min-w-0 flex-1">
                  <span className="flex items-center gap-2">
                    <span className="font-bold">{t.display_symbol}</span>
                    {t.kind === "index" && <Tag>Index</Tag>}
                    <SourceBadge source={t.data_source} />
                  </span>
                  <span className="block truncate text-xs text-muted-foreground">
                    {t.name}
                    {t.sector ? ` · ${t.sector}` : ""}
                  </span>
                </span>
                <Tag tone={t.active ? "gain" : "muted"}>{t.active ? "Listed" : "Hidden"}</Tag>
                <Toggle checked={t.active} disabled={pending === t.symbol} onChange={() => toggle(t)} label={`${t.active ? "Hide" : "List"} ${t.display_symbol}`} />
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}
