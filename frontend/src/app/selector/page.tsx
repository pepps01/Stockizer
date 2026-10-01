"use client";

import Link from "next/link";
import { use, useState } from "react";
import { api } from "@/lib/api";
import { errorMessage, useAsync } from "@/lib/use-async";
import { formatDateTime, formatNumber, formatRatioPercent, symbolHref, changeClass } from "@/lib/format";
import type { SelectorRun } from "@/lib/types";
import { RequireAuth } from "@/components/auth/RequireAuth";
import { ExchangePicker } from "@/components/market/ExchangePicker";
import { SourceBadge } from "@/components/ui/Badges";
import { Card, EmptyState, ErrorNote, Field, PageHeader, PageShell } from "@/components/ui/primitives";

export default function SelectorPage({ searchParams }: { searchParams: Promise<{ exchange?: string }> }) {
  const { exchange } = use(searchParams);
  return <RequireAuth feature="Selector">{(token) => <Selector token={token} initialExchange={exchange ?? ""} />}</RequireAuth>;
}

function Selector({ token, initialExchange }: { token: string; initialExchange: string }) {
  const options = useAsync(() => api.selectorOptions(), []);
  const history = useAsync(() => api.selectorRuns(token), [token]);
  const [draft, setForm] = useState({ exchange: initialExchange.toUpperCase(), period_start: "", period_end: "", metric: "sharpe", top_n: 10 });
  const [run, setRun] = useState<SelectorRun | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  // Untouched dates fall back to the server's default period (last 12 months).
  const period = options.data?.default_period;
  const form = { ...draft, period_start: draft.period_start || period?.start || "", period_end: draft.period_end || period?.end || "" };

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      const { run } = await api.runSelector(token, form);
      setRun(run);
      history.reload();
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  const openRun = async (id: string) => setRun((await api.selectorRun(token, id)).run);

  return (
    <PageShell>
      <PageHeader
        title="Selector"
        subtitle="Rank an exchange's stocks by a performance criterion over a historical period, keep the top N, and save them to a ticker file for the Optimizer."
      />
      <div className="grid gap-6 lg:grid-cols-[22rem_1fr]">
        <div className="space-y-6">
          <Card title="1 · Configure">
            <form onSubmit={submit} className="space-y-4">
              <Field label="Stock exchange">
                <ExchangePicker value={form.exchange} onChange={(exchange) => setForm({ ...form, exchange })} />
              </Field>
              <div className="grid grid-cols-2 gap-3">
                <Field label="From">
                  <input type="date" className="input" value={form.period_start} onChange={(e) => setForm({ ...form, period_start: e.target.value })} required />
                </Field>
                <Field label="To">
                  <input type="date" className="input" value={form.period_end} onChange={(e) => setForm({ ...form, period_end: e.target.value })} required />
                </Field>
              </div>
              <Field label="Performance criterion">
                <select className="input" value={form.metric} onChange={(e) => setForm({ ...form, metric: e.target.value })}>
                  {options.data?.metrics.map((m) => (
                    <option key={m.value} value={m.value}>
                      {m.label}
                    </option>
                  ))}
                </select>
              </Field>
              <Field label="Keep top N">
                <input type="number" min={1} max={50} className="input" value={form.top_n} onChange={(e) => setForm({ ...form, top_n: Number(e.target.value) })} />
              </Field>
              <ErrorNote message={error} />
              <button className="btn-primary w-full" disabled={busy || !form.exchange}>
                {busy ? "Ranking… (first run downloads history)" : "Rank & select"}
              </button>
            </form>
          </Card>

          <Card title="Previous runs">
            {!history.data?.runs.length ? (
              <p className="text-sm text-muted-foreground">No runs yet.</p>
            ) : (
              <ul className="divide-y divide-border text-sm">
                {history.data.runs.map((r) => (
                  <li key={r.id}>
                    <button onClick={() => openRun(r.id)} className="w-full py-2 text-left hover:text-brand">
                      <span className="font-medium">{r.exchange}</span> · {r.metric} · top {r.top_n}
                      <span className="block text-xs text-muted-foreground">
                        {r.period_start} → {r.period_end} · {formatDateTime(r.created_at)}
                      </span>
                    </button>
                  </li>
                ))}
              </ul>
            )}
          </Card>
        </div>

        <Card
          title={run ? `2 · Top ${run.results?.length} of ${run.universe_size} on ${run.exchange_name}` : "2 · Results"}
          action={
            run && (
              <div className="flex flex-wrap gap-2">
                {run.artifact_id && (
                  <button className="btn-secondary" onClick={() => api.downloadArtifact(token, run.artifact_id!, "tickers.csv")}>
                    Download ticker file
                  </button>
                )}
                <Link href={`/optimizer?selector_run=${run.id}`} className="btn-primary">
                  Send to Optimizer →
                </Link>
              </div>
            )
          }
        >
          {!run ? (
            <EmptyState title="Run the Selector to see ranked tickers">Each run is saved with its ticker file so the Optimizer can pick it up.</EmptyState>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full min-w-[720px] text-sm">
                <thead>
                  <tr className="border-b border-border text-xs text-muted-foreground">
                    {["#", "Symbol", "Score", "Return", "Sharpe", "Volatility", "Max drawdown", "Momentum"].map((h, i) => (
                      <th key={h} className={`py-2 font-normal ${i < 2 ? "text-left" : "text-right"} px-2`}>
                        {h}
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {run.results?.map((r) => (
                    <tr key={r.symbol} className="border-b border-border/60">
                      <td className="px-2 py-2.5 font-semibold text-muted-foreground">{r.rank}</td>
                      <td className="px-2 py-2.5">
                        <Link href={symbolHref(r.symbol)} className="flex items-center gap-2 hover:text-brand">
                          <span className="font-semibold">{r.display_symbol}</span>
                          <span className="truncate text-muted-foreground">{r.name}</span>
                          <SourceBadge source={r.data_source} />
                        </Link>
                      </td>
                      <td className="tabular px-2 text-right font-semibold">{formatNumber(r.score, 3)}</td>
                      <td className={`tabular px-2 text-right ${changeClass(r.metrics.total_return)}`}>{formatRatioPercent(r.metrics.total_return, 1, true)}</td>
                      <td className="tabular px-2 text-right">{formatNumber(r.metrics.sharpe, 2)}</td>
                      <td className="tabular px-2 text-right">{formatRatioPercent(r.metrics.volatility, 1)}</td>
                      <td className="tabular px-2 text-right text-loss">{formatRatioPercent(r.metrics.max_drawdown, 1)}</td>
                      <td className={`tabular px-2 text-right ${changeClass(r.metrics.momentum)}`}>{formatRatioPercent(r.metrics.momentum, 1, true)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
              <p className="mt-3 text-xs text-muted-foreground">
                Period {run.period_start} → {run.period_end}. Past performance ranks candidates; it does not predict returns.
              </p>
            </div>
          )}
        </Card>
      </div>
    </PageShell>
  );
}
