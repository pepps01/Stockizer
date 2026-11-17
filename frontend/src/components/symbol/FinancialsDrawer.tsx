"use client";

import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import { api } from "@/lib/api";
import { useAsync } from "@/lib/use-async";
import { changeClass, formatCompact, formatNumber, formatPercent, symbolHref } from "@/lib/format";
import type { FinancialSegment, FinancialStock } from "@/lib/types";
import type { TickerMarks } from "@/lib/use-ticker-marks";
import { AssumeMenu } from "./AssumeMenu";
import { Flag } from "@/components/ui/Flag";
import { SourceBadge } from "@/components/ui/Badges";
import { ErrorNote, Skeleton } from "@/components/ui/primitives";

const TONE: Record<FinancialSegment["key"], string> = {
  growth: "bg-gain",
  value: "bg-brand",
  equity: "bg-foreground",
};

/** Right-hand drawer: the index's stocks as Growth / Value / Equity accordions.
 * It slides in from the right; data loads the first time it opens. */
export function FinancialsDrawer({
  symbol,
  indexName,
  open,
  onClose,
  marks,
}: {
  symbol: string;
  indexName: string;
  open: boolean;
  onClose: () => void;
  marks: TickerMarks;
}) {
  const [requested, setRequested] = useState(false);
  const [expanded, setExpanded] = useState<FinancialSegment["key"] | null>("growth");
  const closeRef = useRef<HTMLButtonElement>(null);
  const { data, error } = useAsync(() => (requested ? api.indexFinancials(symbol) : Promise.resolve(null)), [symbol, requested]);
  // First open triggers the fetch; later opens reuse it.
  if (open && !requested) setRequested(true);

  useEffect(() => {
    if (!open) return;
    closeRef.current?.focus();
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    const overflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    window.addEventListener("keydown", onKey);
    return () => {
      window.removeEventListener("keydown", onKey);
      document.body.style.overflow = overflow;
    };
  }, [open, onClose]);

  const total = data?.segments.find((s) => s.key === "equity")?.stocks.length ?? 0;

  return (
    <div className="drawer-root fixed inset-0 z-[60]" data-open={open} aria-hidden={!open} inert={!open}>
      <div className="drawer-backdrop absolute inset-0 bg-[rgba(16,20,24,0.42)] backdrop-blur-[2px]" onClick={onClose} />
      <aside
        role="dialog"
        aria-modal="true"
        aria-labelledby="financials-title"
        className="drawer-panel absolute inset-y-0 right-0 flex w-full max-w-[580px] flex-col bg-surface shadow-[-24px_0_60px_-30px_rgba(16,20,24,0.45)]"
      >
        <header className="flex items-start justify-between gap-4 border-b border-border px-6 pb-5 pt-[max(1.5rem,env(safe-area-inset-top))]">
          <div className="min-w-0">
            <p className="label-caps">Financials</p>
            <h2 id="financials-title" className="mt-1 truncate text-2xl font-bold">
              {indexName}
            </h2>
            <p className="mt-1 text-sm text-muted-foreground">
              {data ? `${total} stocks, sorted into the three stock types.` : "Sorting the market into stock types…"}
            </p>
          </div>
          <button
            ref={closeRef}
            type="button"
            onClick={onClose}
            aria-label="Close financials"
            className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-surface-muted transition-colors hover:bg-border"
          >
            <svg viewBox="0 0 24 24" className="h-5 w-5" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" aria-hidden>
              <path d="M6 6l12 12M18 6L6 18" />
            </svg>
          </button>
        </header>

        <div className="flex-1 overflow-y-auto px-6 py-5">
          <ErrorNote message={error ?? marks.error} />
          {!data && !error && (
            <div className="space-y-3">
              {[0, 1, 2].map((i) => (
                <Skeleton key={i} className="h-20" />
              ))}
            </div>
          )}
          {data && (
            <div className="drawer-stagger flex flex-col gap-3">
              {data.segments.map((segment) => (
                <Segment
                  key={segment.key}
                  segment={segment}
                  open={expanded === segment.key}
                  onToggle={() => setExpanded(expanded === segment.key ? null : segment.key)}
                  marks={marks}
                />
              ))}
              <p className="pt-2 text-xs leading-relaxed text-muted-foreground">
                Growth and value are judged against the other stocks on the same exchange, from P/E, price-to-book, dividend
                yield and revenue and earnings growth. The middle third is neither, so it appears only under Equity.
                {data.unclassified > 0 && ` ${data.unclassified} stock${data.unclassified === 1 ? " has" : "s have"} no fundamentals to judge.`}
              </p>
            </div>
          )}
        </div>
      </aside>
    </div>
  );
}

function Segment({ segment, open, onToggle, marks }: { segment: FinancialSegment; open: boolean; onToggle: () => void; marks: TickerMarks }) {
  const id = `segment-${segment.key}`;
  return (
    <section className={`rounded-2xl border transition-colors ${open ? "border-foreground/15 bg-surface" : "border-border bg-surface-muted/40"}`}>
      <h3>
        <button type="button" aria-expanded={open} aria-controls={id} onClick={onToggle} className="flex w-full items-center gap-3 px-5 py-4 text-left">
          <span className={`h-2.5 w-2.5 shrink-0 rounded-full ${TONE[segment.key]}`} aria-hidden />
          <span className="flex-1 text-[17px] font-bold">{segment.label}</span>
          <span className="tabular rounded-full bg-surface-muted px-2.5 py-0.5 text-xs font-bold text-muted-foreground">{segment.stocks.length}</span>
          <svg viewBox="0 0 24 24" className={`accordion-chevron h-5 w-5 text-muted-foreground ${open ? "rotate-180" : ""}`} fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" aria-hidden>
            <path d="M6 9l6 6 6-6" />
          </svg>
        </button>
      </h3>
      <div id={id} className="accordion-body" data-open={open}>
        <div className="min-h-0 overflow-hidden">
          <div className="px-5 pb-5">
            <p className="text-sm leading-relaxed text-muted-foreground">{segment.definition}</p>
            <ul className="mt-3 flex flex-wrap gap-1.5" aria-label={`${segment.label} traits`}>
              {segment.traits.map((t) => (
                <li key={t} className="rounded-full bg-surface-muted px-2.5 py-1 text-[11px] font-bold">
                  {t}
                </li>
              ))}
            </ul>
            {segment.stocks.length === 0 ? (
              <p className="mt-4 text-sm text-muted-foreground">No stocks in this market fit this type right now.</p>
            ) : (
              <ul className="mt-4 divide-y divide-border border-y border-border">
                {segment.stocks.map((stock) => (
                  <StockRow key={stock.symbol} stock={stock} showStyle={segment.key === "equity"} marks={marks} />
                ))}
              </ul>
            )}
          </div>
        </div>
      </div>
    </section>
  );
}

function StockRow({ stock, showStyle, marks }: { stock: FinancialStock; showStyle: boolean; marks: TickerMarks }) {
  const f = stock.fundamentals;
  const q = stock.quote;
  const growth = f.revenue_growth != null ? `${f.revenue_growth >= 0 ? "+" : ""}${(f.revenue_growth * 100).toFixed(1)}%` : "—";
  return (
    <li className="flex items-start gap-2 py-1">
      <Link href={symbolHref(stock.symbol)} className="-ml-2 flex min-w-0 flex-1 flex-col gap-1.5 rounded-lg px-2 py-2 transition-colors hover:bg-surface-muted">
        <span className="flex items-center gap-2.5">
          <Flag code={stock.country_code} size={20} />
          <span className="font-bold">{stock.display_symbol}</span>
          <span className="min-w-0 flex-1 truncate text-sm text-muted-foreground">{stock.name}</span>
          <span className="tabular text-sm">{formatNumber(q?.price)}</span>
          <span className={`tabular w-16 text-right text-xs font-bold ${changeClass(q?.change_percent)}`}>{formatPercent(q?.change_percent)}</span>
        </span>
        <span className="tabular flex flex-wrap items-center gap-x-4 gap-y-1 pl-[30px] text-xs text-muted-foreground">
          <span>P/E {formatNumber(f.pe_ratio, 1)}</span>
          <span>P/B {formatNumber(f.price_to_book, 1)}</span>
          <span>Div {f.dividend_yield != null ? `${f.dividend_yield.toFixed(2)}%` : "—"}</span>
          <span>Rev growth {growth}</span>
          <span>Cap {formatCompact(f.market_cap)}</span>
          {showStyle && stock.style && <span className="text-[10px] font-bold uppercase tracking-[0.1em] text-foreground">{stock.style}</span>}
          <SourceBadge source={stock.data_source} />
        </span>
      </Link>
      <div className="pt-2">
        <AssumeMenu
          symbol={stock.display_symbol}
          stance={marks.stanceOf(stock.symbol)}
          signedIn={marks.signedIn}
          onChange={(st) => marks.assume(stock.symbol, st)}
          watching={marks.isWatching(stock.symbol)}
          onToggleWatch={() => marks.toggleWatch(stock.symbol)}
        />
      </div>
    </li>
  );
}
