// Yahoo quotes London in pence (GBp) and Johannesburg in cents (ZAc).
const CURRENCY_LABELS: Record<string, string> = { GBp: "GBX", ZAc: "ZAC" };

export function currencyLabel(currency: string | null | undefined): string {
  if (!currency) return "";
  return CURRENCY_LABELS[currency] ?? currency;
}

function priceDigits(value: number): number {
  const abs = Math.abs(value);
  if (abs >= 1000) return 2;
  if (abs >= 1) return 2;
  if (abs >= 0.01) return 4;
  return 6;
}

export function formatNumber(value: number | null | undefined, digits?: number): string {
  if (value == null || Number.isNaN(value)) return "—";
  const d = digits ?? priceDigits(value);
  return new Intl.NumberFormat("en-US", { minimumFractionDigits: d, maximumFractionDigits: d }).format(value);
}

export function formatPrice(value: number | null | undefined, currency?: string | null): string {
  if (value == null) return "—";
  const label = currencyLabel(currency);
  return label ? `${formatNumber(value)} ${label}` : formatNumber(value);
}

export function formatSigned(value: number | null | undefined, digits?: number): string {
  if (value == null || Number.isNaN(value)) return "—";
  const text = formatNumber(Math.abs(value), digits);
  return `${value > 0 ? "+" : value < 0 ? "−" : ""}${text}`;
}

export function formatPercent(value: number | null | undefined, digits = 2): string {
  if (value == null || Number.isNaN(value)) return "—";
  return `${value > 0 ? "+" : value < 0 ? "−" : ""}${Math.abs(value).toFixed(digits)}%`;
}

/** Fractions (0.123) → "12.30%" — for backtest statistics. */
export function formatRatioPercent(value: number | null | undefined, digits = 2, signed = false): string {
  if (value == null || Number.isNaN(value)) return "—";
  return signed ? formatPercent(value * 100, digits) : `${(value * 100).toFixed(digits)}%`;
}

export function formatCompact(value: number | null | undefined): string {
  if (value == null || Number.isNaN(value)) return "—";
  return new Intl.NumberFormat("en-US", { notation: "compact", maximumFractionDigits: 2 }).format(value);
}

export function changeClass(value: number | null | undefined): string {
  if (value == null || value === 0) return "text-muted-foreground";
  return value > 0 ? "text-gain" : "text-loss";
}

export function formatDateTime(iso: string | null | undefined): string {
  if (!iso) return "—";
  return new Date(iso).toLocaleString(undefined, { month: "short", day: "numeric", hour: "2-digit", minute: "2-digit" });
}

export function formatInterval(seconds: number): string {
  if (seconds % 3600 === 0) return `${seconds / 3600}h`;
  if (seconds % 60 === 0) return `${seconds / 60}m`;
  return `${seconds}s`;
}

export function symbolHref(symbol: string): string {
  return `/symbols/${encodeURIComponent(symbol)}`;
}
