import type { Technicals } from "@/lib/types";
import { formatNumber } from "@/lib/format";
import { RatingLabel } from "@/components/ui/Badges";
import { Card } from "@/components/ui/primitives";

const INDICATOR_LABELS: Record<string, string> = {
  rsi14: "RSI (14)",
  stoch_k: "Stochastic %K",
  cci20: "CCI (20)",
  macd: "MACD (12, 26)",
  williams_r: "Williams %R",
  sma50: "SMA (50)",
  sma200: "SMA (200)",
  ema20: "EMA (20)",
};

export function TechnicalsCard({ technicals }: { technicals: Technicals }) {
  return (
    <Card title="Technicals">
      <Gauge value={technicals.summary} />
      <div className="mt-2 text-center text-lg font-bold">
        <RatingLabel label={technicals.label} />
      </div>
      <div className="mt-5 grid grid-cols-2 gap-4 border-y border-border py-3 text-sm">
        <div className="text-center">
          <div className="text-xs text-muted-foreground">Moving averages</div>
          <RatingLabel label={technicals.ma_label} />
        </div>
        <div className="text-center">
          <div className="text-xs text-muted-foreground">Oscillators</div>
          <RatingLabel label={technicals.osc_label} />
        </div>
      </div>
      <dl className="mt-4 space-y-1.5 text-sm">
        {Object.entries(INDICATOR_LABELS).map(([key, label]) =>
          technicals.indicators?.[key] != null ? (
            <div key={key} className="flex justify-between">
              <dt className="text-muted-foreground">{label}</dt>
              <dd className="tabular">{formatNumber(technicals.indicators[key], 2)}</dd>
            </div>
          ) : null,
        )}
      </dl>
    </Card>
  );
}

/** Semicircle needle gauge from Strong sell (−1) to Strong buy (+1). */
function Gauge({ value }: { value: number | null }) {
  const v = value ?? 0;
  const angle = Math.PI * (1 - (v + 1) / 2);
  const x = 60 + 44 * Math.cos(angle);
  const y = 60 - 44 * Math.sin(angle);
  return (
    <svg viewBox="0 0 120 68" className="mx-auto w-48" aria-label={`Technical rating ${v.toFixed(2)}`}>
      <defs>
        <linearGradient id="gauge" x1="0" x2="1">
          <stop offset="0%" stopColor="var(--loss)" />
          <stop offset="50%" stopColor="var(--muted-foreground)" />
          <stop offset="100%" stopColor="var(--gain)" />
        </linearGradient>
      </defs>
      <path d="M10 60 A50 50 0 0 1 110 60" fill="none" stroke="url(#gauge)" strokeWidth="8" strokeLinecap="round" />
      <line x1="60" y1="60" x2={x} y2={y} stroke="var(--foreground)" strokeWidth="2.5" strokeLinecap="round" />
      <circle cx="60" cy="60" r="4" fill="var(--foreground)" />
    </svg>
  );
}
