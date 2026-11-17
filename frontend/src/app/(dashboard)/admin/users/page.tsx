"use client";

import { useState } from "react";
import { api } from "@/lib/api";
import { useAuth } from "@/lib/auth-context";
import { errorMessage, useAsync } from "@/lib/use-async";
import { formatDateTime } from "@/lib/format";
import type { AdminUser } from "@/lib/types";
import { RowAction, Tag } from "@/components/admin/AdminBits";
import { EmptyState, ErrorNote, Skeleton } from "@/components/ui/primitives";

type Flag = "is_admin" | "is_active" | "is_verified";

export default function AdminUsersPage() {
  const { token, user: me } = useAuth();
  const [query, setQuery] = useState("");
  const [search, setSearch] = useState("");
  const [page, setPage] = useState(1);
  const [error, setError] = useState<string | null>(null);
  const list = useAsync(() => api.adminUsers(token!, search, page), [token, search, page]);

  const change = async (u: AdminUser, flag: Flag, value: boolean, confirmText?: string) => {
    if (confirmText && !window.confirm(confirmText)) return;
    setError(null);
    try {
      await api.adminUpdateUser(token!, u.id, { [flag]: value });
      list.reload();
    } catch (err) {
      setError(errorMessage(err));
    }
  };

  const data = list.data;
  const pages = data ? Math.max(1, Math.ceil(data.total / data.page_size)) : 1;

  return (
    <div className="space-y-6">
      <form
        className="flex max-w-md gap-2"
        onSubmit={(e) => {
          e.preventDefault();
          setPage(1);
          setSearch(query.trim());
        }}
      >
        <input className="input" placeholder="Search name or email" value={query} onChange={(e) => setQuery(e.target.value)} aria-label="Search users" />
        <button className="btn-secondary">Search</button>
      </form>

      <ErrorNote message={error ?? list.error} />

      {!data ? (
        <Skeleton className="h-64" />
      ) : !data.users.length ? (
        <EmptyState title="No accounts match">Try another name or email.</EmptyState>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full min-w-[860px] text-sm">
            <thead>
              <tr className="border-b border-border text-left text-xs text-muted-foreground">
                <th className="py-2 pr-3 font-normal">Account</th>
                <th className="py-2 pr-3 font-normal">Joined</th>
                <th className="py-2 pr-3 font-normal">Status</th>
                <th className="py-2 pr-3 text-right font-normal">Selector</th>
                <th className="py-2 pr-3 text-right font-normal">Optimizer</th>
                <th className="py-2 pr-3 text-right font-normal">Live</th>
                <th className="py-2 text-right font-normal">Actions</th>
              </tr>
            </thead>
            <tbody>
              {data.users.map((u) => {
                const self = u.id === me?.id;
                const name = `${u.first_name} ${u.last_name}`;
                return (
                  <tr key={u.id} className={`border-b border-border ${u.is_active === false ? "opacity-60" : ""}`}>
                    <td className="py-3 pr-3">
                      <span className="block font-bold">
                        {name}
                        {self && <span className="ml-2 text-xs font-normal text-muted-foreground">(you)</span>}
                      </span>
                      <span className="block text-xs text-muted-foreground">{u.email}</span>
                    </td>
                    <td className="tabular py-3 pr-3 text-xs text-muted-foreground">{formatDateTime(u.created_at)}</td>
                    <td className="py-3 pr-3">
                      <span className="flex flex-wrap gap-x-3 gap-y-1">
                        {u.is_admin && <Tag tone="ink">Admin</Tag>}
                        {u.is_active === false ? <Tag tone="loss">Disabled</Tag> : u.is_verified ? <Tag tone="gain">Verified</Tag> : <Tag tone="hold">Unverified</Tag>}
                      </span>
                    </td>
                    <td className="tabular py-3 pr-3 text-right">{u.activity.selector_runs}</td>
                    <td className="tabular py-3 pr-3 text-right">{u.activity.optimizer_runs}</td>
                    <td className="tabular py-3 pr-3 text-right">{u.activity.active_sessions}</td>
                    <td className="py-3 text-right">
                      <span className="inline-flex flex-wrap justify-end gap-1">
                        {!u.is_verified && <RowAction onClick={() => change(u, "is_verified", true)}>Verify</RowAction>}
                        <RowAction
                          disabled={self}
                          onClick={() =>
                            change(u, "is_admin", !u.is_admin, u.is_admin ? `Remove admin rights from ${name}?` : `Give ${name} full admin access?`)
                          }
                        >
                          {u.is_admin ? "Remove admin" : "Make admin"}
                        </RowAction>
                        <RowAction
                          danger={u.is_active !== false}
                          disabled={self}
                          onClick={() =>
                            change(
                              u,
                              "is_active",
                              u.is_active === false,
                              u.is_active === false ? undefined : `Disable ${name}? They are signed out and their live sessions stop.`,
                            )
                          }
                        >
                          {u.is_active === false ? "Enable" : "Disable"}
                        </RowAction>
                      </span>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}

      {data && pages > 1 && (
        <div className="flex items-center justify-between text-sm">
          <span className="text-muted-foreground">
            {data.total} accounts · page {data.page} of {pages}
          </span>
          <span className="flex gap-2">
            <button className="btn-secondary" disabled={page <= 1} onClick={() => setPage(page - 1)}>
              Previous
            </button>
            <button className="btn-secondary" disabled={page >= pages} onClick={() => setPage(page + 1)}>
              Next
            </button>
          </span>
        </div>
      )}
    </div>
  );
}
