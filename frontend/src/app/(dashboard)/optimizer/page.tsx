"use client";

import Link from "next/link";
import { use, useState } from "react";
import { api } from "@/lib/api";
import { errorMessage, useAsync } from "@/lib/use-async";
import { useResolvedTheme } from "@/lib/theme";
import { changeClass, formatDateTime, formatNumber, formatRatioPercent, symbolHref } from "@/lib/format";
import type { BacktestSummary, OptimizerRun, ParamOption, StrategyKey } from "@/lib/types";
import { RequireAuth } from "@/components/auth/RequireAuth";
import { EquityChart } from "@/components/charts/EquityChart";
import { SourceBadge } from "@/components/ui/Badges";
import { Card, EmptyState, ErrorNote, Field, PageHeader, PageShell, Segmented } from "@/components/ui/primitives";

type Bounds = Record<string, [number, number]>;

const STRATEGY_SHORT: Record<StrategyKey, string> = { algebraic: "Algebraic", indicators: "Stoch · MACD · RSI" };

/** Indicator parameters are shown in the groups traders know them by. */
function paramGroup(name: string): string {
  if (name.startsWith("stoch_")) return "Stochastic";
  if (name.startsWith("macd_")) return "MACD";
  if (name.startsWith("rsi_") || name === "overbought" || name === "oversold") return "RSI";
  return "Signal";
}

function isoYearsAgo(years: number) {
  const d = new Date();
  d.setFullYear(d.getFullYear() - years);
  return d.toISOString().slice(0, 10);
}

export default function OptimizerPage({ searchParams }: { searchParams: Promise<{ selector_run?: string; symbol?: string }> }) {
  const params = use(searchParams);
  return <RequireAuth feature="Optimizer">{(token) => <Optimizer token={token} initialRun={params.selector_run} initialSymbol={params.symbol} />}</RequireAuth>;
}

function Optimizer({ token, initialRun, initialSymbol }: { token: string; initialRun?: string; initialSymbol?: string }) {
  const options = useAsync(() => api.optimizerOptions(), []);
  const selectorRuns = useAsync(() => api.selectorRuns(token), [token]);
  const history = useAsync(() => api.optimizerRuns(token), [token]);

  const [source, setSource] = useState<"selector" | "symbols">(initialSymbol ? "symbols" : "selector");
  const [chosenRunId, setSelectorRunId] = useState(initialRun ?? "");
  const [topK, setTopK] = useState(3);
  const [symbols, setSymbols] = useState(initialSymbol ?? "");
  const [trainingStart, setTrainingStart] = useState(isoYearsAgo(4));
  const [trainingEnd, setTrainingEnd] = useState(isoYearsAgo(1));
  const [objective, setObjective] = useState("sharpe");
  const [strategy, setStrategy] = useState<StrategyKey>("algebraic");
  const [bounds, setBounds] = useState<Bounds>({});
  const [results, setResults] = useState<OptimizerRun[]>([]);
  const [selected, setSelected] = useState<OptimizerRun | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const selectorRunId = chosenRunId || selectorRuns.data?.runs[0]?.id || "";

  const select = async (run: OptimizerRun) => setSelected(run.status === "completed" ? (await api.optimizerRun(token, run.id)).run : run);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      const { runs } = await api.runOptimizer(token, {
        ...(source === "selector"
          ? { selector_run_id: selectorRunId, top_k: topK }
          : { symbols: symbols.split(/[\s,]+/).filter(Boolean).map((s) => s.toUpperCase()) }),
        training_start: trainingStart,
        training_end: trainingEnd,
        objective,
        strategy,
        bounds,
      });
      setResults(runs);
      history.reload();
      const first = runs.find((r) => r.status === "completed");
      if (first) await select(first);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  const strategyInfo = options.data?.strategies.find((s) => s.key === strategy);
  const parameters = strategyInfo?.parameters ?? [];
  const groups = [...new Set(parameters.map((p) => paramGroup(p.name)))];
  const chooseStrategy = (next: StrategyKey) => {
    setStrategy(next);
    setBounds({});
  };

  const shown = results.length ? results : history.data?.runs.slice(0, 12) ?? [];

  return (
    <PageShell>
      <PageHeader
        title="Optimizer"
        subtitle="Pick a strategy, estimate its best parameters on a training period, then check them on the unseen period that follows — compared with simply buying and holding."
      />
      <div className="grid gap-6 lg:grid-cols-[24rem_1fr]">
        <Card title="Configure">
          <form onSubmit={submit} className="space-y-4">
            {options.data?.strategies && (
              <Field label="Strategy">
                <Segmented
                  value={strategy}
                  onChange={chooseStrategy}
                  options={options.data.strategies.map((s) => ({ value: s.key, label: STRATEGY_SHORT[s.key] ?? s.label }))}
                />
                {strategyInfo && <p className="mt-2 text-xs leading-relaxed text-muted-foreground">{strategyInfo.description}</p>}
              </Field>
            )}
            <Segmented
              value={source}
              onChange={setSource}
              options={[
                { value: "selector", label: "From Selector file" },
                { value: "symbols", label: "Symbols" },
              ]}
            />
            {source === "selector" ? (
              <div className="grid grid-cols-[1fr_5rem] gap-3">
                <Field label="Ticker file">
                  <select className="input" value={selectorRunId} onChange={(e) => setSelectorRunId(e.target.value)} required>
                    {!selectorRuns.data?.runs.length && <option value="">Run the Selector first</option>}
                    {selectorRuns.data?.runs.map((r) => (
                      <option key={r.id} value={r.id}>
                        {r.exchange} · {r.metric} · {r.period_start}→{r.period_end}
                      </option>
                    ))}
                  </select>
                </Field>
                <Field label="Top K">
                  <input type="number" min={1} max={10} className="input" value={topK} onChange={(e) => setTopK(Number(e.target.value))} />
                </Field>
              </div>
            ) : (
              <Field label="Symbols" hint="Comma-separated, e.g. AAPL, RY.TO, DANGCEM.NGX (max 10)">
                <input className="input" value={symbols} onChange={(e) => setSymbols(e.target.value)} required />
              </Field>
            )}
            <div className="grid grid-cols-2 gap-3">
              <Field label="Training from">
                <input type="date" className="input" value={trainingStart} onChange={(e) => setTrainingStart(e.target.value)} />
              </Field>
              <Field label="Training to">
                <input type="date" className="input" value={trainingEnd} onChange={(e) => setTrainingEnd(e.target.value)} />
              </Field>
            </div>
            <Field label="Objective">
              <select className="input" value={objective} onChange={(e) => setObjective(e.target.value)}>
                {options.data?.objectives.map((o) => (
                  <option key={o} value={o}>
                    {o.replace("_", " ")}
                  </option>
                ))}
              </select>
            </Field>
            <fieldset>
              <legend className="mb-1 text-sm font-bold">Parameter bounds</legend>
              <p className="mb-3 text-xs text-muted-foreground">The search stays inside these ranges.</p>
              <div className="space-y-4">
                {groups.map((group) => (
                  <div key={group}>
                    <div className="mb-2 grid grid-cols-[1fr_4.5rem_4.5rem] items-end gap-2">
                      <h3 className="label-caps">{groups.length > 1 ? group : "Parameter"}</h3>
                      <span className="text-center text-[10px] font-bold uppercase tracking-[0.1em] text-muted-foreground">Lower</span>
                      <span className="text-center text-[10px] font-bold uppercase tracking-[0.1em] text-muted-foreground">Upper</span>
                    </div>
                    <div className="space-y-2">
                      {parameters
                        .filter((p) => paramGroup(p.name) === group)
                        .map((p) => (
                          <BoundInput key={p.name} param={p} value={bounds[p.name]} onChange={(v) => setBounds({ ...bounds, [p.name]: v })} />
                        ))}
                    </div>
                  </div>
                ))}
              </div>
            </fieldset>
            <ErrorNote message={error} />
            <button className="btn-primary w-full" disabled={busy}>
              {busy ? "Estimating…" : "Estimate parameters"}
            </button>
          </form>
        </Card>

        <div className="space-y-6">
          {selected && <RunDetail run={selected} token={token} />}
          <Card title={results.length ? "This batch" : "Recent runs"}>
            {!shown.length ? (
              <EmptyState title="No optimisation runs yet" />
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full min-w-[720px] text-sm">
                  <thead>
                    <tr className="border-b border-border text-xs text-muted-foreground">
                      {["Symbol", "Strategy", "Objective", "Train score", "Out-of-sample", "vs buy & hold", "Created"].map((h, i) => (
                        <th key={h} className={`px-2 py-2 font-normal ${i === 0 ? "text-left" : "text-right"}`}>
                          {h}
                        </th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {shown.map((r) => (
                      <tr key={r.id} onClick={() => select(r)} className={`cursor-pointer border-b border-border/60 hover:bg-surface-muted ${selected?.id === r.id ? "bg-brand-soft" : ""}`}>
                        <td className="px-2 py-2.5">
                          <span className="font-semibold">{r.display_symbol}</span> <SourceBadge source={r.data_source} />
                          {r.status === "failed" && <span className="block text-xs text-loss">{r.error}</span>}
                        </td>
                        <td className="px-2 text-right text-xs text-muted-foreground">{STRATEGY_SHORT[r.strategy] ?? r.strategy}</td>
                        <td className="px-2 text-right">{r.objective}</td>
                        <td className="tabular px-2 text-right">{formatNumber(r.best_score, 2)}</td>
                        <td className="tabular px-2 text-right">{formatNumber(r.metrics.test?.strategy[r.objective as keyof BacktestSummary["strategy"]], 2)}</td>
                        <td className="tabular px-2 text-right">{formatNumber(r.metrics.test?.buy_and_hold[r.objective as keyof BacktestSummary["strategy"]], 2)}</td>
                        <td className="px-2 text-right text-xs text-muted-foreground">{formatDateTime(r.created_at)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </Card>
        </div>
      </div>
    </PageShell>
  );
}

function BoundInput({ param, value, onChange }: { param: ParamOption; value?: [number, number]; onChange: (v: [number, number]) => void }) {
  const [lo, hi] = value ?? [param.low, param.high];
  const step = param.type === "int" ? 1 : 0.05;
  return (
    <div className="grid grid-cols-[1fr_4.5rem_4.5rem] items-center gap-2 text-sm" title={param.description}>
      <span className="truncate text-muted-foreground">{param.description}</span>
      <input type="number" className="input px-2 py-1" step={step} min={param.low} max={hi} value={lo} onChange={(e) => onChange([Number(e.target.value), hi])} aria-label={`${param.name} low`} />
      <input type="number" className="input px-2 py-1" step={step} min={lo} max={param.high} value={hi} onChange={(e) => onChange([lo, Number(e.target.value)])} aria-label={`${param.name} high`} />
    </div>
  );
}

function RunDetail({ run, token }: { run: OptimizerRun; token: string }) {
  const [period, setPeriod] = useState<"train" | "test">(run.metrics.test ? "test" : "train");
  const theme = useResolvedTheme();
  const [status, setStatus] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const summary = run.metrics[period];
  const curve = run.metrics.curves?.[period] ?? [];

  const monitor = async () => {
    setError(null);
    try {
      await api.createSession(token, { symbol: run.symbol, interval_sec: 300, optimizer_run_id: run.id });
      setStatus("Adviser session started with these parameters.");
    } catch (err) {
      setError(errorMessage(err));
    }
  };

  if (run.status === "failed") {
    return (
      <Card title={`${run.display_symbol} — failed`}>
        <ErrorNote message={run.error} />
      </Card>
    );
  }

  return (
    <Card
      title={
        <Link href={symbolHref(run.symbol)} className="text-lg font-bold hover:underline">
          {run.display_symbol} · {run.name}
        </Link>
      }
      action={
        <div className="flex flex-wrap gap-2">
          {run.artifact_id && (
            <button className="btn-secondary" onClick={() => api.downloadArtifact(token, run.artifact_id!, "params.json")}>
              Download parameters
            </button>
          )}
          <button className="btn-primary" onClick={monitor}>
            Monitor with Adviser
          </button>
        </div>
      }
    >
      <p className="label-caps mb-3">
        {STRATEGY_SHORT[run.strategy] ?? run.strategy} · {run.objective.replace("_", " ")}
      </p>
      <div className="flex flex-wrap gap-2">
        {Object.entries(run.parameters).map(([k, v]) => (
          <span key={k} className="rounded-full bg-surface-muted px-3 py-1 text-xs">
            {k} = <span className="tabular font-semibold">{Number.isInteger(v) ? v : v.toFixed(3)}</span>
          </span>
        ))}
      </div>
      {run.metrics.min_trades_met === false && (
        <p className="mt-3 rounded-lg bg-hold-soft px-3 py-2 text-xs text-hold">No parameter set traded often enough in training — treat these values with caution.</p>
      )}

      <div className="mt-5 grid grid-cols-2 gap-6" role="tablist" aria-label="Evaluation period">
        {([
          ["train", "Training", `${run.training_start} → ${run.training_end}`],
          ...(run.metrics.test ? [["test", "Unseen", `${run.metrics.test_period?.start} → ${run.metrics.test_period?.end}`]] : []),
        ] as ["train" | "test", string, string][]).map(([key, label, dates]) => {
          const m = run.metrics[key];
          const selected = key === period;
          return (
            <button
              key={key}
              role="tab"
              aria-selected={selected}
              onClick={() => setPeriod(key)}
              className={`border-b pb-3 text-left transition-colors ${selected ? "border-b-2 border-foreground" : "border-border hover:border-muted-foreground"}`}
            >
              <span className={`label-caps ${key === "test" ? "!text-brand" : ""}`}>{label}</span>
              <span className="tabular block text-xs text-muted-foreground">{dates}</span>
              <span className={`tabular mt-2 block text-3xl font-light ${changeClass(m?.strategy.total_return)}`}>
                {formatRatioPercent(m?.strategy.total_return, 1, true)}
              </span>
              <span className="block text-xs text-muted-foreground">vs {formatRatioPercent(m?.buy_and_hold.total_return, 1, true)} buy &amp; hold</span>
            </button>
          );
        })}
      </div>

      {summary && (
        <div className="mt-4 overflow-x-auto">
          <table className="w-full min-w-[520px] text-sm">
            <thead>
              <tr className="border-b border-border text-xs text-muted-foreground">
                <th className="py-2 text-left font-normal" />
                {["Return", "CAGR", "Sharpe", "Sortino", "Max drawdown", "Volatility"].map((h) => (
                  <th key={h} className="px-2 py-2 text-right font-normal">
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {(["strategy", "buy_and_hold"] as const).map((key) => {
                const s = summary[key];
                return (
                  <tr key={key} className="border-b border-border/60">
                    <td className="py-2 font-medium">{key === "strategy" ? "Stockiser signal" : "Buy & hold"}</td>
                    <td className={`tabular px-2 text-right ${changeClass(s.total_return)}`}>{formatRatioPercent(s.total_return, 1, true)}</td>
                    <td className="tabular px-2 text-right">{formatRatioPercent(s.cagr, 1, true)}</td>
                    <td className="tabular px-2 text-right">{formatNumber(s.sharpe, 2)}</td>
                    <td className="tabular px-2 text-right">{formatNumber(s.sortino, 2)}</td>
                    <td className="tabular px-2 text-right text-loss">{formatRatioPercent(s.max_drawdown, 1)}</td>
                    <td className="tabular px-2 text-right">{formatRatioPercent(s.volatility, 1)}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
          <p className="mt-2 text-xs text-muted-foreground">
            {summary.trades} entries · {summary.win_rate != null ? `${(summary.win_rate * 100).toFixed(0)}% winning trades · ` : ""}
            in the market {(summary.exposure * 100).toFixed(0)}% of days · 10 bps cost per trade
          </p>
        </div>
      )}
      {curve.length > 0 && (
        <div className="mt-4">
          <EquityChart key={theme} points={curve} />
        </div>
      )}
      {status && <p className="mt-3 text-sm text-gain">{status}</p>}
      <ErrorNote message={error} />
    </Card>
  );
}
