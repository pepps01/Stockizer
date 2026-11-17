"use client";

import Link from "next/link";
import { useState } from "react";
import { api } from "@/lib/api";
import { errorMessage, useAsync } from "@/lib/use-async";
import { useLiveQuotes } from "@/lib/realtime";
import { changeClass, formatNumber, formatPercent, symbolHref } from "@/lib/format";
import { PREFS, sortWatchlist, useBrowserPref } from "@/lib/preferences";
import { Flag } from "@/components/ui/Flag";
import { ErrorNote, Skeleton } from "@/components/ui/primitives";

const SHOWN = 8;

/** Investor profile: the watchlist with live prices, in the order chosen in Settings. */
export function WatchlistSection({ token }: { token: string }) {
  const { data, loading, reload } = useAsync(() => api.watchlist(token), [token]);
  const sort = useBrowserPref(PREFS.watchlistSort);
  const live = useLiveQuotes((data?.items ?? []).map((r) => r.symbol));
  const [error, setError] = useState<string | null>(null);
  const rows = sortWatchlist(data?.items ?? [], sort, live);

  const remove = async (symbol: string) => {
    setError(null);
    try {
      await api.removeFromWatchlist(token, symbol);
      reload();
    } catch (err) {
      setError(errorMessage(err));
    }
  };

  return (
    <section className="flex flex-col gap-3" aria-labelledby="watchlist-title">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <h2 id="watchlist-title" className="label-caps">
          Watchlist{rows.length ? ` · ${rows.length}` : ""}
        </h2>
        <span className="flex gap-4 text-sm font-bold">
          <Link href="/settings" className="text-muted-foreground underline-offset-4 hover:text-foreground hover:underline">
            Order
          </Link>
          {rows.length > SHOWN && (
            <Link href="/watchlist" className="underline-offset-4 hover:underline">
              See all →
            </Link>
          )}
        </span>
      </div>
      <ErrorNote message={error} />
      {loading && !data ? (
        <Skeleton className="h-24" />
      ) : rows.length === 0 ? (
        <p className="border-y border-border py-5 text-sm text-muted-foreground">
          Nothing on your watchlist yet. Use <span className="font-bold text-foreground">Add to watchlist</span> in any ticker&apos;s menu, or the star on a
          symbol page.
        </p>
      ) : (
        <ul className="divide-y divide-border border-y border-border">
          {rows.slice(0, SHOWN).map((row) => {
            const q = live[row.symbol] ?? row.quote;
            return (
              <li key={row.symbol} className="flex items-center gap-4 py-3">
                <Link href={symbolHref(row.symbol)} className="flex min-w-0 flex-1 items-center gap-3">
                  <Flag code={row.country_code} size={22} />
                  <span className="min-w-0">
                    <span className="block font-bold">{row.display_symbol}</span>
                    <span className="block truncate text-xs text-muted-foreground">{row.name}</span>
                  </span>
                </Link>
                <span className="tabular flex flex-col items-end text-sm">
                  <span>{formatNumber(q?.price)}</span>
                  <span className={`text-xs font-bold ${changeClass(q?.change_percent)}`}>{formatPercent(q?.change_percent)}</span>
                </span>
                <button
                  type="button"
                  onClick={() => remove(row.symbol)}
                  aria-label={`Remove ${row.display_symbol} from your watchlist`}
                  title="Remove from watchlist"
                  className="flex h-8 w-8 items-center justify-center rounded-lg text-hold transition-colors hover:bg-surface-muted"
                >
                  <svg viewBox="0 0 24 24" className="h-4 w-4" fill="currentColor" aria-hidden>
                    <path d="M12 3.5l2.6 5.3 5.9.9-4.25 4.1 1 5.8L12 16.9l-5.25 2.7 1-5.8L3.5 9.7l5.9-.9z" />
                  </svg>
                </button>
              </li>
            );
          })}
        </ul>
      )}
    </section>
  );
}
