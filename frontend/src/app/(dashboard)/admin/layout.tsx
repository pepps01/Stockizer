"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import type { ReactNode } from "react";
import { useAuth } from "@/lib/auth-context";
import { BrandMark } from "@/components/layout/BrandMark";
import { PageHeader, PageShell, Skeleton } from "@/components/ui/primitives";

const TABS = [
  { href: "/admin", label: "Overview" },
  { href: "/admin/users", label: "Users" },
  { href: "/admin/sessions", label: "Sessions" },
  { href: "/admin/catalog", label: "Catalog" },
  { href: "/admin/audit", label: "Audit log" },
];

/** The admin console (web only). It is separate from the investor app: its own
 * top bar, no investor sidebar, and it is reached through /admin/login. The API
 * enforces admin rights on every call; this guard only routes people. */
export default function AdminLayout({ children }: { children: ReactNode }) {
  const { user, isLoading, logout } = useAuth();
  const pathname = usePathname();
  const router = useRouter();

  if (pathname === "/admin/login") return <>{children}</>;

  const signOut = () => {
    logout();
    router.replace("/admin/login");
  };

  return (
    <div className="flex min-h-screen flex-col bg-background">
      <header className="sticky top-0 z-40 border-b border-border bg-surface/95 backdrop-blur">
        <div className="mx-auto flex h-16 max-w-7xl items-center justify-between gap-4 px-4 sm:px-6">
          <Link href="/admin" className="flex items-center gap-3">
            <BrandMark size={30} />
            <span className="flex flex-col leading-tight">
              <span className="text-[15px] font-bold">Stockiser</span>
              <span className="label-caps !text-[10px]">Admin console</span>
            </span>
          </Link>
          <div className="flex items-center gap-2 text-sm">
            <Link href="/" className="hidden rounded-full px-3 py-2 font-bold text-muted-foreground hover:text-foreground sm:block">
              Open investor app ↗
            </Link>
            {user?.is_admin && (
              <>
                <span className="hidden max-w-48 truncate text-muted-foreground md:block">{user.email}</span>
                <button type="button" onClick={signOut} className="btn-secondary min-h-9 px-4">
                  Sign out
                </button>
              </>
            )}
          </div>
        </div>
      </header>

      {isLoading ? (
        <PageShell>
          <Skeleton className="h-40" />
        </PageShell>
      ) : !user?.is_admin ? (
        <PageShell width="max-w-lg">
          <div className="py-16">
            <h1 className="text-[28px] font-bold">Admins only</h1>
            <p className="mt-2 text-sm text-muted-foreground">
              {user ? "This account doesn't have access to the admin console." : "Sign in with an admin account to manage Stockiser."}
            </p>
            <Link href="/admin/login" className="btn-primary mt-6">
              Admin sign in
            </Link>
          </div>
        </PageShell>
      ) : (
        <PageShell>
          <PageHeader title="Admin" subtitle="Manage accounts, monitoring and the market catalog. Every change is recorded in the audit log." />
          <nav aria-label="Admin sections" className="-mt-2 mb-8 flex gap-1 overflow-x-auto border-b border-border">
            {TABS.map((t) => {
              const active = t.href === "/admin" ? pathname === "/admin" : pathname.startsWith(t.href);
              return (
                <Link
                  key={t.href}
                  href={t.href}
                  aria-current={active ? "page" : undefined}
                  className={`-mb-px whitespace-nowrap border-b-2 px-3 pb-3 text-sm font-bold transition-colors ${
                    active ? "border-foreground text-foreground" : "border-transparent text-muted-foreground hover:text-foreground"
                  }`}
                >
                  {t.label}
                </Link>
              );
            })}
          </nav>
          {children}
        </PageShell>
      )}
    </div>
  );
}
