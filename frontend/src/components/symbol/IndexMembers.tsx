"use client";

import { useCallback, useState } from "react";
import { useAuth } from "@/lib/auth-context";
import type { IndexMembers as IndexMembersData } from "@/lib/types";
import { useTickerMarks } from "@/lib/use-ticker-marks";
import { AssumeMenu } from "./AssumeMenu";
import { MarketTable } from "@/components/market/MarketTable";
import { Card, EmptyState, ErrorNote } from "@/components/ui/primitives";
import { FinancialsDrawer } from "./FinancialsDrawer";

/** On an index's page: the stocks of its market, with highs, lows and volume,
 * and a "Get Financials" button that opens the stock-type drawer. */
export function IndexMembers({
  symbol,
  indexName,
  data,
  loading,
  error,
}: {
  symbol: string;
  indexName: string;
  data: IndexMembersData | null;
  loading: boolean;
  error: string | null;
}) {
  const [open, setOpen] = useState(false);
  const close = useCallback(() => setOpen(false), []);
  const { token } = useAuth();
  const marks = useTickerMarks(token, Boolean(data));

  if (data && data.stocks.length === 0) {
    return (
      <Card title="Stocks">
        <EmptyState title="No member stocks">{indexName} measures market volatility rather than a basket of companies.</EmptyState>
      </Card>
    );
  }

  return (
    <Card title={`Stocks in ${indexName}`}>
      <p className="-mt-2 mb-4 max-w-3xl text-sm text-muted-foreground">
        The companies Stockiser covers in this index&apos;s market{data && data.countries.length > 1 ? ` (${data.countries.join(", ")})` : ""}. It is not
        the index&apos;s full membership list.
      </p>
      <ErrorNote message={error ?? (open ? null : marks.error)} />
      <MarketTable
        rows={data?.stocks ?? null}
        loading={loading}
        showCountry={(data?.countries.length ?? 1) > 1}
        symbolLabel="Stock"
        showVolume
        rowMenu={(row) => (
          <AssumeMenu
            symbol={row.display_symbol}
            stance={marks.stanceOf(row.symbol)}
            signedIn={marks.signedIn}
            onChange={(st) => marks.assume(row.symbol, st)}
            watching={marks.isWatching(row.symbol)}
            onToggleWatch={() => marks.toggleWatch(row.symbol)}
          />
        )}
        action={
          <button type="button" className="btn-action" onClick={() => setOpen(true)} disabled={!data}>
            <svg viewBox="0 0 24 24" className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" aria-hidden>
              <path d="M4 19V9M10 19V5M16 19v-7M22 19H2" />
            </svg>
            Get Financials
            <svg viewBox="0 0 24 24" className="btn-action-arrow h-4 w-4" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" aria-hidden>
              <path d="M5 12h14M13 6l6 6-6 6" />
            </svg>
          </button>
        }
      />
      <FinancialsDrawer symbol={symbol} indexName={indexName} open={open} onClose={close} marks={marks} />
    </Card>
  );
}
