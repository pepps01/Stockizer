"use client";

import { useState } from "react";
import { useAuth } from "@/lib/auth-context";
import { api } from "@/lib/api";
import { errorMessage, useAsync } from "@/lib/use-async";
import Link from "next/link";
import type { RiskProfile } from "@/lib/types";
import { RequireAuth } from "@/components/auth/RequireAuth";
import { ErrorNote, Field, PageShell } from "@/components/ui/primitives";
import { AssumedPositions } from "@/components/profile/AssumedPositions";
import { WatchlistSection } from "@/components/profile/WatchlistSection";

export default function ProfilePage() {
  return <RequireAuth feature="profile">{(token) => <Profile token={token} />}</RequireAuth>;
}

const RISK: { value: RiskProfile; label: string; text: string }[] = [
  { value: "conservative", label: "Conservative", text: "You prefer steadiness over growth and want fewer, surer moves." },
  { value: "moderate", label: "Moderate", text: "You accept some swings in exchange for growth." },
  { value: "aggressive", label: "Aggressive", text: "You are comfortable with large swings in pursuit of higher returns." },
];

function Profile({ token }: { token: string }) {
  const { user, refreshUser } = useAuth();
  // RequireAuth only renders this once the token — and with it the user — is loaded.
  const [form, setForm] = useState({
    first_name: user?.first_name ?? "",
    last_name: user?.last_name ?? "",
    risk_profile: (user?.risk_profile ?? "moderate") as RiskProfile,
  });
  const [status, setStatus] = useState<"idle" | "saving" | "saved">("idle");
  const [error, setError] = useState<string | null>(null);
  // The journal counts the buy / hold / sell calls assumed from Financials or a symbol page.
  const journal = useAsync(() => api.assumptions(token), [token]);
  const watch = useAsync(() => api.watchlist(token), [token]);
  const count = (a: string) => journal.data?.assumptions.filter((x) => x.stance === a).length ?? 0;

  const edit = (patch: Partial<typeof form>) => {
    setForm((f) => ({ ...f, ...patch }));
    setStatus("idle");
  };
  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setStatus("saving");
    setError(null);
    try {
      await api.updateMe(token, form);
      await refreshUser();
      setStatus("saved");
    } catch (err) {
      setError(errorMessage(err));
      setStatus("idle");
    }
  };

  const initials = `${form.first_name[0] ?? ""}${form.last_name[0] ?? ""}`.toUpperCase();
  const since = user ? new Date(user.created_at).toLocaleDateString(undefined, { month: "short", year: "numeric" }) : "";
  const risk = RISK.find((r) => r.value === form.risk_profile) ?? RISK[1];

  return (
    <PageShell width="max-w-2xl">
      <form onSubmit={submit} className="flex flex-col gap-10">
        <div className="flex flex-wrap items-end justify-between gap-3">
          <h1 className="text-[32px] font-bold tracking-tight">Investor profile</h1>
          <Link href="/settings" className="text-sm font-bold text-muted-foreground underline-offset-4 hover:text-foreground hover:underline">
            Alerts, theme and defaults are in Settings →
          </Link>
        </div>

        <section className="flex items-center gap-4">
          <span className="flex h-16 w-16 shrink-0 items-center justify-center rounded-full bg-surface-muted text-2xl font-bold">{initials}</span>
          <div className="flex min-w-0 flex-col gap-0.5">
            <span className="text-lg font-bold">
              {form.first_name} {form.last_name}
            </span>
            <span className="truncate text-sm text-muted-foreground">{user?.email}</span>
            {user?.is_verified && <span className="text-xs font-bold text-gain">✓ Email verified · since {since}</span>}
          </div>
        </section>

        <section className="grid gap-3 sm:grid-cols-2">
          <Field label="First name">
            <input className="input" value={form.first_name} onChange={(e) => edit({ first_name: e.target.value })} required />
          </Field>
          <Field label="Last name">
            <input className="input" value={form.last_name} onChange={(e) => edit({ last_name: e.target.value })} required />
          </Field>
        </section>

        <section className="flex flex-col gap-3">
          <h2 className="label-caps">Risk appetite</h2>
          <div role="radiogroup" aria-label="Risk appetite" className="flex rounded-full bg-surface-muted p-1">
            {RISK.map((r) => (
              <button
                key={r.value}
                type="button"
                role="radio"
                aria-checked={form.risk_profile === r.value}
                onClick={() => edit({ risk_profile: r.value })}
                className={`min-h-10 flex-1 rounded-full text-[13px] font-bold transition-colors ${form.risk_profile === r.value ? "bg-ink text-ink-foreground" : "text-muted-foreground hover:text-foreground"}`}
              >
                {r.label}
              </button>
            ))}
          </div>
          <p className="text-sm text-muted-foreground">{risk.text} Change it any time.</p>
        </section>

        <section className="flex flex-col gap-2.5">
          <h2 className="label-caps">Your journal</h2>
          <dl className="grid grid-cols-4 border-y border-border">
            {[
              ["Assumed buy", count("buy"), "text-gain"],
              ["Assumed hold", count("hold"), "text-hold"],
              ["Assumed sell", count("sell"), "text-loss"],
              ["Watching", watch.data?.items.length ?? 0, ""],
            ].map(([label, value, tone]) => (
              <div key={label as string} className="flex flex-col py-3">
                <dd className={`tabular text-2xl font-light ${tone}`}>{value}</dd>
                <dt className="text-xs text-muted-foreground">{label}</dt>
              </div>
            ))}
          </dl>
        </section>

        <ErrorNote message={error} />
        <button className="btn-primary self-start" disabled={status === "saving"}>
          {status === "saving" ? "Saving…" : status === "saved" ? "Saved ✓" : "Save changes"}
        </button>
      </form>

      <div className="mt-14 flex flex-col gap-12">
        <AssumedPositions token={token} onChanged={journal.reload} />
        <WatchlistSection token={token} />

      </div>
    </PageShell>
  );
}
