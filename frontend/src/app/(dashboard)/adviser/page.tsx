"use client";

import Link from "next/link";
import { useCallback, useEffect, useState, useSyncExternalStore } from "react";
import { api } from "@/lib/api";
import { errorMessage, useAsync } from "@/lib/use-async";
import { useConnectionState, useLiveQuotes, useSignalListener } from "@/lib/realtime";
import { formatDateTime, formatInterval, formatNumber, formatPercent, formatPrice, changeClass, symbolHref, currencyLabel } from "@/lib/format";
import type { AdviserSession, SignalEvent, SignalType, TickerInfo } from "@/lib/types";
import { RequireAuth } from "@/components/auth/RequireAuth";
import { SignalBadge, SourceBadge } from "@/components/ui/Badges";
import { Card, EmptyState, ErrorNote, Field, PageHeader, PageShell } from "@/components/ui/primitives";

const ROW_TONE: Record<SignalType, string> = { BUY: "border-l-gain", SELL: "border-l-loss", HOLD: "border-l-hold" };

export default function AdviserPage() {
  return <RequireAuth feature="Adviser">{(token) => <Adviser token={token} />}</RequireAuth>;
}

function Adviser({ token }: { token: string }) {
  const sessions = useAsync(() => api.sessions(token), [token]);
  const initialSignals = useAsync(() => api.signals(token), [token]);
  const [pushed, setPushed] = useState<SignalEvent[]>([]);
  const connection = useConnectionState();
  const live = useLiveQuotes(sessions.data?.sessions.map((s) => s.symbol) ?? []);
  // Signals pushed over the socket, newest first, then the history fetched on load.
  const pushedIds = new Set(pushed.map((s) => s.id));
  const feed = [...pushed, ...(initialSignals.data?.signals ?? []).filter((s) => !pushedIds.has(s.id))].slice(0, 100);

  const onSignal = useCallback(
    (signal: SignalEvent) => {
      setPushed((current) => [signal, ...current.filter((s) => s.id !== signal.id)].slice(0, 100));
      sessions.reload();
    },
    [sessions],
  );
  useSignalListener(onSignal);

  const act = async (session: AdviserSession, action: "pause" | "resume" | "stop" | "evaluate") => {
    if (action === "evaluate") await api.evaluateSession(token, session.id);
    else await api.updateSession(token, session.id, action === "pause" ? "paused" : action === "resume" ? "active" : "stopped");
    sessions.reload();
  };

  return (
    <PageShell>
      <PageHeader
        title="Adviser"
        subtitle="Monitors your tickers at the interval you choose and emits colour-coded decision signals — green BUY, red SELL, orange HOLD — pushed to you in real time. It never places trades."
        actions={<NotificationToggle />}
      />
      <div className="grid gap-6 lg:grid-cols-[1fr_24rem]">
        <div className="space-y-6">
          <NewSession token={token} onCreated={sessions.reload} />
          <Card
            title="Monitored tickers"
            action={
              <span className="flex items-center gap-2 text-xs text-muted-foreground">
                <span className={`h-2 w-2 rounded-full ${connection === "open" ? "bg-gain" : "bg-hold"}`} />
                {connection === "open" ? "Live" : "Reconnecting…"}
              </span>
            }
          >
            <ErrorNote message={sessions.error} />
            {!sessions.data?.sessions.length ? (
              <EmptyState title="Nothing monitored yet">Add a ticker above, or start monitoring from any symbol page or Optimizer result.</EmptyState>
            ) : (
              <ul className="border-t border-border">
                {sessions.data.sessions.map((s) => {
                  const q = live[s.symbol];
                  return (
                    <li key={s.id} className={`border-b border-l-2 border-border py-4 pl-4 ${s.last_signal_type ? ROW_TONE[s.last_signal_type] : ""} ${s.status === "paused" ? "opacity-60" : ""}`}>
                      <div className="flex flex-wrap items-center gap-3">
                        <Link href={symbolHref(s.symbol)} className="font-semibold hover:text-brand">
                          {s.display_symbol}
                        </Link>
                        <span className="truncate text-sm text-muted-foreground">{s.name}</span>
                        <SourceBadge source={s.data_source} />
                        <span className="ml-auto">
                          <SignalBadge type={s.last_signal_type} />
                        </span>
                      </div>
                      <div className="mt-2 flex flex-wrap items-center gap-x-5 gap-y-1 text-sm">
                        <span className="tabular">
                          {formatNumber(q?.price ?? s.last_price)} <span className="text-xs text-muted-foreground">{currencyLabel(s.currency)}</span>
                        </span>
                        {q && <span className={`tabular ${changeClass(q.change_percent)}`}>{formatPercent(q.change_percent)}</span>}
                        <span className="text-muted-foreground">confidence {s.last_confidence != null ? `${(s.last_confidence * 100).toFixed(0)}%` : "—"}</span>
                        <span className="text-muted-foreground">every {formatInterval(s.interval_sec)}</span>
                        <span className="text-muted-foreground">{s.parameters ? "optimised params" : "default params"}</span>
                        <span className="text-xs text-muted-foreground">checked {formatDateTime(s.last_evaluated_at)}</span>
                      </div>
                      <div className="mt-3 flex flex-wrap gap-2 text-xs">
                        <button className="btn-secondary px-3 py-1" onClick={() => act(s, "evaluate")}>
                          Check now
                        </button>
                        <button className="btn-secondary px-3 py-1" onClick={() => act(s, s.status === "active" ? "pause" : "resume")}>
                          {s.status === "active" ? "Pause" : "Resume"}
                        </button>
                        <button className="btn-secondary px-3 py-1 text-loss" onClick={() => act(s, "stop")}>
                          Stop
                        </button>
                      </div>
                    </li>
                  );
                })}
              </ul>
            )}
          </Card>
        </div>

        <Card title="Signal feed">
          {!feed.length ? (
            <p className="text-sm text-muted-foreground">Signals appear here the moment the Adviser emits them.</p>
          ) : (
            <ol className="space-y-3">
              {feed.map((s) => (
                <li key={s.id} className={`border-l-4 pl-3 ${ROW_TONE[s.signal_type]}`}>
                  <div className="flex items-center justify-between gap-2">
                    <Link href={symbolHref(s.symbol)} className="text-sm font-semibold hover:text-brand">
                      {s.display_symbol}
                    </Link>
                    <SignalBadge type={s.signal_type} size="sm" />
                  </div>
                  <p className="text-xs text-muted-foreground">
                    {formatPrice(s.price, s.currency)} · {(s.confidence * 100).toFixed(0)}% · {formatDateTime(s.emitted_at)}
                  </p>
                  <p className="mt-1 text-xs">{s.reason}</p>
                </li>
              ))}
            </ol>
          )}
        </Card>
      </div>
    </PageShell>
  );
}

function NewSession({ token, onCreated }: { token: string; onCreated: () => void }) {
  const [query, setQuery] = useState("");
  const [matches, setMatches] = useState<TickerInfo[]>([]);
  const [ticker, setTicker] = useState<TickerInfo | null>(null);
  const [interval, setIntervalSec] = useState(300);
  const [runId, setRunId] = useState("");
  const runs = useAsync(() => (ticker ? api.optimizerRuns(token, ticker.symbol) : null), [token, ticker?.symbol]);
  const [error, setError] = useState<string | null>(null);

  const suggestions = query.trim() && !ticker ? matches : [];

  useEffect(() => {
    if (!query.trim() || ticker) return;
    const timer = setTimeout(() => api.search(query).then(({ results }) => setMatches(results.slice(0, 6))).catch(() => undefined), 180);
    return () => clearTimeout(timer);
  }, [query, ticker]);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!ticker) return;
    setError(null);
    try {
      await api.createSession(token, { symbol: ticker.symbol, interval_sec: interval, optimizer_run_id: runId || null });
      setQuery("");
      setTicker(null);
      setRunId("");
      onCreated();
    } catch (err) {
      setError(errorMessage(err));
    }
  };

  return (
    <Card title="Monitor a ticker">
      <form onSubmit={submit} className="grid gap-3 sm:grid-cols-[1fr_10rem_12rem_auto] sm:items-end">
        <div className="relative">
          <Field label="Exchange & ticker">
            <input className="input" placeholder="e.g. Dangote, SHOP, 005930" value={query} onChange={(e) => { setQuery(e.target.value); setTicker(null); }} />
          </Field>
          {suggestions.length > 0 && (
            <ul className="absolute z-20 mt-1 w-full rounded-xl border border-border bg-surface py-1 shadow-lg">
              {suggestions.map((m) => (
                <li key={m.symbol}>
                  <button
                    type="button"
                    className="flex w-full items-center gap-2 px-3 py-2 text-left text-sm hover:bg-surface-muted"
                    onClick={() => {
                      setTicker(m);
                      setQuery(m.display_symbol);
                    }}
                  >
                    <span className="font-semibold">{m.display_symbol}</span>
                    <span className="truncate text-muted-foreground">{m.name}</span>
                    <span className="ml-auto text-xs text-muted-foreground">{m.exchange}</span>
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>
        <Field label="Interval">
          <select className="input" value={interval} onChange={(e) => setIntervalSec(Number(e.target.value))}>
            <option value={60}>1 minute</option>
            <option value={300}>5 minutes</option>
            <option value={900}>15 minutes</option>
            <option value={3600}>1 hour</option>
            <option value={86400}>Daily</option>
          </select>
        </Field>
        <Field label="Parameters">
          <select className="input" value={runId} onChange={(e) => setRunId(e.target.value)} disabled={!ticker}>
            <option value="">Latest optimised / default</option>
            {runs.data?.runs
              .filter((r) => r.status === "completed")
              .map((r) => (
                <option key={r.id} value={r.id}>
                  {r.objective} {r.training_start}→{r.training_end}
                </option>
              ))}
          </select>
        </Field>
        <button className="btn-primary" disabled={!ticker}>
          Start
        </button>
      </form>
      <ErrorNote message={error} />
    </Card>
  );
}

const subscribeNever = () => () => undefined;

function NotificationToggle() {
  // Server render has no Notification API; the browser reads the real permission.
  const current = useSyncExternalStore(subscribeNever, () => (typeof Notification === "undefined" ? "unsupported" : Notification.permission), () => "unsupported" as const);
  const [requested, setPermission] = useState<NotificationPermission | null>(null);
  const permission = requested ?? current;
  if (permission === "unsupported" || permission === "granted") {
    return permission === "granted" ? <span className="text-xs text-muted-foreground">Desktop notifications on</span> : null;
  }
  return (
    <button className="btn-secondary" onClick={() => Notification.requestPermission().then(setPermission)} disabled={permission === "denied"}>
      {permission === "denied" ? "Notifications blocked" : "Enable desktop notifications"}
    </button>
  );
}
