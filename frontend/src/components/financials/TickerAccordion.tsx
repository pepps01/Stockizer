"use client";

import * as Accordion from "@radix-ui/react-accordion";
import { useState } from "react";
import { api } from "@/lib/api";
import type { Financials, TickerMeta } from "@/lib/types";
import { formatCompactNumber, formatPercent, formatPrice } from "@/lib/format";

export function TickerAccordion({ tickers }: { tickers: TickerMeta[] }) {
  return (
    <Accordion.Root type="single" collapsible className="divide-y divide-border rounded-xl border border-border bg-surface">
      {tickers.map((ticker) => (
        <TickerAccordionItem key={ticker.symbol} ticker={ticker} />
      ))}
    </Accordion.Root>
  );
}

function TickerAccordionItem({ ticker }: { ticker: TickerMeta }) {
  const [financials, setFinancials] = useState<Financials | null>(null);
  const [loading, setLoading] = useState(false);

  const handleOpenChange = (value: string) => {
    if (value && !financials && !loading) {
      setLoading(true);
      api
        .getTickerFinancials(ticker.symbol)
        .then(({ financials }) => setFinancials(financials))
        .finally(() => setLoading(false));
    }
  };

  return (
    <Accordion.Item value={ticker.symbol} onFocusCapture={() => {}}>
      <Accordion.Header>
        <Accordion.Trigger
          onClick={() => handleOpenChange(ticker.symbol)}
          className="group flex w-full items-center justify-between px-4 py-3.5 text-left hover:bg-surface-muted transition-colors"
        >
          <span>
            <span className="font-medium">{ticker.symbol}</span>
            <span className="ml-2 text-sm text-muted-foreground">{ticker.name}</span>
          </span>
          <span className="text-muted-foreground transition-transform group-data-[state=open]:rotate-180">⌄</span>
        </Accordion.Trigger>
      </Accordion.Header>
      <Accordion.Content className="px-4 pb-4">
        {loading && <p className="text-sm text-muted-foreground">Loading financials…</p>}
        {financials && (
          <dl className="grid grid-cols-2 gap-3 text-sm sm:grid-cols-3">
            <Stat label="P/E ratio" value={financials.pe_ratio?.toFixed(2) ?? "—"} />
            <Stat label="Forward P/E" value={financials.forward_pe?.toFixed(2) ?? "—"} />
            <Stat label="Market cap" value={formatCompactNumber(financials.market_cap)} />
            <Stat label="EPS" value={formatPrice(financials.eps)} />
            <Stat label="Dividend yield" value={formatPercent(financials.dividend_yield)} />
            <Stat label="52w range" value={`${formatPrice(financials.fifty_two_week_low)} – ${formatPrice(financials.fifty_two_week_high)}`} />
          </dl>
        )}
      </Accordion.Content>
    </Accordion.Item>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <dt className="text-xs text-muted-foreground">{label}</dt>
      <dd className="font-medium">{value}</dd>
    </div>
  );
}
