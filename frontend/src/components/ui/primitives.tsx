import type { ReactNode } from "react";
import { changeClass, formatPercent, formatSigned } from "@/lib/format";

export function PageShell({ children, width = "max-w-7xl" }: { children: ReactNode; width?: string }) {
  return <main className={`mx-auto w-full ${width} flex-1 px-4 py-8 sm:px-6`}>{children}</main>;
}

export function PageHeader({ title, subtitle, actions, icon }: { title: ReactNode; subtitle?: ReactNode; actions?: ReactNode; icon?: ReactNode }) {
  return (
    <div className="mb-6 flex flex-wrap items-end justify-between gap-4">
      <div className="flex items-center gap-3">
        {icon}
        <div>
          <h1 className="text-[28px] font-bold tracking-tight sm:text-[32px]">{title}</h1>
          {subtitle && <p className="mt-1 max-w-2xl text-sm text-muted-foreground">{subtitle}</p>}
        </div>
      </div>
      {actions}
    </div>
  );
}

/** A page section: top hairline, small-caps title, content. Rules, not boxes. */
export function Card({ children, className = "", title, action }: { children: ReactNode; className?: string; title?: ReactNode; action?: ReactNode }) {
  return (
    <section className={`border-t border-border pt-5 pb-2 ${className}`}>
      {(title || action) && (
        <div className="mb-4 flex min-h-8 items-center justify-between gap-3">
          {typeof title === "string" ? <h2 className="label-caps">{title}</h2> : title}
          {action}
        </div>
      )}
      {children}
    </section>
  );
}

export function Change({ value, percent, className = "" }: { value?: number | null; percent?: number | null; className?: string }) {
  const tone = changeClass(percent ?? value);
  return (
    <span className={`tabular ${tone} ${className}`}>
      {value !== undefined && formatSigned(value)}
      {value !== undefined && percent !== undefined && " "}
      {percent !== undefined && (value !== undefined ? `(${formatPercent(percent)})` : formatPercent(percent))}
    </span>
  );
}

export function Skeleton({ className = "" }: { className?: string }) {
  return <div className={`animate-pulse rounded-lg bg-surface-muted ${className}`} />;
}

export function EmptyState({ title, children }: { title: string; children?: ReactNode }) {
  return (
    <div className="rounded-2xl border border-dashed border-border px-6 py-10 text-center">
      <p className="font-bold">{title}</p>
      {children && <div className="mt-2 text-sm text-muted-foreground">{children}</div>}
    </div>
  );
}

export function ErrorNote({ message }: { message: string | null | undefined }) {
  if (!message) return null;
  return <p className="rounded-lg bg-loss-soft px-3 py-2 text-sm text-loss">{message}</p>;
}

export function Segmented<T extends string>({ options, value, onChange }: { options: { value: T; label: string }[]; value: T; onChange: (v: T) => void }) {
  return (
    <div className="inline-flex rounded-full bg-surface-muted p-1 text-[13px]">
      {options.map((o) => (
        <button
          key={o.value}
          type="button"
          aria-pressed={value === o.value}
          onClick={() => onChange(o.value)}
          className={`min-h-8 rounded-full px-3.5 font-bold transition-colors ${value === o.value ? "bg-ink text-ink-foreground" : "text-muted-foreground hover:text-foreground"}`}
        >
          {o.label}
        </button>
      ))}
    </div>
  );
}

export function Stat({ label, value, hint }: { label: string; value: ReactNode; hint?: string }) {
  return (
    <div>
      <dt className="text-xs text-muted-foreground" title={hint}>
        {label}
      </dt>
      <dd className="tabular mt-0.5 text-[15px]">{value}</dd>
    </div>
  );
}

export function Field({ label, children, hint }: { label: string; children: ReactNode; hint?: string }) {
  return (
    <label className="block">
      <span className="mb-1.5 block text-sm font-bold">{label}</span>
      {children}
      {hint && <span className="mt-1 block text-xs text-muted-foreground">{hint}</span>}
    </label>
  );
}
