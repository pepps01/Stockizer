"use client";

import Link from "next/link";
import { useState } from "react";
import { api } from "@/lib/api";
import { errorMessage, useAsync } from "@/lib/use-async";
import { changeClass, formatDateTime, formatNumber, formatPercent, symbolHref } from "@/lib/format";
import type { Stance } from "@/lib/types";
import { AssumeMenu, STANCE_STYLE } from "@/components/symbol/AssumeMenu";
import { Flag } from "@/components/ui/Flag";
import { ErrorNote, Skeleton } from "@/components/ui/primitives";

/** Investor profile: the buy / hold / sell calls assumed from an index's
 * Financials panel, with the price then, the price now and the move since. */
export function AssumedPositions({ token, onChanged }: { token: string; onChanged?: () => void }) {
  const { data, loading, reload } = useAsync(() => api.assumptions(token), [token]);
  const [error, setError] = useState<string | null>(null);

  const change = async (symbol: string, stance: Stance | null) => {
    setError(null);
    try {
      if (stance) await api.setAssumption(token, symbol, stance);
      else await api.clearAssumption(token, symbol);
      reload();
      onChanged?.();
    } catch (err) {
      setError(errorMessage(err));
    }
  };

  const rows = data?.assumptions ?? [];
  const counts = (["buy", "hold", "sell"] as Stance[]).map((s) => [s, rows.filter((r) => r.stance === s).length] as const);

  return (
    <section className="flex flex-col gap-3" aria-labelledby="assumed-title">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <h2 id="assumed-title" className="label-caps">
          Assumed positions
        </h2>
        {rows.length > 0 && (
          <span className="flex gap-2">
            {counts.map(([stance, n]) => (
              <span key={stance} className={`tabular rounded-full px-2.5 py-0.5 text-xs font-bold ${STANCE_STYLE[stance].pill}`}>
                {n} {STANCE_STYLE[stance].label.toLowerCase()}
              </span>
            ))}
          </span>
        )}
      </div>
      <ErrorNote message={error} />
      {loading && !data ? (
        <Skeleton className="h-24" />
      ) : rows.length === 0 ? (
        <p className="border-y border-border py-5 text-sm text-muted-foreground">
          No calls yet. Open any index, choose <span className="font-bold text-foreground">Get Financials</span>, and use{" "}
          <span className="font-bold text-foreground">Assume</span> on a stock to track it here.
        </p>
      ) : (
        <ul className="divide-y divide-border border-y border-border">
          {rows.map((a) => {
            const now = a.quote?.price ?? null;
            return (
              <li key={a.id} className="flex flex-wrap items-center gap-x-4 gap-y-2 py-3">
                <Link href={symbolHref(a.symbol)} className="flex min-w-0 flex-1 items-center gap-3">
                  <Flag code={a.country_code} size={22} />
                  <span className="min-w-0">
                    <span className="block font-bold">{a.display_symbol}</span>
                    <span className="block truncate text-xs text-muted-foreground">{a.name}</span>
                  </span>
                </Link>
                <span className="tabular flex flex-col items-end text-xs">
                  <span className="text-muted-foreground">
                    {formatNumber(a.price)} → <span className="text-foreground">{formatNumber(now)}</span>
                  </span>
                  <span className={`font-bold ${changeClass(a.change_since_percent)}`}>{formatPercent(a.change_since_percent)} since</span>
                </span>
                <span className="hidden w-32 text-right text-xs text-muted-foreground sm:block">{formatDateTime(a.updated_at)}</span>
                <AssumeMenu symbol={a.display_symbol} stance={a.stance} signedIn onChange={(st) => change(a.symbol, st)} />
              </li>
            );
          })}
        </ul>
      )}
    </section>
  );
}
