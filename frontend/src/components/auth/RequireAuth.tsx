"use client";

import Link from "next/link";
import type { ReactNode } from "react";
import { useAuth } from "@/lib/auth-context";
import { PageShell, Skeleton } from "@/components/ui/primitives";

/** Renders children with a guaranteed token, or a sign-in prompt. */
export function RequireAuth({ children, feature }: { children: (token: string) => ReactNode; feature: string }) {
  const { token, isLoading } = useAuth();
  if (isLoading) {
    return (
      <PageShell>
        <Skeleton className="h-40" />
      </PageShell>
    );
  }
  if (!token) {
    return (
      <PageShell width="max-w-lg">
        <div className="card p-8 text-center">
          <h1 className="text-xl font-semibold">Sign in to use the {feature}</h1>
          <p className="mt-2 text-sm text-muted-foreground">Runs, parameters and signals are saved to your account.</p>
          <div className="mt-6 flex justify-center gap-3">
            <Link href="/login" className="btn-primary">
              Log in
            </Link>
            <Link href="/register" className="btn-secondary">
              Create account
            </Link>
          </div>
        </div>
      </PageShell>
    );
  }
  return <>{children(token)}</>;
}
