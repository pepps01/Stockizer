"use client";

import Link from "next/link";
import { useState } from "react";
import { api } from "@/lib/api";
import { useAuth } from "@/lib/auth-context";
import { errorMessage, useAsync } from "@/lib/use-async";
import { formatDateTime, formatPrice, symbolHref } from "@/lib/format";
import { RowAction, Tag } from "@/components/admin/AdminBits";
import { SignalBadge } from "@/components/ui/Badges";
import { EmptyState, ErrorNote, Segmented, Skeleton } from "@/components/ui/primitives";

type Filter = "active" | "paused" | "stopped" | "all";

function interval(sec: number) {
  if (sec % 86400 === 0) return `${sec / 86400}d`;
  if (sec % 3600 === 0) return `${sec / 3600}h`;
  return `${Math.round(sec / 60)}m`;
}

export default function AdminSessionsPage() {
  const { token } = useAuth();
  const [filter, setFilter] = useState<Filter>("active");
  const [error, setError] = useState<string | null>(null);
  const list = useAsync(() => api.adminSessions(token!, filter === "all" ? "" : filter), [token, filter]);

  const setStatus = async (id: string, status: "active" | "paused" | "stopped", label: string) => {
    if (status === "stopped" && !window.confirm(`Stop monitoring ${label}? The owner can start it again.`)) return;
    setError(null);
    try {
      await api.adminSetSessionStatus(token!, id, status);
      list.reload();
    } catch (err) {
      setError(errorMessage(err));
    }
  };

  return (
    <div className="space-y-6">
      <Segmented
        value={filter}
        onChange={setFilter}
        options={[
          { value: "active", label: "Live" },
          { value: "paused", label: "Paused" },
          { value: "stopped", label: "Stopped" },
          { value: "all", label: "All" },
        ]}
      />
      <ErrorNote message={error ?? list.error} />
      {!list.data ? (
        <Skeleton className="h-64" />
      ) : !list.data.sessions.length ? (
        <EmptyState title="No sessions here">Adviser sessions appear when users monitor a ticker.</EmptyState>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full min-w-[820px] text-sm">
            <thead>
              <tr className="border-b border-border text-left text-xs text-muted-foreground">
                <th className="py-2 pr-3 font-normal">Ticker</th>
                <th className="py-2 pr-3 font-normal">Owner</th>
                <th className="py-2 pr-3 font-normal">Every</th>
                <th className="py-2 pr-3 font-normal">Last signal</th>
                <th className="py-2 pr-3 font-normal">Last checked</th>
                <th className="py-2 pr-3 font-normal">Status</th>
                <th className="py-2 text-right font-normal">Actions</th>
              </tr>
            </thead>
            <tbody>
              {list.data.sessions.map((s) => (
                <tr key={s.id} className="border-b border-border">
                  <td className="py-3 pr-3">
                    <Link href={symbolHref(s.symbol)} className="font-bold hover:underline">
                      {s.display_symbol}
                    </Link>
                    <span className="block max-w-48 truncate text-xs text-muted-foreground">{s.name}</span>
                  </td>
                  <td className="py-3 pr-3 text-xs">{s.user_email}</td>
                  <td className="tabular py-3 pr-3">{interval(s.interval_sec)}</td>
                  <td className="py-3 pr-3">
                    {s.last_signal_type ? (
                      <span className="flex items-center gap-2">
                        <SignalBadge type={s.last_signal_type} />
                        <span className="tabular text-xs text-muted-foreground">{formatPrice(s.last_price, s.currency)}</span>
                      </span>
                    ) : (
                      <span className="text-muted-foreground">—</span>
                    )}
                  </td>
                  <td className="tabular py-3 pr-3 text-xs text-muted-foreground">{s.last_evaluated_at ? formatDateTime(s.last_evaluated_at) : "—"}</td>
                  <td className="py-3 pr-3">
                    <Tag tone={s.status === "active" ? "gain" : s.status === "paused" ? "hold" : "muted"}>{s.status === "active" ? "Live" : s.status}</Tag>
                  </td>
                  <td className="py-3 text-right">
                    <span className="inline-flex gap-1">
                      {s.status === "active" && <RowAction onClick={() => setStatus(s.id, "paused", s.display_symbol)}>Pause</RowAction>}
                      {s.status === "paused" && <RowAction onClick={() => setStatus(s.id, "active", s.display_symbol)}>Resume</RowAction>}
                      {s.status !== "stopped" && (
                        <RowAction danger onClick={() => setStatus(s.id, "stopped", s.display_symbol)}>
                          Stop
                        </RowAction>
                      )}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
