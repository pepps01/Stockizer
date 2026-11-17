"use client";

import Link from "next/link";
import { useState } from "react";
import { api } from "@/lib/api";
import { useAuth } from "@/lib/auth-context";
import { errorMessage, useAsync } from "@/lib/use-async";
import { PREFS, setBrowserPref, useBrowserPref, type WatchlistSort } from "@/lib/preferences";
import type { AlertChannel, User } from "@/lib/types";
import { ExchangePicker } from "@/components/market/ExchangePicker";
import { ErrorNote, PageShell, Segmented, Skeleton } from "@/components/ui/primitives";
import { Switch } from "@/components/ui/Switch";
import { ThemeSwitch } from "@/components/ui/ThemeSwitch";

const CHANNELS: { value: AlertChannel; label: string; text: string }[] = [
  { value: "in_app", label: "In-app signal alerts", text: "A banner whenever the Adviser emits a signal" },
  { value: "email", label: "Email alerts", text: "An email when a signal changes" },
  { value: "push", label: "Phone push notifications", text: "Sent to phones signed in to the Stockiser app, even when it's closed" },
];

/** Settings: appearance for everyone; notifications and market defaults for
 * signed-in investors. Every change saves on the spot. */
export default function SettingsPage() {
  const { user, token, isLoading } = useAuth();
  return (
    <PageShell width="max-w-2xl">
      <div className="flex flex-col gap-10">
        <header>
          <h1 className="text-[32px] font-bold tracking-tight">Settings</h1>
          <p className="mt-1 text-sm text-muted-foreground">Changes save as you make them.</p>
        </header>

        <Section title="Appearance">
          <Row label="Theme" hint="System follows your device. Saved in this browser.">
            <ThemeSwitch />
          </Row>
        </Section>

        {isLoading ? (
          <Skeleton className="h-48" />
        ) : user && token ? (
          <AccountSettings key={user.id} user={user} token={token} />
        ) : (
          <p className="border-y border-border py-5 text-sm text-muted-foreground">
            <Link href="/login" className="font-bold text-foreground underline underline-offset-4">
              Log in
            </Link>{" "}
            to manage signal alerts and your default exchange.
          </p>
        )}
      </div>
    </PageShell>
  );
}

function AccountSettings({ user, token }: { user: User; token: string }) {
  const { refreshUser, logout } = useAuth();
  const [channels, setChannels] = useState<AlertChannel[]>(user.alert_channels);
  const [exchange, setExchange] = useState(user.default_exchange ?? "");
  const [saved, setSaved] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const save = async (patch: { alert_channels?: AlertChannel[]; default_exchange?: string | null }, what: string, undo: () => void) => {
    setError(null);
    setSaved(null);
    try {
      await api.updateMe(token, patch);
      await refreshUser();
      setSaved(what);
    } catch (err) {
      undo();
      setError(errorMessage(err));
    }
  };

  const toggle = (channel: AlertChannel) => {
    const before = channels;
    const next = channels.includes(channel) ? channels.filter((c) => c !== channel) : [...channels, channel];
    setChannels(next);
    save({ alert_channels: next }, "Alerts saved", () => setChannels(before));
  };

  const chooseExchange = (code: string) => {
    const before = exchange;
    setExchange(code);
    save({ default_exchange: code || null }, "Default exchange saved", () => setExchange(before));
  };

  return (
    <>
      <Section title="Notifications">
        {CHANNELS.map((c) => (
          <Row key={c.value} label={c.label} hint={c.text}>
            <Switch label={c.label} checked={channels.includes(c.value)} onChange={() => toggle(c.value)} />
          </Row>
        ))}
      </Section>

      <Section title="Markets">
        <Row label="Default exchange" hint="Pre-selected when you open the Selector.">
          <div className="w-full sm:w-72">
            <ExchangePicker value={exchange} onChange={chooseExchange} />
          </div>
        </Row>
      </Section>

      <div aria-live="polite" className="-mt-6 min-h-5 text-sm">
        {saved && <span className="font-bold text-gain">✓ {saved}</span>}
        <ErrorNote message={error} />
      </div>

      <WatchlistSettings token={token} />

      <Section title="Account">
        <Row label="Signed in as" hint={user.email}>
          <button type="button" onClick={logout} className="btn-secondary">
            Log out
          </button>
        </Row>
        <Row label="Name, risk appetite and your positions" hint="These live on your investor profile.">
          <Link href="/profile" className="btn-secondary">
            Investor profile →
          </Link>
        </Row>
      </Section>
    </>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="flex flex-col">
      <h2 className="label-caps pb-2">{title}</h2>
      <div className="border-t border-border">{children}</div>
    </section>
  );
}

function Row({ label, hint, children }: { label: string; hint?: string; children: React.ReactNode }) {
  return (
    <div className="flex flex-wrap items-center justify-between gap-4 border-b border-border py-3.5">
      <span className="flex min-w-0 flex-1 flex-col">
        <span className="text-[15px]">{label}</span>
        {hint && <span className="truncate text-xs text-muted-foreground">{hint}</span>}
      </span>
      {children}
    </div>
  );
}

/** Watchlist order and Home visibility are kept in this browser; clearing it is account-wide. */
function WatchlistSettings({ token }: { token: string }) {
  const sort = useBrowserPref(PREFS.watchlistSort);
  const onHome = useBrowserPref(PREFS.homeWatchlist) === "show";
  const watch = useAsync(() => api.watchlist(token), [token]);
  const count = watch.data?.items.length ?? 0;
  const [confirming, setConfirming] = useState(false);
  const [clearing, setClearing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const clearAll = async () => {
    setClearing(true);
    setError(null);
    try {
      await Promise.all((watch.data?.items ?? []).map((i) => api.removeFromWatchlist(token, i.symbol)));
      setConfirming(false);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setClearing(false);
      watch.reload();
    }
  };

  return (
    <Section title="Watchlist">
      <Row label="Order" hint="Used on the Watchlist page, Home and your profile.">
        <Segmented
          value={sort}
          onChange={(v: WatchlistSort) => setBrowserPref(PREFS.watchlistSort, v)}
          options={[
            { value: "added", label: "Newest first" },
            { value: "name", label: "A–Z" },
            { value: "change", label: "Top movers" },
          ]}
        />
      </Row>
      <Row label="Show on Home" hint="Your first six symbols on the Home dashboard.">
        <Switch label="Show watchlist on Home" checked={onHome} onChange={() => setBrowserPref(PREFS.homeWatchlist, onHome ? "hide" : "show")} />
      </Row>
      <Row label="Clear watchlist" hint={count ? `Removes all ${count} symbol${count === 1 ? "" : "s"} from your account.` : "Your watchlist is empty."}>
        {confirming ? (
          <span className="flex items-center gap-2">
            <button type="button" onClick={() => setConfirming(false)} className="btn-secondary min-h-9 px-4">
              Keep
            </button>
            <button
              type="button"
              onClick={clearAll}
              disabled={clearing}
              className="inline-flex min-h-9 items-center rounded-full bg-loss px-4 text-sm font-bold text-white transition-opacity hover:opacity-90 disabled:opacity-50"
            >
              {clearing ? "Clearing…" : `Remove ${count}`}
            </button>
          </span>
        ) : (
          <button type="button" onClick={() => setConfirming(true)} disabled={!count} className="btn-secondary min-h-9 px-4 text-loss">
            Clear…
          </button>
        )}
      </Row>
      {error && (
        <div className="py-2">
          <ErrorNote message={error} />
        </div>
      )}
    </Section>
  );
}
