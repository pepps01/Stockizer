"use client";

import { useEffect, useState } from "react";
import { api } from "@/lib/api";
import { changeColorClass, formatPercent, formatPrice } from "@/lib/format";

export function IndexQuoteRow({ symbol, label }: { symbol: string; label: string }) {
  const [quote, setQuote] = useState<{ price: number | null; change_percent: number | null } | null>(null);

  useEffect(() => {
    let cancelled = false;
    api.getTicker(symbol).then(({ ticker }) => {
      if (!cancelled) setQuote({ price: ticker.price ?? null, change_percent: ticker.change_percent ?? null });
    });
    return () => {
      cancelled = true;
    };
  }, [symbol]);

  return (
    <li className="flex items-center justify-between py-3 text-sm">
      <span>{label}</span>
      <span className="text-right">
        <span className="font-medium">{quote ? formatPrice(quote.price) : "—"}</span>{" "}
        <span className={quote ? changeColorClass(quote.change_percent) : ""}>
          {quote ? formatPercent(quote.change_percent) : ""}
        </span>
      </span>
    </li>
  );
}
