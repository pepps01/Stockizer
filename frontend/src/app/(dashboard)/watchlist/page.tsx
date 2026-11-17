"use client";

import { api } from "@/lib/api";
import { useAsync } from "@/lib/use-async";
import { PREFS, sortWatchlist, useBrowserPref } from "@/lib/preferences";
import { RequireAuth } from "@/components/auth/RequireAuth";
import { MarketTable } from "@/components/market/MarketTable";
import { EmptyState, ErrorNote, PageHeader, PageShell } from "@/components/ui/primitives";

export default function WatchlistPage() {
  return <RequireAuth feature="watchlist">{(token) => <Watchlist token={token} />}</RequireAuth>;
}

function Watchlist({ token }: { token: string }) {
  const { data, loading, error } = useAsync(() => api.watchlist(token), [token]);
  const sort = useBrowserPref(PREFS.watchlistSort);
  return (
    <PageShell>
      <PageHeader title="Watchlist" subtitle="Symbols you follow, from any exchange, with live prices. Change the order in Settings." />
      <ErrorNote message={error} />
      <section className="border-t border-border pt-5">
        {data && !data.items.length ? (
          <EmptyState title="Your watchlist is empty">Open any symbol and choose “Add to watchlist”.</EmptyState>
        ) : (
          <MarketTable rows={data ? sortWatchlist(data.items, sort) : null} loading={loading} />
        )}
      </section>
    </PageShell>
  );
}
