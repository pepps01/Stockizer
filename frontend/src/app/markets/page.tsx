"use client";

import { use } from "react";
import { useRouter } from "next/navigation";
import { api } from "@/lib/api";
import { useAsync } from "@/lib/use-async";
import { CountrySelector } from "@/components/market/CountrySelector";
import { MarketTable } from "@/components/market/MarketTable";
import { MoversBoard } from "@/components/market/MoversBoard";
import { ExchangeGrid } from "@/components/market/ExchangeGrid";
import { Flag } from "@/components/ui/Flag";
import { EmptyState, ErrorNote, PageHeader, PageShell } from "@/components/ui/primitives";

export default function MarketsPage({ searchParams }: { searchParams: Promise<{ country?: string }> }) {
  const { country: rawCountry } = use(searchParams);
  const country = rawCountry?.toUpperCase() || null;
  const router = useRouter();

  const indices = useAsync(() => api.indices(country), [country]);
  const movers = useAsync(() => api.movers({ country, limit: 6 }), [country]);
  const exchanges = useAsync(() => api.exchanges(country), [country]);
  const countryName = exchanges.data?.exchanges[0]?.country;

  return (
    <PageShell>
      <PageHeader
        icon={country ? <Flag code={country} size={44} /> : undefined}
        title={country ? `${countryName ?? country} stock market` : "World stock markets"}
        subtitle="Major indices, the day's movers and every covered exchange. Prices stream live; markets without a free feed are clearly marked as simulated."
        actions={<CountrySelector value={country} onChange={(code) => router.replace(code ? `/markets?country=${code}` : "/markets")} />}
      />

      <ErrorNote message={indices.error || movers.error || exchanges.error} />

      <section className="card p-5">
        <h2 className="mb-4 text-xl font-semibold">{country ? "Indices" : "Major world indices"}</h2>
        {indices.data && !indices.data.indices.length ? (
          <EmptyState title="No index tracked for this country yet" />
        ) : (
          <MarketTable rows={indices.data?.indices ?? null} loading={indices.loading} showCountry={!country} />
        )}
      </section>

      <section className="mt-8">
        <MoversBoard movers={movers.data} loading={movers.loading} />
      </section>

      <section className="mt-10">
        <h2 className="mb-4 text-xl font-semibold">Exchanges</h2>
        <ExchangeGrid exchanges={exchanges.data?.exchanges ?? []} />
      </section>
    </PageShell>
  );
}
