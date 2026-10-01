"use client";

import { api } from "@/lib/api";
import { useAsync } from "@/lib/use-async";
import { RequireAuth } from "@/components/auth/RequireAuth";
import { MarketTable } from "@/components/market/MarketTable";
import { EmptyState, ErrorNote, PageHeader, PageShell } from "@/components/ui/primitives";

export default function WatchlistPage() {
  return <RequireAuth feature="watchlist">{(token) => <Watchlist token={token} />}</RequireAuth>;
}

function Watchlist({ token }: { token: string }) {
  const { data, loading, error } = useAsync(() => api.watchlist(token), [token]);
  return (
    <PageShell>
      <PageHeader title="Watchlist" subtitle="Symbols you follow, from any exchange, with live prices." />
      <ErrorNote message={error} />
      <section className="card p-5">
        {data && !data.items.length ? (
          <EmptyState title="Your watchlist is empty">Open any symbol and choose “Add to watchlist”.</EmptyState>
        ) : (
          <MarketTable rows={data?.items ?? null} loading={loading} />
        )}
      </section>
    </PageShell>
  );
}
