"use client";

import { api } from "@/lib/api";
import { useAuth } from "@/lib/auth-context";
import { useAsync } from "@/lib/use-async";
import { AuditList } from "@/components/admin/AdminBits";
import { ErrorNote, Skeleton } from "@/components/ui/primitives";

export default function AdminAuditPage() {
  const { token } = useAuth();
  const { data, error } = useAsync(() => api.adminAudit(token!), [token]);
  return (
    <div className="max-w-3xl">
      <p className="mb-4 text-sm text-muted-foreground">Every change made in the admin area, newest first.</p>
      <ErrorNote message={error} />
      {data ? <AuditList actions={data.actions} /> : <Skeleton className="h-64" />}
    </div>
  );
}
