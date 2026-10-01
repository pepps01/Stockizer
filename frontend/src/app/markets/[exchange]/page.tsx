"use client";

import Link from "next/link";
import { use } from "react";
import { api } from "@/lib/api";
import { useAsync } from "@/lib/use-async";
import { currencyLabel } from "@/lib/format";
import { MarketTable } from "@/components/market/MarketTable";
import { MoversBoard } from "@/components/market/MoversBoard";
import { Flag } from "@/components/ui/Flag";
import { MarketStatus, SourceBadge } from "@/components/ui/Badges";
import { ErrorNote, PageHeader, PageShell, Skeleton } from "@/components/ui/primitives";

const DAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

export default function ExchangePage({ params }: { params: Promise<{ exchange: string }> }) {
  const { exchange: code } = use(params);
  const listing = useAsync(() => api.exchange(code), [code]);
  const movers = useAsync(() => api.movers({ exchange: code, limit: 4 }), [code]);
  const exchange = listing.data?.exchange;

  return (
    <PageShell>
      <Link href={exchange ? `/markets?country=${exchange.country_code}` : "/markets"} className="text-sm text-muted-foreground hover:text-foreground">
        ← {exchange?.country ?? "Markets"}
      </Link>
      {exchange ? (
        <div className="mt-2">
          <PageHeader
            icon={<Flag code={exchange.country_code} size={48} />}
            title={
              <span className="flex flex-wrap items-center gap-3">
                {exchange.name} <SourceBadge source={exchange.data_source} />
              </span>
            }
            subtitle={
              <span className="flex flex-wrap items-center gap-x-4 gap-y-1">
                <MarketStatus open={exchange.is_open} localTime={exchange.local_time} />
                <span>
                  {exchange.trading_days.map((d) => DAYS[d]).join(" · ")} · {exchange.opens_at}–{exchange.closes_at} ({exchange.timezone})
                </span>
                <span>Local time {exchange.local_time.slice(11)}</span>
                <span>Quoted in {currencyLabel(exchange.currency)}</span>
              </span>
            }
            actions={
              <Link href={`/selector?exchange=${exchange.code}`} className="btn-primary">
                Rank this exchange →
              </Link>
            }
          />
        </div>
      ) : (
        <Skeleton className="mt-4 h-16 w-2/3" />
      )}

      <ErrorNote message={listing.error} />

      {!!listing.data?.indices.length && (
        <section className="card mb-6 p-5">
          <h2 className="mb-4 text-lg font-semibold">Indices</h2>
          <MarketTable rows={listing.data.indices} showCountry={false} />
        </section>
      )}

      <section className="card p-5">
        <h2 className="mb-4 text-lg font-semibold">Listed stocks</h2>
        <MarketTable rows={listing.data?.stocks ?? null} loading={listing.loading} showCountry={false} />
      </section>

      <section className="mt-8">
        <MoversBoard movers={movers.data} loading={movers.loading} />
      </section>
    </PageShell>
  );
}
