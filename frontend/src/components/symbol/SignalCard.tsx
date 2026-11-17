"use client";

import Link from "next/link";
import { useState } from "react";
import { api } from "@/lib/api";
import { useAuth } from "@/lib/auth-context";
import { useAsync, errorMessage } from "@/lib/use-async";
import { formatPrice, formatSigned } from "@/lib/format";
import type { SignalType, TickerInfo } from "@/lib/types";
import { Card, ErrorNote, Skeleton } from "@/components/ui/primitives";

const TONE: Record<SignalType, string> = { BUY: "text-gain", SELL: "text-loss", HOLD: "text-hold" };

const INTERVALS = [
  { value: 60, label: "Every minute" },
  { value: 300, label: "Every 5 minutes" },
  { value: 900, label: "Every 15 minutes" },
  { value: 3600, label: "Hourly" },
];

/** The Adviser's current decision for this symbol, plus a one-click monitoring session. */
export function SignalCard({ ticker }: { ticker: TickerInfo }) {
  const { token, user } = useAuth();
  const { data, loading, error } = useAsync(() => api.signal(ticker.symbol, token), [ticker.symbol, token]);
  const [interval, setIntervalSec] = useState(300);
  const [status, setStatus] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  const monitor = async () => {
    if (!token) return;
    setActionError(null);
    try {
      await api.createSession(token, { symbol: ticker.symbol, interval_sec: interval, optimizer_run_id: data?.optimizer_run_id });
      setStatus("Monitoring started — signals will appear on the Adviser page and as notifications.");
    } catch (err) {
      setActionError(errorMessage(err));
    }
  };

  const signal = data?.signal;
  return (
    <Card title="Adviser signal">
      {loading && <Skeleton className="h-32" />}
      <ErrorNote message={error} />
      {signal && (
        <>
          <div className="flex items-end justify-between gap-3">
            <span className={`text-4xl font-black leading-none tracking-wide ${TONE[signal.signal_type]}`}>{signal.signal_type}</span>
            <div className="flex items-baseline gap-1.5">
              <span className="tabular text-3xl font-light leading-none">{(signal.confidence * 100).toFixed(0)}%</span>
              <span className="text-xs text-muted-foreground">confidence</span>
            </div>
          </div>
          <ScoreBar score={signal.score} threshold={signal.parameters.threshold} tone={TONE[signal.signal_type]} />
          <p className="mt-4 text-sm leading-relaxed">{signal.reason}</p>
          <dl className="mt-4 grid grid-cols-2 gap-2 text-xs text-muted-foreground">
            {componentRows(signal.strategy, signal.components).map(([label, value]) => (
              <div key={label}>
                {label} <span className="tabular text-foreground">{value}</span>
              </div>
            ))}
            <div>
              Price <span className="tabular text-foreground">{formatPrice(signal.price, ticker.kind === "index" ? null : ticker.currency)}</span>
            </div>
            <div>As of {signal.as_of}</div>
          </dl>
          <p className="mt-3 text-xs text-muted-foreground">
            {signal.strategy === "indicators" ? "Stochastic + MACD + RSI" : "Algebraic signal"} ·{" "}
            {data?.optimizer_run_id ? "your optimised parameters." : "default parameters."}{" "}
            <Link href={`/optimizer?symbol=${encodeURIComponent(ticker.symbol)}`} className="text-brand hover:underline">
              Optimise for {ticker.display_symbol} →
            </Link>
          </p>
          <div className="mt-4 border-t border-border pt-4">
            {user ? (
              <div className="flex flex-wrap items-center gap-2">
                <select className="input w-auto" value={interval} onChange={(e) => setIntervalSec(Number(e.target.value))} aria-label="Monitoring interval">
                  {INTERVALS.map((i) => (
                    <option key={i.value} value={i.value}>
                      {i.label}
                    </option>
                  ))}
                </select>
                <button onClick={monitor} className="btn-primary">
                  Monitor with Adviser
                </button>
              </div>
            ) : (
              <p className="text-sm">
                <Link href="/login" className="text-brand hover:underline">
                  Log in
                </Link>{" "}
                to monitor this symbol and receive live signals.
              </p>
            )}
            {status && <p className="mt-2 text-sm text-gain">{status}</p>}
            <ErrorNote message={actionError} />
          </div>
        </>
      )}
    </Card>
  );
}

/** The inputs behind the score, labelled for the strategy that produced it. */
function componentRows(strategy: string, c: Record<string, number>): [string, string][] {
  if (strategy === "indicators") {
    return [
      ["MACD hist.", formatSigned(c.macd_hist, 3)],
      ["RSI", c.rsi?.toFixed(0) ?? "—"],
      ["Stochastic %D", c.stoch_d?.toFixed(0) ?? "—"],
    ];
  }
  return [
    ["Trend", `${formatSigned(c.trend, 2)}σ`],
    ["Stretch", `${formatSigned(c.z, 2)}σ`],
  ];
}

/** Score S ∈ [−1, 1] on a quiet track; the ±θ HOLD band is shaded and the
 * marker takes the colour of the decision it falls into. */
function ScoreBar({ score, threshold, tone }: { score: number; threshold: number; tone: string }) {
  const pct = (v: number) => ((Math.max(-1, Math.min(1, v)) + 1) / 2) * 100;
  return (
    <div className="mt-6">
      <div className="relative h-1.5 rounded-full bg-surface-muted">
        <span className="absolute inset-y-0 bg-hold-soft" style={{ left: `${pct(-threshold)}%`, width: `${pct(threshold) - pct(-threshold)}%` }} />
        <span className="absolute -top-1 left-1/2 h-3.5 w-px bg-border" />
        <span
          className={`absolute top-1/2 size-5 -translate-x-1/2 -translate-y-1/2 rounded-full border-[5px] border-current bg-surface ${tone}`}
          style={{ left: `${pct(score)}%` }}
        />
      </div>
      <div className="mt-3 flex justify-between text-[11px] text-muted-foreground">
        <span className="font-bold tracking-widest">SELL</span>
        <span className="tabular">
          S {formatSigned(score, 2)} · θ ±{threshold.toFixed(2)}
        </span>
        <span className="font-bold tracking-widest">BUY</span>
      </div>
    </div>
  );
}
