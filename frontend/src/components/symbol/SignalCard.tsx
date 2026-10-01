"use client";

import Link from "next/link";
import { useState } from "react";
import { api } from "@/lib/api";
import { useAuth } from "@/lib/auth-context";
import { useAsync, errorMessage } from "@/lib/use-async";
import { formatPrice, formatSigned } from "@/lib/format";
import type { TickerInfo } from "@/lib/types";
import { SignalBadge } from "@/components/ui/Badges";
import { Card, ErrorNote, Skeleton } from "@/components/ui/primitives";

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
          <div className="flex items-center justify-between">
            <SignalBadge type={signal.signal_type} size="lg" />
            <div className="text-right">
              <div className="text-2xl font-semibold">{(signal.confidence * 100).toFixed(0)}%</div>
              <div className="text-xs text-muted-foreground">confidence</div>
            </div>
          </div>
          <ScoreBar score={signal.score} threshold={signal.parameters.threshold} />
          <p className="mt-3 text-sm text-muted-foreground">{signal.reason}</p>
          <dl className="mt-3 grid grid-cols-2 gap-2 text-xs text-muted-foreground">
            <div>
              Trend <span className="tabular text-foreground">{formatSigned(signal.components.trend, 2)}σ</span>
            </div>
            <div>
              Stretch <span className="tabular text-foreground">{formatSigned(signal.components.z, 2)}σ</span>
            </div>
            <div>
              Price <span className="tabular text-foreground">{formatPrice(signal.price, ticker.kind === "index" ? null : ticker.currency)}</span>
            </div>
            <div>As of {signal.as_of}</div>
          </dl>
          <p className="mt-3 text-xs text-muted-foreground">
            {data?.optimizer_run_id ? "Using your optimised parameters." : "Using default parameters."}{" "}
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

/** Score S ∈ [−1, 1] with the ±θ decision band. */
function ScoreBar({ score, threshold }: { score: number; threshold: number }) {
  const pos = (v: number) => `${((v + 1) / 2) * 100}%`;
  return (
    <div className="mt-4">
      <div className="relative h-2 rounded-full bg-gradient-to-r from-loss via-hold to-gain">
        <span className="absolute top-1/2 h-4 w-1 -translate-x-1/2 -translate-y-1/2 rounded bg-foreground" style={{ left: pos(score) }} />
        <span className="absolute -top-1 h-4 w-px bg-surface/80" style={{ left: pos(-threshold) }} />
        <span className="absolute -top-1 h-4 w-px bg-surface/80" style={{ left: pos(threshold) }} />
      </div>
      <div className="mt-1 flex justify-between text-[10px] text-muted-foreground">
        <span>SELL −1</span>
        <span>
          score {formatSigned(score, 2)} · θ ±{threshold.toFixed(2)}
        </span>
        <span>BUY +1</span>
      </div>
    </div>
  );
}
