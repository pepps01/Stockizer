"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";
import { useAuth } from "@/lib/auth-context";
import { useConnectionState } from "@/lib/realtime";
import { SymbolSearch } from "./SymbolSearch";
import { BrandMark } from "./BrandMark";

const NAV_LINKS = [
  { href: "/markets", label: "Markets" },
  { href: "/selector", label: "Selector" },
  { href: "/optimizer", label: "Optimizer" },
  { href: "/adviser", label: "Adviser" },
  { href: "/watchlist", label: "Watchlist" },
];

export function Navbar() {
  const { user, logout, isLoading } = useAuth();
  const pathname = usePathname();
  const connection = useConnectionState();
  const [menuOpen, setMenuOpen] = useState(false);

  return (
    <header className="sticky top-0 z-50 border-b border-border bg-surface/95 backdrop-blur">
      <div className="mx-auto flex h-16 max-w-7xl items-center gap-4 px-4 sm:px-6">
        <Link href="/" className="flex shrink-0 items-center gap-2.5">
          <BrandMark size={34} />
          <span className="text-lg font-bold tracking-tight">Algizer</span>
        </Link>

        <div className="hidden flex-1 md:flex">
          <SymbolSearch />
        </div>

        <nav className="hidden items-center gap-1 text-sm lg:flex">
          {NAV_LINKS.map((link) => {
            const active = pathname === link.href || pathname.startsWith(`${link.href}/`);
            return (
              <Link
                key={link.href}
                href={link.href}
                className={`rounded-full px-3 py-1.5 transition-colors ${active ? "bg-brand-soft font-medium text-brand" : "text-muted-foreground hover:text-foreground"}`}
              >
                {link.label}
              </Link>
            );
          })}
        </nav>

        <span
          title={connection === "open" ? "Live data connected" : connection === "connecting" ? "Connecting to live data…" : "Live data offline"}
          className={`hidden h-2 w-2 shrink-0 rounded-full sm:block ${connection === "open" ? "bg-gain" : connection === "connecting" ? "bg-hold" : "bg-muted-foreground/40"}`}
        />

        <div className="ml-auto hidden items-center gap-3 lg:ml-0 lg:flex">
          {isLoading ? null : user ? (
            <>
              <Link href="/profile" className="flex h-9 w-9 items-center justify-center rounded-full border border-border bg-surface-muted text-sm font-semibold" title="Profile">
                {user.first_name[0]?.toUpperCase()}
              </Link>
              <button onClick={logout} className="text-sm text-muted-foreground hover:text-foreground">
                Log out
              </button>
            </>
          ) : (
            <>
              <Link href="/login" className="text-sm text-muted-foreground hover:text-foreground">
                Log in
              </Link>
              <Link href="/register" className="btn-primary rounded-full py-1.5">
                Get started
              </Link>
            </>
          )}
        </div>

        <button className="ml-auto flex h-9 w-9 items-center justify-center rounded-lg border border-border lg:hidden" onClick={() => setMenuOpen((v) => !v)} aria-label="Toggle menu">
          <span className="flex flex-col gap-1">
            <span className="h-0.5 w-4 bg-foreground" />
            <span className="h-0.5 w-4 bg-foreground" />
            <span className="h-0.5 w-4 bg-foreground" />
          </span>
        </button>
      </div>

      {menuOpen && (
        <div className="flex flex-col gap-3 border-t border-border px-4 py-4 lg:hidden" onClick={() => setMenuOpen(false)}>
          <div className="md:hidden" onClick={(e) => e.stopPropagation()}>
            <SymbolSearch />
          </div>
          {NAV_LINKS.map((link) => (
            <Link key={link.href} href={link.href} className="text-sm">
              {link.label}
            </Link>
          ))}
          <div className="h-px bg-border" />
          {user ? (
            <>
              <Link href="/profile" className="text-sm">
                Profile ({user.first_name})
              </Link>
              <button onClick={logout} className="text-left text-sm text-muted-foreground">
                Log out
              </button>
            </>
          ) : (
            <>
              <Link href="/login" className="text-sm">
                Log in
              </Link>
              <Link href="/register" className="text-sm font-medium text-brand">
                Get started
              </Link>
            </>
          )}
        </div>
      )}
    </header>
  );
}
