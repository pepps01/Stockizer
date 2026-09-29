import Link from "next/link";
import type { SelectorResult } from "@/lib/types";
import { changeColorClass, formatPercent, formatPrice } from "@/lib/format";
import { ActionButtons } from "./ActionButtons";

const ACTION_BADGE: Record<SelectorResult["recommended_action"], string> = {
  buy: "bg-gain/10 text-gain",
  sell: "bg-loss/10 text-loss",
  hold: "bg-surface-muted text-muted-foreground",
};

export function TickerCard({ result }: { result: SelectorResult }) {
  return (
    <div className="rounded-xl border border-border bg-surface p-4 sm:p-5">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <Link href={`/ticker/${result.symbol}`} className="font-semibold hover:text-brand">
            {result.symbol}
          </Link>
          <span className="ml-2 text-sm text-muted-foreground">{result.name}</span>
          <p className="mt-1 text-sm text-muted-foreground max-w-xl">{result.description}</p>
          <div className="mt-2 flex flex-wrap gap-x-4 gap-y-1 text-xs text-muted-foreground">
            {result.country && <span>{result.country}</span>}
            <span>Score {result.score?.toFixed(1) ?? "—"}/5</span>
            <span>{result.index_memberships.join(", ").toUpperCase()}</span>
          </div>
        </div>
        <div className="text-right">
          <p className="font-medium">{formatPrice(result.price)}</p>
          <p className={`text-sm ${changeColorClass(result.change_percent)}`}>{formatPercent(result.change_percent)}</p>
          <span className={`mt-1 inline-block rounded-full px-2 py-0.5 text-xs font-medium ${ACTION_BADGE[result.recommended_action]}`}>
            {result.recommended_action.toUpperCase()}
          </span>
        </div>
      </div>
      <div className="mt-3">
        <ActionButtons symbol={result.symbol} />
      </div>
    </div>
  );
}
