"use client";

import Link from "next/link";
import { useState } from "react";
import type { MarketRow } from "@/lib/types";
import { changeClass, currencyLabel, formatCompact, formatNumber, formatPercent, formatSigned, symbolHref } from "@/lib/format";
import { useLiveQuotes } from "@/lib/realtime";
import { Flag } from "@/components/ui/Flag";
import { RatingLabel, SourceBadge } from "@/components/ui/Badges";
import { Segmented, Skeleton } from "@/components/ui/primitives";

type View = "overview" | "performance" | "technicals";

const PERF_COLUMNS: { key: keyof NonNullable<MarketRow["performance"]>; label: string }[] = [
  { key: "perf_1w", label: "1W" },
  { key: "perf_1m", label: "1M" },
  { key: "perf_3m", label: "3M" },
  { key: "perf_6m", label: "6M" },
  { key: "perf_ytd", label: "YTD" },
  { key: "perf_1y", label: "1Y" },
];

/** Indices / stocks table with TradingView's Overview · Performance · Technicals tabs. Quotes stream live. */
export function MarketTable({
  rows,
  loading,
  showCountry = true,
  symbolLabel = "Symbol",
  showVolume = false,
  action,
  rowMenu,
}: {
  rows: MarketRow[] | null;
  loading?: boolean;
  showCountry?: boolean;
  symbolLabel?: string;
  /** Adds a Volume column to the Overview tab. */
  showVolume?: boolean;
  /** Rendered beside the view tabs, e.g. a "Get Financials" button. */
  action?: React.ReactNode;
  /** A per-row control in a last column, e.g. the Assume / watchlist menu. */
  rowMenu?: (row: MarketRow) => React.ReactNode;
}) {
  const [view, setView] = useState<View>("overview");
  const live = useLiveQuotes(rows?.map((r) => r.symbol) ?? []);

  return (
    <div>
      <div className="flex flex-wrap items-center justify-between gap-3">
        <Segmented
          value={view}
          onChange={setView}
          options={[
            { value: "overview", label: "Overview" },
            { value: "performance", label: "Performance" },
            { value: "technicals", label: "Technicals" },
          ]}
        />
        {action}
      </div>
      <div className="mt-4 overflow-x-auto">
        <table className="w-full min-w-[760px] text-sm">
          <thead>
            <tr className="border-b border-border text-xs text-muted-foreground">
              <th className="py-2 pr-3 text-left font-normal">
                {symbolLabel} <span className="block text-[11px]">{rows?.length ?? ""}</span>
              </th>
              {view === "overview" && ["Price", "Chg %", "Chg", "High", "Low", ...(showVolume ? ["Volume"] : []), "Tech rating"].map((h) => <Th key={h}>{h}</Th>)}
              {view === "performance" && [...PERF_COLUMNS.map((c) => c.label), "Volatility 1M"].map((h) => <Th key={h}>{h}</Th>)}
              {view === "technicals" && ["Tech rating", "MA rating", "Oscillators rating"].map((h) => <Th key={h}>{h}</Th>)}
              {rowMenu && <th className="w-px py-2 pl-2" aria-label="Actions" />}
            </tr>
          </thead>
          <tbody>
            {loading && !rows?.length &&
              Array.from({ length: 8 }).map((_, i) => (
                <tr key={i} className="border-b border-border/60">
                  <td colSpan={10} className="py-3">
                    <Skeleton className="h-6 w-full" />
                  </td>
                </tr>
              ))}
            {rows?.map((row) => {
              const q = live[row.symbol] ?? row.quote;
              const unit = row.kind === "index" ? "" : currencyLabel(row.currency);
              return (
                <tr key={row.symbol} className="border-b border-border/60 transition-colors hover:bg-surface-muted/60">
                  <td className="py-2.5 pr-3">
                    <Link href={symbolHref(row.symbol)} className="flex items-center gap-3">
                      {showCountry && <Flag code={row.country_code} size={24} />}
                      <span className="rounded bg-surface-muted px-2 py-0.5 text-[11px] font-semibold">{row.display_symbol}</span>
                      <span className="truncate hover:text-brand">{row.name}</span>
                      <SourceBadge source={row.data_source} />
                    </Link>
                  </td>
                  {view === "overview" && (
                    <>
                      <Td>
                        {formatNumber(q?.price)} <Unit>{unit}</Unit>
                      </Td>
                      <Td className={changeClass(q?.change_percent)}>{formatPercent(q?.change_percent)}</Td>
                      <Td className={changeClass(q?.change)}>
                        {formatSigned(q?.change)} <Unit>{unit}</Unit>
                      </Td>
                      <Td>{formatNumber(q?.high)}</Td>
                      <Td>{formatNumber(q?.low)}</Td>
                      {showVolume && <Td>{formatCompact(q?.volume)}</Td>}
                      <Td>
                        <RatingLabel label={row.technicals?.label} />
                      </Td>
                    </>
                  )}
                  {view === "performance" && (
                    <>
                      {PERF_COLUMNS.map((c) => (
                        <Td key={c.key} className={changeClass(row.performance?.[c.key])}>
                          {formatPercent(row.performance?.[c.key])}
                        </Td>
                      ))}
                      <Td>{row.performance?.volatility_1m != null ? `${row.performance.volatility_1m.toFixed(2)}%` : "—"}</Td>
                    </>
                  )}
                  {view === "technicals" && (
                    <>
                      <Td>
                        <RatingLabel label={row.technicals?.label} />
                      </Td>
                      <Td>
                        <RatingLabel label={row.technicals?.ma_label} />
                      </Td>
                      <Td>
                        <RatingLabel label={row.technicals?.osc_label} />
                      </Td>
                    </>
                  )}
                  {rowMenu && <td className="py-1.5 pl-2 text-right">{rowMenu(row)}</td>}
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function Th({ children }: { children: React.ReactNode }) {
  return <th className="px-3 py-2 text-right font-normal">{children}</th>;
}

function Td({ children, className = "" }: { children: React.ReactNode; className?: string }) {
  return <td className={`tabular whitespace-nowrap px-3 py-2.5 text-right ${className}`}>{children}</td>;
}

function Unit({ children }: { children: React.ReactNode }) {
  return children ? <span className="text-[10px] text-muted-foreground">{children}</span> : null;
}
