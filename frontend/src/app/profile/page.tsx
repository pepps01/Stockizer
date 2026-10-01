"use client";

import { useState } from "react";
import { useAuth } from "@/lib/auth-context";
import { api } from "@/lib/api";
import { errorMessage } from "@/lib/use-async";
import type { AlertChannel, RiskProfile } from "@/lib/types";
import { RequireAuth } from "@/components/auth/RequireAuth";
import { ExchangePicker } from "@/components/market/ExchangePicker";
import { Card, ErrorNote, Field, PageHeader, PageShell } from "@/components/ui/primitives";

export default function ProfilePage() {
  return <RequireAuth feature="profile">{(token) => <Profile token={token} />}</RequireAuth>;
}

function Profile({ token }: { token: string }) {
  const { user, refreshUser } = useAuth();
  // RequireAuth only renders this once the token — and with it the user — is loaded.
  const [form, setForm] = useState({
    first_name: user?.first_name ?? "",
    last_name: user?.last_name ?? "",
    risk_profile: (user?.risk_profile ?? "moderate") as RiskProfile,
    alert_channels: (user?.alert_channels ?? ["in_app"]) as AlertChannel[],
    default_exchange: user?.default_exchange ?? "",
  });
  const [status, setStatus] = useState<"idle" | "saving" | "saved">("idle");
  const [error, setError] = useState<string | null>(null);

  const toggleChannel = (channel: AlertChannel) =>
    setForm((f) => ({
      ...f,
      alert_channels: f.alert_channels.includes(channel) ? f.alert_channels.filter((c) => c !== channel) : [...f.alert_channels, channel],
    }));

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setStatus("saving");
    setError(null);
    try {
      await api.updateMe(token, { ...form, default_exchange: form.default_exchange || null });
      await refreshUser();
      setStatus("saved");
    } catch (err) {
      setError(errorMessage(err));
      setStatus("idle");
    }
  };

  return (
    <PageShell width="max-w-xl">
      <PageHeader title="Profile" subtitle={user?.email} />
      <Card>
        <form onSubmit={submit} className="space-y-5">
          <div className="grid grid-cols-2 gap-3">
            <Field label="First name">
              <input className="input" value={form.first_name} onChange={(e) => setForm({ ...form, first_name: e.target.value })} required />
            </Field>
            <Field label="Last name">
              <input className="input" value={form.last_name} onChange={(e) => setForm({ ...form, last_name: e.target.value })} required />
            </Field>
          </div>
          <Field label="Risk profile" hint="Recorded with your account for future personalisation of signals.">
            <select className="input" value={form.risk_profile} onChange={(e) => setForm({ ...form, risk_profile: e.target.value as RiskProfile })}>
              <option value="conservative">Conservative</option>
              <option value="moderate">Moderate</option>
              <option value="aggressive">Aggressive</option>
            </select>
          </Field>
          <Field label="Default exchange">
            <ExchangePicker value={form.default_exchange} onChange={(code) => setForm({ ...form, default_exchange: code })} />
          </Field>
          <fieldset>
            <legend className="mb-2 text-sm font-medium">Signal alerts</legend>
            <label className="flex items-center gap-2 text-sm">
              <input type="checkbox" checked={form.alert_channels.includes("in_app")} onChange={() => toggleChannel("in_app")} /> In-app (live toasts)
            </label>
            <label className="mt-1 flex items-center gap-2 text-sm">
              <input type="checkbox" checked={form.alert_channels.includes("email")} onChange={() => toggleChannel("email")} /> Email me when a signal changes
            </label>
          </fieldset>
          <ErrorNote message={error} />
          <button className="btn-primary w-full" disabled={status === "saving"}>
            {status === "saving" ? "Saving…" : status === "saved" ? "Saved ✓" : "Save changes"}
          </button>
        </form>
      </Card>
    </PageShell>
  );
}
