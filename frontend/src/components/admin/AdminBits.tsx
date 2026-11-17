import type { ReactNode } from "react";
import type { AdminAuditEntry } from "@/lib/types";
import { formatDateTime } from "@/lib/format";

/** A row of big light numbers separated by hairlines. */
export function StatStrip({ items }: { items: { label: string; value: ReactNode; hint?: string }[] }) {
  return (
    <dl className="grid grid-cols-2 border-y border-border sm:grid-cols-3 lg:grid-cols-6">
      {items.map((item, i) => (
        <div key={item.label} className={`py-4 pr-4 ${i > 0 ? "lg:border-l lg:border-border lg:pl-4" : ""}`}>
          <dt className="label-caps">{item.label}</dt>
          <dd className="tabular mt-1 text-3xl font-light">{item.value}</dd>
          {item.hint && <p className="mt-0.5 text-xs text-muted-foreground">{item.hint}</p>}
        </div>
      ))}
    </dl>
  );
}

/** Small uppercase status tag; tone only for states that matter. */
export function Tag({ children, tone = "muted" }: { children: ReactNode; tone?: "muted" | "gain" | "loss" | "hold" | "ink" }) {
  const tones = {
    muted: "text-muted-foreground",
    gain: "text-gain",
    loss: "text-loss",
    hold: "text-hold",
    ink: "text-foreground",
  };
  return <span className={`text-[11px] font-bold uppercase tracking-[0.1em] ${tones[tone]}`}>{children}</span>;
}

/** Quiet text button for row actions. */
export function RowAction({ children, onClick, danger, disabled }: { children: ReactNode; onClick: () => void; danger?: boolean; disabled?: boolean }) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      className={`rounded-full px-3 py-1 text-xs font-bold transition-colors disabled:opacity-40 ${
        danger ? "text-loss hover:bg-loss-soft" : "text-foreground hover:bg-surface-muted"
      }`}
    >
      {children}
    </button>
  );
}

export function Toggle({ checked, onChange, label, disabled }: { checked: boolean; onChange: () => void; label: string; disabled?: boolean }) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      aria-label={label}
      disabled={disabled}
      onClick={onChange}
      className={`relative h-6 w-10 shrink-0 rounded-full transition-colors disabled:opacity-40 ${checked ? "bg-mint-deep" : "bg-border"}`}
    >
      <span className={`absolute top-0.5 h-5 w-5 rounded-full bg-white shadow-sm transition-all ${checked ? "left-[18px]" : "left-0.5"}`} />
    </button>
  );
}

/** One audit entry as a sentence: "boss@x.com disabled trader@x.com". */
export function describeAction(a: AdminAuditEntry): string {
  const d = a.detail as Record<string, unknown>;
  if (a.action === "user.update") {
    const after = (d.after ?? {}) as Record<string, boolean>;
    const who = String(d.email ?? a.target_id);
    const parts = Object.entries(after).map(([flag, on]) => {
      if (flag === "is_admin") return on ? `made ${who} an admin` : `removed admin rights from ${who}`;
      if (flag === "is_active") return on ? `re-enabled ${who}` : `disabled ${who}${d.sessions_stopped ? ` and stopped ${d.sessions_stopped} session(s)` : ""}`;
      if (flag === "is_verified") return on ? `verified ${who}` : `unverified ${who}`;
      return `changed ${flag} for ${who}`;
    });
    return parts.join(", ");
  }
  if (a.action === "session.status") return `set the ${String(d.symbol ?? "")} session to ${String(d.after ?? "")}`;
  if (a.action === "ticker.active") return `${d.after ? "listed" : "hid"} ${a.target_id}`;
  return `${a.action} on ${a.target_type} ${a.target_id}`;
}

export function AuditList({ actions, empty = "No admin changes yet." }: { actions: AdminAuditEntry[]; empty?: string }) {
  if (!actions.length) return <p className="text-sm text-muted-foreground">{empty}</p>;
  return (
    <ul className="divide-y divide-border border-y border-border">
      {actions.map((a) => (
        <li key={a.id} className="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1 py-3 text-sm">
          <span>
            <span className="font-bold">{a.admin_email ?? "An admin"}</span> {describeAction(a)}
          </span>
          <span className="tabular text-xs text-muted-foreground">{formatDateTime(a.created_at)}</span>
        </li>
      ))}
    </ul>
  );
}
