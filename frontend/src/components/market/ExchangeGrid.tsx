import Link from "next/link";
import type { Exchange } from "@/lib/types";
import { Flag } from "@/components/ui/Flag";
import { MarketStatus, SourceBadge } from "@/components/ui/Badges";

export function ExchangeGrid({ exchanges }: { exchanges: Exchange[] }) {
  return (
    <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
      {exchanges.map((e) => (
        <Link key={e.code} href={`/markets/${e.code}`} className="card flex items-start gap-3 p-4 transition-shadow hover:shadow-md">
          <Flag code={e.country_code} size={32} />
          <div className="min-w-0 flex-1">
            <div className="flex items-center gap-2">
              <span className="font-semibold">{e.code}</span>
              <SourceBadge source={e.data_source} />
            </div>
            <p className="truncate text-sm text-muted-foreground">{e.name}</p>
            <div className="mt-2 flex flex-wrap items-center gap-x-3 gap-y-1">
              <MarketStatus open={e.is_open} localTime={e.local_time} />
              <span className="text-xs text-muted-foreground">
                {e.opens_at}–{e.closes_at} local · {e.stock_count ?? 0} stocks
              </span>
            </div>
          </div>
        </Link>
      ))}
    </div>
  );
}
