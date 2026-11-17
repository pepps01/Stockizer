import type { DataSource, SignalType } from "@/lib/types";

export function SourceBadge({ source, className = "" }: { source: DataSource | null | undefined; className?: string }) {
  if (source !== "synthetic") return null;
  return (
    <span
      title="No free live feed covers this market, so prices are simulated by a deterministic model. Do not trade on them."
      className={`inline-flex items-center rounded border border-hold/30 px-1.5 py-px text-[10px] font-bold uppercase tracking-[0.1em] text-hold ${className}`}
    >
      Simulated
    </span>
  );
}

const SIGNAL_STYLES: Record<SignalType, string> = {
  BUY: "bg-gain-soft text-gain",
  SELL: "bg-loss-soft text-loss",
  HOLD: "bg-hold-soft text-hold",
};

export function SignalBadge({ type, size = "md" }: { type: SignalType | null | undefined; size?: "sm" | "md" | "lg" }) {
  if (!type) return <span className="text-muted-foreground">—</span>;
  const sizes = { sm: "px-2.5 py-0.5 text-[11px]", md: "px-3 py-1 text-xs", lg: "px-4 py-1.5 text-base" };
  return <span className={`inline-flex items-center rounded-full font-black tracking-[0.06em] ${SIGNAL_STYLES[type]} ${sizes[size]}`}>{type}</span>;
}

export function RatingLabel({ label }: { label: string | null | undefined }) {
  if (!label) return <span className="text-muted-foreground">—</span>;
  const lower = label.toLowerCase();
  const tone = lower.includes("buy") ? "text-gain" : lower.includes("sell") ? "text-loss" : "text-muted-foreground";
  const arrow = label === "Strong buy" ? "⇈" : label === "Buy" ? "↑" : label === "Strong sell" ? "⇊" : label === "Sell" ? "↓" : "=";
  return (
    <span className={`inline-flex items-center gap-1 whitespace-nowrap font-bold ${tone}`}>
      <span aria-hidden className="text-xs">{arrow}</span>
      {label}
    </span>
  );
}

export function MarketStatus({ open, localTime }: { open: boolean; localTime?: string }) {
  return (
    <span className="inline-flex items-center gap-1.5 text-xs text-muted-foreground" title={localTime ? `Local time ${localTime}` : undefined}>
      <span className={`h-2 w-2 rounded-full ${open ? "bg-gain" : "bg-muted-foreground/50"}`} />
      {open ? "Market open" : "Market closed"}
    </span>
  );
}
