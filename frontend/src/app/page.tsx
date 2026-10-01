"use client";

import Link from "next/link";
import { api } from "@/lib/api";
import { useAsync } from "@/lib/use-async";
import { useLiveQuotes } from "@/lib/realtime";
import { changeClass, formatNumber, formatPercent, symbolHref } from "@/lib/format";
import { BrandMark } from "@/components/layout/BrandMark";
import { Flag } from "@/components/ui/Flag";
import { SourceBadge } from "@/components/ui/Badges";
import { PageShell, Skeleton } from "@/components/ui/primitives";

const MODULES = [
  {
    href: "/selector",
    title: "Selector",
    tone: "bg-brand-soft text-brand",
    check: "text-brand",
    icon: "M4 5h16l-6 8v6l-4-2v-4L4 5z",
    steps: ["Pick stock exchange of interest", "Specify historical period", "Choose performance criteria", "Rank & select top-N", "Save selected tickers to file"],
  },
  {
    href: "/optimizer",
    title: "Optimizer",
    tone: "bg-hold-soft text-hold",
    check: "text-hold",
    icon: "M4 7h10M18 7h2M4 17h4M12 17h8M14 5v4M8 15v4",
    steps: ["Call ticker file from Selector", "Specify training period", "Set parameter bounds", "Tune to optimal parameters", "Save optimal values to file"],
  },
  {
    href: "/adviser",
    title: "Adviser",
    tone: "bg-gain-soft text-gain",
    check: "text-gain",
    icon: "M12 3a6 6 0 0 0-6 6v4l-2 3h16l-2-3V9a6 6 0 0 0-6-6zM10 19a2 2 0 0 0 4 0",
    steps: ["Specify exchange & ticker", "Set monitoring interval", "Emit decision signals", "Color-code signals (green/red/orange)", "Notify user in real time"],
  },
];

export default function HomePage() {
  const { data, loading } = useAsync(() => api.indices(), []);
  const headline = data?.indices.slice(0, 10) ?? [];
  const live = useLiveQuotes(headline.map((r) => r.symbol));

  return (
    <PageShell>
      <section className="flex flex-wrap items-center justify-between gap-6">
        <div className="flex items-center gap-4">
          <BrandMark size={72} />
          <div>
            <h1 className="text-4xl font-bold tracking-tight sm:text-5xl">Algizer</h1>
            <p className="mt-1 font-medium text-brand">Evalucre Capital · algebraic adviser</p>
          </div>
        </div>
        <div className="flex flex-wrap gap-2 text-sm">
          {["Selector · Optimizer · Adviser", "Live market signals", "Algebraic, not chartist"].map((chip) => (
            <span key={chip} className="rounded-full border border-border bg-surface px-4 py-2 font-medium shadow-sm">
              {chip}
            </span>
          ))}
        </div>
      </section>

      <section className="mt-8 overflow-x-auto">
        <div className="flex gap-3 pb-2">
          {loading && !headline.length && Array.from({ length: 6 }).map((_, i) => <Skeleton key={i} className="h-20 w-48 shrink-0" />)}
          {headline.map((row) => {
            const q = live[row.symbol] ?? row.quote;
            return (
              <Link key={row.symbol} href={symbolHref(row.symbol)} className="card w-52 shrink-0 p-4 transition-shadow hover:shadow-md">
                <div className="flex items-center gap-2">
                  <Flag code={row.country_code} size={18} />
                  <span className="truncate text-sm font-medium">{row.name}</span>
                </div>
                <div className="mt-2 flex items-baseline justify-between gap-2">
                  <span className="tabular font-semibold">{formatNumber(q?.price)}</span>
                  <span className={`tabular text-sm ${changeClass(q?.change_percent)}`}>{formatPercent(q?.change_percent)}</span>
                </div>
                <SourceBadge source={row.data_source} className="mt-1" />
              </Link>
            );
          })}
        </div>
      </section>

      <section className="mt-8 grid gap-6 md:grid-cols-2">
        {MODULES.map((m) => (
          <Link key={m.href} href={m.href} className="card group p-8 transition-shadow hover:shadow-lg">
            <div className="flex items-center gap-4">
              <span className={`flex h-14 w-14 items-center justify-center rounded-2xl ${m.tone}`}>
                <svg viewBox="0 0 24 24" className="h-7 w-7" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <path d={m.icon} />
                </svg>
              </span>
              <h2 className="text-2xl font-semibold group-hover:text-brand">{m.title}</h2>
            </div>
            <ul className="mt-6 space-y-2.5">
              {m.steps.map((step) => (
                <li key={step} className="flex items-center gap-3 text-muted-foreground">
                  <span className={m.check}>✓</span>
                  {step}
                </li>
              ))}
            </ul>
          </Link>
        ))}
        <div className="card flex flex-col justify-between p-8">
          <div>
            <h2 className="text-2xl font-semibold">Global markets</h2>
            <p className="mt-3 text-muted-foreground">
              37 exchanges across 34 countries — New York, Toronto, London, Frankfurt, Tokyo, Seoul, Shanghai, Mumbai, Johannesburg, Lagos, Nairobi,
              Riyadh, São Paulo and more — with indices, movers and TradingView-style technical ratings.
            </p>
          </div>
          <Link href="/markets" className="btn-primary mt-6 self-start">
            Explore markets →
          </Link>
        </div>
      </section>

      <p className="mt-8 rounded-2xl bg-brand-soft px-5 py-4 text-sm">
        <strong>Key principle:</strong> the Adviser never executes trades — it emits signals, which you can act on through your own broker.
      </p>
    </PageShell>
  );
}
