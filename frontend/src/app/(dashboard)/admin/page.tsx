"use client";

import Link from "next/link";
import { api } from "@/lib/api";
import { useAuth } from "@/lib/auth-context";
import { useAsync } from "@/lib/use-async";
import { formatDateTime, formatPrice } from "@/lib/format";
import { AuditList, StatStrip, Tag } from "@/components/admin/AdminBits";
import { SignalBadge } from "@/components/ui/Badges";
import { Card, ErrorNote, Skeleton } from "@/components/ui/primitives";

export default function AdminOverviewPage() {
  const { token } = useAuth();
  const { data, error } = useAsync(() => api.adminOverview(token!), [token]);

  if (!data) {
    return (
      <>
        <ErrorNote message={error} />
        <Skeleton className="h-28" />
      </>
    );
  }
  const { users, pipeline, system } = data;
  return (
    <div className="space-y-10">
      <StatStrip
        items={[
          { label: "Users", value: users.total, hint: `${users.verified} verified · ${users.disabled} disabled` },
          { label: "New this week", value: users.new_7d },
          { label: "Live sessions", value: pipeline.active_sessions },
          { label: "Signals · 24h", value: pipeline.signals_24h },
          { label: "Optimizer runs", value: pipeline.optimizer_runs, hint: `${pipeline.selector_runs} selector runs` },
          { label: "Push devices", value: pipeline.push_devices },
        ]}
      />

      <div className="grid gap-10 lg:grid-cols-[1fr_22rem]">
        <div className="space-y-10">
          <Card title="Latest signals" action={<Link href="/admin/sessions" className="text-sm font-bold underline-offset-4 hover:underline">Sessions →</Link>}>
            {!data.recent_signals.length ? (
              <p className="text-sm text-muted-foreground">No signals yet.</p>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full min-w-[560px] text-sm">
                  <tbody>
                    {data.recent_signals.map((s) => (
                      <tr key={s.id} className="border-b border-border last:border-0">
                        <td className="tabular py-2.5 pr-3 text-xs text-muted-foreground">{formatDateTime(s.emitted_at)}</td>
                        <td className="py-2.5 pr-3 font-bold">{s.display_symbol}</td>
                        <td className="py-2.5 pr-3">
                          <SignalBadge type={s.signal_type} />
                        </td>
                        <td className="tabular py-2.5 pr-3 text-right">{formatPrice(s.price, s.currency)}</td>
                        <td className="truncate py-2.5 text-right text-xs text-muted-foreground">{s.user_email}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </Card>

          <Card title="Recent admin activity" action={<Link href="/admin/audit" className="text-sm font-bold underline-offset-4 hover:underline">Audit log →</Link>}>
            <AuditList actions={data.recent_actions} />
          </Card>
        </div>

        <aside className="space-y-10">
          <Card title="System">
            <dl className="divide-y divide-border border-y border-border text-sm">
              {[
                ["Market data", <Tag key="m" tone="ink">{system.market_data_mode}</Tag>],
                ["Adviser worker", <Tag key="w" tone={system.adviser_worker ? "gain" : "hold"}>{system.adviser_worker ? "Running here" : "External"}</Tag>],
                ["Push notifications", <Tag key="p" tone={system.push_enabled ? "gain" : "hold"}>{system.push_enabled ? "FCM on" : "Not configured"}</Tag>],
                ["Email alerts", <Tag key="e" tone={system.email_enabled ? "gain" : "hold"}>{system.email_enabled ? "SendGrid on" : "Not configured"}</Tag>],
              ].map(([label, value]) => (
                <div key={String(label)} className="flex items-center justify-between py-2.5">
                  <dt className="text-muted-foreground">{label}</dt>
                  <dd>{value}</dd>
                </div>
              ))}
            </dl>
          </Card>

          <Card title="Newest accounts" action={<Link href="/admin/users" className="text-sm font-bold underline-offset-4 hover:underline">Users →</Link>}>
            <ul className="divide-y divide-border border-y border-border text-sm">
              {data.recent_users.map((u) => (
                <li key={u.id} className="flex items-center justify-between gap-3 py-2.5">
                  <span className="min-w-0">
                    <span className="block truncate font-bold">
                      {u.first_name} {u.last_name}
                    </span>
                    <span className="block truncate text-xs text-muted-foreground">{u.email}</span>
                  </span>
                  {u.is_admin ? <Tag tone="ink">Admin</Tag> : !u.is_verified ? <Tag tone="hold">Unverified</Tag> : null}
                </li>
              ))}
            </ul>
          </Card>
        </aside>
      </div>
    </div>
  );
}
