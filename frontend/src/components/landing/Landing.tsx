"use client";

import Link from "next/link";
import { useState } from "react";
import { api } from "@/lib/api";
import { useAsync } from "@/lib/use-async";
import { useLiveQuotes } from "@/lib/realtime";
import { changeClass, formatNumber, formatPercent, symbolHref } from "@/lib/format";
import type { MarketRow, Quote } from "@/lib/types";
import { Flag } from "@/components/ui/Flag";
import { BrandMark } from "@/components/layout/BrandMark";

/* The signed-out home page: a marketing landing in a warm cream / forest /
   lime palette (scoped to `.landing` in globals.css). Every price on it is
   live from the API; nothing is invented. */

const NAV = [
  { href: "/markets", label: "Markets" },
  { href: "#how", label: "How it works" },
  { href: "#features", label: "Features" },
  { href: "#mobile", label: "Mobile app" },
];

const PROMISES = [
  { icon: <path d="M4 6h16M4 12h10M4 18h6" />, text: "Equity, growth & value screens" },
  { icon: <path d="M4 18l5-6 4 3 7-9" />, text: "Tested on unseen data" },
  { icon: <path d="M12 4v4M12 16v4M4 12h4M16 12h4" />, text: "Assumed BUY · SELL · HOLD" },
  { icon: <path d="M12 3.5l7.5 3v5.5c0 4.4-3.2 7.6-7.5 8.5-4.3-.9-7.5-4.1-7.5-8.5V6.5z" />, text: "Never touches your money" },
];

const STEPS = [
  { n: "01", title: "Select", text: "Pick equity, growth or value stocks, then rank an exchange over the period you choose and keep the top performers." },
  { n: "02", title: "Optimize", text: "Estimate the best signal parameters on history — algebraic or Stochastic + MACD + RSI — and check them on a period they never saw." },
  { n: "03", title: "Advise", text: "Stockiser watches the market and tells you the moment the signal flips to BUY, SELL or HOLD — on the web and on your phone." },
];

function Icon({ children, className = "h-5 w-5" }: { children: React.ReactNode; className?: string }) {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8} strokeLinecap="round" strokeLinejoin="round" className={className} aria-hidden>
      {children}
    </svg>
  );
}

function Logo({ light = false }: { light?: boolean }) {
  return (
    <span className="flex items-center gap-2.5">
      <BrandMark size={38} />
      <span className="flex flex-col leading-none">
        <span className="text-xl font-black tracking-tight">Stockiser</span>
        <span className={`mt-0.5 text-[9px] font-bold uppercase tracking-[0.32em] ${light ? "text-white/60" : "text-[var(--l-forest)]"}`}>Evalucre Capital</span>
      </span>
    </span>
  );
}

function Delta({ value, className = "" }: { value: number | null | undefined; className?: string }) {
  const up = (value ?? 0) >= 0;
  return (
    <span className={`tabular inline-flex items-center gap-1 text-xs font-bold ${changeClass(value)} ${className}`}>
      <span aria-hidden>{up ? "▲" : "▼"}</span>
      {formatPercent(value)}
    </span>
  );
}

/** A floating quote card in the hero, like a trading-app widget. */
function QuoteCard({ eyebrow, row, quote, className }: { eyebrow: string; row?: MarketRow; quote?: Quote | null; className: string }) {
  return (
    <div className={`absolute rounded-2xl bg-white px-5 py-4 shadow-[0_18px_40px_-18px_rgba(14,59,50,0.35)] ${className}`}>
      <p className="text-[10px] font-bold uppercase tracking-[0.16em] text-[var(--l-forest)]">{eyebrow}</p>
      <p className="mt-1 text-xs text-[var(--l-muted)]">{row?.name ?? "—"}</p>
      <p className="tabular mt-1 text-2xl font-bold tracking-tight text-[var(--l-ink)]">{formatNumber(quote?.price)}</p>
      <Delta value={quote?.change_percent} className="mt-1" />
    </div>
  );
}

/** Hero illustration: rising bars, a signal coin and a dotted field — drawn, not stock art. */
function HeroArt() {
  const bars = [46, 70, 58, 96, 120, 150];
  return (
    <svg viewBox="0 0 420 300" className="relative z-10 w-full max-w-[460px]" aria-hidden>
      <defs>
        <linearGradient id="bar" x1="0" x2="1">
          <stop offset="0" stopColor="#f3f2ee" />
          <stop offset="0.5" stopColor="#c9ccc6" />
          <stop offset="1" stopColor="#8d928b" />
        </linearGradient>
        <linearGradient id="barTop" x1="0" x2="1">
          <stop offset="0" stopColor="#ffffff" />
          <stop offset="1" stopColor="#dfe1dc" />
        </linearGradient>
        <radialGradient id="coin" cx="0.35" cy="0.3" r="0.8">
          <stop offset="0" stopColor="#ffffff" />
          <stop offset="0.6" stopColor="#c8cbc4" />
          <stop offset="1" stopColor="#7d827b" />
        </radialGradient>
      </defs>
      <ellipse cx="210" cy="262" rx="190" ry="18" fill="#0e3b32" opacity="0.08" />
      {bars.map((h, i) => {
        const x = 60 + i * 44;
        const y = 250 - h;
        return (
          <g key={i}>
            <rect x={x} y={y} width="30" height={h} rx="3" fill="url(#bar)" />
            <path d={`M${x} ${y} l10 -8 h30 l-10 8 z`} fill="url(#barTop)" />
            <path d={`M${x + 30} ${y} l10 -8 v${h} l-10 8 z`} fill="#7d827b" />
          </g>
        );
      })}
      <polyline points="60,196 104,174 148,186 192,150 236,128 280,96 330,70" fill="none" stroke="#0e3b32" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" />
      <circle cx="330" cy="70" r="6" fill="#4ee478" stroke="#0e3b32" strokeWidth="3" />
      <g transform="translate(330 196)">
        <ellipse cx="0" cy="40" rx="44" ry="10" fill="#7d827b" />
        <circle r="46" fill="url(#coin)" stroke="#9aa096" strokeWidth="2" />
        <circle r="34" fill="none" stroke="#ffffff" strokeOpacity="0.7" strokeWidth="2" />
        {/* The Stockiser mark, engraved: forest S through grey bars. */}
        <g transform="scale(0.36)" fill="none" strokeWidth="14" strokeLinecap="round">
          <g stroke="#8d928b">
            <line x1="0" y1="-64" x2="0" y2="-40" />
            <line x1="29" y1="-46" x2="29" y2="-22" />
            <line x1="-29" y1="22" x2="-29" y2="46" />
            <line x1="0" y1="40" x2="0" y2="64" />
          </g>
          <path d="M-29 -36 V-31 C-29 -12 29 12 29 31 V36" stroke="#114325" strokeLinejoin="round" />
        </g>
      </g>
    </svg>
  );
}

function Ticker({ rows, live }: { rows: MarketRow[]; live: Record<string, Quote> }) {
  if (!rows.length) return <div className="h-12 bg-[var(--l-forest)]" />;
  const items = [...rows, ...rows];
  return (
    <div className="relative flex mt-16 h-12 items-center overflow-hidden bg-[var(--l-forest)] text-white">
      <span className="z-10 flex h-full shrink-0 items-center gap-2 bg-[var(--l-forest)] pl-6 pr-5 text-xs font-bold tracking-[0.16em] text-[var(--l-lime)]">
        <span className="h-2 w-2 animate-pulse rounded-full bg-[var(--l-lime)]" /> LIVE
      </span>
      <div className="landing-marquee flex shrink-0 gap-10 whitespace-nowrap pr-10">
        {items.map((row, i) => {
          const q = live[row.symbol] ?? row.quote;
          const up = (q?.change_percent ?? 0) >= 0;
          return (
            <Link key={`${row.symbol}-${i}`} href={symbolHref(row.symbol)} className="tabular flex items-center gap-2.5 text-[13px] hover:text-[var(--l-lime)]" tabIndex={i < rows.length ? 0 : -1}>
              <span className="font-bold">{row.display_symbol.replace(/^\^/, "")}</span>
              <span className="text-white/70">{formatNumber(q?.price)}</span>
              <span className={`font-bold ${up ? "text-[#7ee2a8]" : "text-[#ff8f86]"}`}>{formatPercent(q?.change_percent)}</span>
            </Link>
          );
        })}
      </div>
    </div>
  );
}

/** A phone frame for app mock-ups. */
function Phone({ children, className = "" }: { children: React.ReactNode; className?: string }) {
  return (
    <div className={`relative w-[260px] rounded-[42px] border-[10px] border-[#14181c] bg-white shadow-[0_30px_60px_-24px_rgba(14,59,50,0.45)] ${className}`}>
      <div className="absolute left-1/2 top-2 h-5 w-20 -translate-x-1/2 rounded-full bg-[#14181c]" />
      <div className="px-4 pb-6 pt-10">{children}</div>
    </div>
  );
}

function PhoneWatchlist({ rows, live, title }: { rows: MarketRow[]; live: Record<string, Quote>; title: string }) {
  return (
    <>
      <div className="mb-3 flex items-center justify-between text-[var(--l-ink)]">
        <span className="text-xs">‹</span>
        <span className="text-sm font-bold">{title}</span>
        <span className="text-xs">⋮</span>
      </div>
      <ul className="space-y-2">
        {rows.map((row) => {
          const q = live[row.symbol] ?? row.quote;
          return (
            <li key={row.symbol} className="flex items-center gap-3 rounded-xl border border-[#edece6] px-3 py-2.5">
              <Flag code={row.country_code} size={26} />
              <span className="min-w-0 flex-1">
                <span className="block truncate text-[11px] font-bold text-[var(--l-muted)]">{row.display_symbol.replace(/^\^/, "")}</span>
                <span className="tabular block text-sm font-bold text-[var(--l-ink)]">{formatNumber(q?.price)}</span>
              </span>
              <Delta value={q?.change_percent} />
            </li>
          );
        })}
      </ul>
    </>
  );
}

function StockTypeMock() {
  const [choice, setChoice] = useState("growth");
  const options = [
    ["equity", "Equity stocks", "Every listed stock on the exchange."],
    ["growth", "Growth stocks", "Growing faster than the market, high P/E, little dividend."],
    ["value", "Value stocks", "Priced below their fundamentals, low P/E, steady dividends."],
  ];
  return (
    <div className="rounded-2xl border border-[#edece6] bg-white p-4 shadow-[0_14px_30px_-20px_rgba(14,59,50,0.3)]">
      <p className="mb-2 text-center text-xs font-bold text-[var(--l-ink)]">Choose a stock type</p>
      <div role="radiogroup" aria-label="Stock type example">
        {options.map(([value, label, text]) => (
          <button
            key={value}
            type="button"
            role="radio"
            aria-checked={choice === value}
            onClick={() => setChoice(value)}
            className="flex w-full items-start justify-between gap-3 border-t border-[#f0efe9] py-2.5 text-left first:border-0"
          >
            <span>
              <span className="block text-xs font-bold text-[var(--l-ink)]">{label}</span>
              <span className="block text-[11px] leading-snug text-[var(--l-muted)]">{text}</span>
            </span>
            <span className={`mt-0.5 grid h-4 w-4 shrink-0 place-items-center rounded-full border-2 ${choice === value ? "border-[var(--l-forest)]" : "border-[#d5d6cf]"}`}>
              {choice === value && <span className="h-1.5 w-1.5 rounded-full bg-[var(--l-forest)]" />}
            </span>
          </button>
        ))}
      </div>
    </div>
  );
}

function ChartMock() {
  const pts = [62, 58, 64, 60, 70, 66, 74, 72, 82, 78, 88, 94, 90, 100, 108];
  const w = 300;
  const h = 120;
  const max = Math.max(...pts);
  const min = Math.min(...pts);
  const xy = pts.map((v, i) => [(i / (pts.length - 1)) * w, h - ((v - min) / (max - min)) * (h - 20) - 6]);
  const line = xy.map(([x, y]) => `${x.toFixed(1)},${y.toFixed(1)}`).join(" ");
  const [px, py] = xy[9];
  return (
    <div className="rounded-2xl border border-[#edece6] bg-white p-4 shadow-[0_14px_30px_-20px_rgba(14,59,50,0.3)]">
      <div className="mb-2 flex items-center gap-2">
        <span className="h-5 w-5 rounded-full bg-[var(--l-forest)]" />
        <span className="text-xs font-bold text-[var(--l-ink)]">Training → unseen</span>
      </div>
      <svg viewBox={`0 0 ${w} ${h}`} className="w-full" aria-hidden>
        <defs>
          <linearGradient id="area" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor="#0e3b32" stopOpacity="0.22" />
            <stop offset="1" stopColor="#0e3b32" stopOpacity="0" />
          </linearGradient>
        </defs>
        <rect x={w * 0.66} y="0" width={w * 0.34} height={h} fill="#4ee478" opacity="0.25" />
        <text x={w * 0.66 + 6} y="12" fontSize="9" fontWeight="700" fill="#0e3b32" letterSpacing="1">
          UNSEEN
        </text>
        <polygon points={`0,${h} ${line} ${w},${h}`} fill="url(#area)" />
        <polyline points={line} fill="none" stroke="#0e3b32" strokeWidth="2.2" strokeLinejoin="round" />
        <line x1={px} x2={px} y1={py} y2={h} stroke="#0e3b32" strokeDasharray="3 3" opacity="0.5" />
        <circle cx={px} cy={py} r="4.5" fill="#fff" stroke="#0e3b32" strokeWidth="2" />
      </svg>
    </div>
  );
}

export function Landing() {
  const { data } = useAsync(() => api.indices(), []);
  const indices = data?.indices ?? [];
  const live = useLiveQuotes(indices.slice(0, 14).map((r) => r.symbol));
  const pick = (symbol: string) => indices.find((r) => r.symbol === symbol);
  const quoteOf = (row?: MarketRow) => (row ? live[row.symbol] ?? row.quote : null);
  const [spx, ftse, dax] = [pick("^GSPC") ?? indices[0], pick("^FTSE") ?? indices[1], pick("^GDAXI") ?? indices[2]];
  const phoneRows = indices.filter((r) => r.symbol !== "^VIX").slice(0, 5);
  const countries = useAsync(() => api.countries(), []).data?.countries ?? [];

  return (
    <div className="landing min-h-screen bg-[var(--l-cream)] text-[var(--l-ink)]">
      {/* ---- top navigation ---- */}
      <header className="sticky top-0 z-40 border-b border-[#ebe8df] bg-[var(--l-cream)]/90 backdrop-blur">
        <div className="mx-auto flex h-20 max-w-7xl items-center justify-between gap-6 px-5 sm:px-8">
          <Link href="/" aria-label="Stockiser home">
            <Logo />
          </Link>
          <nav aria-label="Main" className="hidden items-center gap-8 text-[15px] font-bold lg:flex">
            {NAV.map((n) => (
              <Link key={n.href} href={n.href} className="hover:text-[var(--l-forest)]">
                {n.label}
              </Link>
            ))}
          </nav>
          <div className="flex items-center gap-2 sm:gap-4">
            <Link href="/login" className="px-2 text-[15px] font-bold hover:text-[var(--l-forest)]">
              Login
            </Link>
            <Link href="/register" className="landing-cta hidden sm:inline-flex">
              Open free account
            </Link>
          </div>
        </div>
      </header>

      {/* ---- hero ---- */}
      <section className="mx-auto grid max-w-7xl items-center gap-12 px-5 pb-12 pt-14 sm:px-8 lg:grid-cols-[1.05fr_1fr] lg:pt-20">
        <div>
          {/* <span className="inline-flex items-center gap-2 rounded-full border border-[#dcdad2] bg-white/60 px-4 py-1.5 text-xs font-black uppercase tracking-[0.18em] text-[var(--l-forest)]">
            <span className="h-1.5 w-1.5 rounded-full bg-[var(--l-forest)]" /> Signals, not noise
          </span> */}
          <h1 className="mt-7 text-[52px] font-black leading-[0.98] tracking-[-0.03em] sm:text-[76px]">
            Get the right
            <br />
            <span className="text-[var(--l-forest)]">Signals.</span>
          </h1>
          <p className="mt-7 max-w-xl text-lg leading-relaxed text-[var(--l-muted)]">
            Rank stocks on 37 exchanges, tune a strategy on their history, and get a live BUY, SELL or HOLD the moment it changes — from one calm workspace.
          </p>
          <div className="mt-9 flex flex-wrap gap-3">
            <Link href="/register" className="landing-cta min-h-14 px-8 text-base">
              Start free <span aria-hidden>↗</span>
            </Link>
            <Link href="/markets" className="inline-flex min-h-14 items-center rounded-full border-2 border-[#d5d3ca] px-8 text-base font-bold hover:border-[var(--l-forest)]">
              Explore markets
            </Link>
          </div>
          <p className="mt-8 flex flex-wrap items-center gap-x-3 gap-y-1 text-sm text-[var(--l-muted)]">
            <span className="font-black text-[var(--l-ink)]">37 exchanges · 34 countries</span>
            <span aria-hidden>·</span> Recommendations only — you trade through your own broker.
          </p>
        </div>

        <div className="relative mx-auto flex aspect-square w-full max-w-[560px] items-center justify-center">
          <div className="absolute inset-[6%] rounded-full border border-[#dcdad2]" />
          <div
            className="absolute bottom-[8%] left-[2%] h-40 w-56 opacity-60"
            style={{ backgroundImage: "radial-gradient(#b9b7ae 1.2px, transparent 1.2px)", backgroundSize: "14px 14px" }}
          />
          <HeroArt />
          <QuoteCard eyebrow="US index" row={spx} quote={quoteOf(spx)} className="left-[2%] top-[14%]" />
          <QuoteCard eyebrow="UK index" row={ftse} quote={quoteOf(ftse)} className="right-0 top-[2%]" />
          <QuoteCard eyebrow="EU index" row={dax} quote={quoteOf(dax)} className="bottom-[6%] left-[10%]" />
        </div>
      </section>

      {/* ---- promises ---- */}
      <section className="mx-auto max-w-7xl px-5 pb-14 sm:px-8">
        <ul className="flex flex-wrap gap-3">
          {PROMISES.map((p) => (
            <li key={p.text} className="flex items-center gap-3 rounded-full border border-[#ebe8df] bg-white px-5 py-3 text-[15px] font-bold">
              <span className="text-[var(--l-forest)]">
                <Icon>{p.icon}</Icon>
              </span>
              {p.text}
            </li>
          ))}
        </ul>
      </section>

      <Ticker rows={indices.slice(0, 14)} live={live} />

      {/* ---- features ---- */}
      <section id="features" className="scroll-mt-24 bg-white">
        <div className="mx-auto grid max-w-7xl gap-6 px-5 py-24 sm:px-8 lg:grid-cols-2">
          <article className="rounded-3xl border border-[#efeee8] bg-[#fbfaf7] p-8">
            <p className="text-xs font-bold text-[var(--l-forest)]">Precision screening</p>
            <h2 className="mt-1 text-3xl font-black tracking-tight">Start with the right stocks</h2>
            <p className="mt-3 max-w-md text-[var(--l-muted)]">Equity, growth or value — judged against the other stocks on the same exchange, because a cheap P/E in Lagos isn&apos;t a cheap P/E on Nasdaq.</p>
            <div className="mt-8 max-w-sm">
              <StockTypeMock />
            </div>
          </article>
          <article className="rounded-3xl border border-[#efeee8] bg-[#fbfaf7] p-8">
            <p className="text-xs font-bold text-[var(--l-forest)]">Honest testing</p>
            <h2 className="mt-1 text-3xl font-black tracking-tight">Tuned on the past, proven on the unseen</h2>
            <p className="mt-3 max-w-md text-[var(--l-muted)]">The Optimizer estimates parameters on a training period, then reports how they did afterwards — always next to simply buying and holding.</p>
            <div className="mt-8">
              <ChartMock />
            </div>
          </article>

          <article className="flex flex-col gap-6 rounded-3xl border border-[#efeee8] bg-[#fbfaf7] p-8 lg:col-span-2 lg:flex-row lg:items-center lg:justify-between">
            <ul className="flex flex-wrap gap-2.5" aria-label="Covered countries">
              {countries.slice(0, 18).map((c) => (
                <li key={c.code} className="rounded-xl bg-white p-2 shadow-[0_8px_20px_-14px_rgba(14,59,50,0.4)]">
                  <Flag code={c.code} size={26} />
                </li>
              ))}
            </ul>
            <div className="lg:max-w-sm">
              <p className="text-xs font-bold text-[var(--l-forest)]">Global coverage</p>
              <h2 className="mt-1 text-3xl font-black tracking-tight">From Wall Street to Lagos</h2>
              <p className="mt-2 text-[var(--l-muted)]">37 exchanges across six continents. Markets without a free data feed are clearly marked as simulated.</p>
            </div>
          </article>

          <article id="mobile" className="relative grid scroll-mt-24 items-center gap-10 overflow-hidden rounded-3xl border border-[#efeee8] bg-[#fbfaf7] p-8 lg:col-span-2 lg:grid-cols-2 lg:p-14">
            <div>
              <p className="text-xs font-bold text-[var(--l-forest)]">Always with you</p>
              <h2 className="mt-1 text-4xl font-black tracking-tight">Track every market from your phone</h2>
              <p className="mt-3 max-w-md text-[var(--l-muted)]">
                The Stockiser app follows your watchlist live and sends a push notification the moment the Adviser&apos;s signal changes.
              </p>
            </div>
            <div className="flex justify-center">
              <Phone>
                <PhoneWatchlist rows={phoneRows} live={live} title="Watchlist" />
              </Phone>
            </div>
          </article>
        </div>
      </section>

      {/* ---- how it works ---- */}
      <section id="how" className="scroll-mt-24 border-y border-[#ebe8df]">
        <div className="mx-auto grid max-w-7xl gap-12 px-5 py-24 sm:px-8 lg:grid-cols-[22rem_1fr]">
          <div>
            <h2 className="text-5xl font-black leading-[1.02] tracking-tight">
              Three steps.
              <br />
              <span className="text-[var(--l-forest)]">One decision.</span>
            </h2>
            <p className="mt-4 text-[var(--l-muted)]">Stockiser recommends. You stay in control and act through your own broker.</p>
          </div>
          <ol className="grid gap-5 md:grid-cols-3">
            {STEPS.map((s) => (
              <li key={s.n} className="rounded-3xl border border-[#ebe8df] bg-white p-7">
                <span className="text-sm font-black text-[var(--l-forest)]">{s.n}</span>
                <h3 className="mt-3 text-2xl font-black">{s.title}</h3>
                <p className="mt-2 leading-relaxed text-[var(--l-muted)]">{s.text}</p>
              </li>
            ))}
          </ol>
        </div>
      </section>

      {/* ---- closing call to action ---- */}
      <section className="relative overflow-hidden">
        <div className="mx-auto flex max-w-7xl flex-col items-center px-5 py-28 text-center sm:px-8">
          <BrandMark size={56} />
          <h2 className="mt-6 text-5xl font-black tracking-tight">
            Unlock calmer
            <br />
            investing today.
          </h2>
          <p className="mt-4 max-w-lg text-lg text-[var(--l-muted)]">Create a free account, run your first Selector in a minute, and let the Adviser keep watch.</p>
          <div className="mt-8 flex flex-wrap justify-center gap-3">
            <Link href="/register" className="landing-cta min-h-14 px-8 text-base">
              Open free account <span aria-hidden>↗</span>
            </Link>
            <Link href="/login" className="inline-flex min-h-14 items-center rounded-full border-2 border-[#d5d3ca] px-8 text-base font-bold hover:border-[var(--l-forest)]">
              Log in
            </Link>
          </div>
        </div>
        <div className="pointer-events-none absolute -left-16 bottom-10 hidden -rotate-12 xl:block">
          <Phone>
            <PhoneWatchlist rows={indices.slice(5, 9)} live={live} title="Europe" />
          </Phone>
        </div>
        <div className="pointer-events-none absolute -right-16 bottom-10 hidden rotate-12 xl:block">
          <Phone>
            <PhoneWatchlist rows={indices.slice(0, 4)} live={live} title="United States" />
          </Phone>
        </div>
      </section>

      {/* ---- footer ---- */}
      <footer className="bg-[var(--l-forest)] text-white">
        <div className="mx-auto grid max-w-7xl gap-10 px-5 py-14 sm:px-8 md:grid-cols-[1.4fr_1fr_1fr_1fr]">
          <div>
            <Logo light />
            <p className="mt-4 max-w-xs text-sm text-white/60">Evalucre Capital&apos;s algebraic adviser. Stockiser recommends; it never places trades. Not investment advice.</p>
          </div>
          {[
            ["Product", [["/markets", "Markets"], ["/selector", "Selector"], ["/optimizer", "Optimizer"], ["/adviser", "Adviser"]]],
            ["Account", [["/register", "Open account"], ["/login", "Login"], ["/profile", "Investor profile"]]],
            ["Learn", [["#how", "How it works"], ["#features", "Features"], ["#mobile", "Mobile app"]]],
          ].map(([title, links]) => (
            <div key={title as string}>
              <p className="text-sm font-black">{title as string}</p>
              <ul className="mt-3 space-y-2 text-sm text-white/65">
                {(links as string[][]).map(([href, label]) => (
                  <li key={href}>
                    <Link href={href} className="hover:text-[var(--l-lime)]">
                      {label}
                    </Link>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>
        <div className="border-t border-white/10">
          <p className="mx-auto max-w-7xl px-5 py-5 text-xs text-white/50 sm:px-8">
            © {new Date().getFullYear()} Evalucre Capital. Prices marked “Simulated” are model-generated.
          </p>
        </div>
      </footer>
    </div>
  );
}
