"use client";

import Link from "next/link";
import { useState } from "react";
import { useAuth } from "@/lib/auth-context";

const NAV_LINKS = [
  { href: "/markets", label: "Markets" },
  { href: "/financials", label: "Financials" },
  { href: "/selector", label: "Selector" },
];

export function Navbar() {
  const { user, logout, isLoading } = useAuth();
  const [menuOpen, setMenuOpen] = useState(false);

  return (
    <header className="sticky top-0 z-50 border-b border-border bg-surface">
      <div className="mx-auto flex h-16 max-w-7xl items-center justify-between gap-4 px-4 sm:px-6">
        <div className="flex items-center gap-8">
          <Link href="/" className="flex items-center gap-2 font-semibold text-lg shrink-0">
            <span className="flex h-7 w-7 items-center justify-center rounded bg-brand text-brand-foreground text-sm font-bold">
              T
            </span>
            Tickizer
          </Link>
          <nav className="hidden md:flex items-center gap-6 text-sm text-muted-foreground">
            {NAV_LINKS.map((link) => (
              <Link key={link.href} href={link.href} className="hover:text-foreground transition-colors">
                {link.label}
              </Link>
            ))}
          </nav>
        </div>

        <div className="hidden md:flex items-center gap-3">
          {isLoading ? null : user ? (
            <>
              <Link
                href="/profile"
                className="flex h-8 w-8 items-center justify-center rounded-full bg-surface-muted text-sm font-medium border border-border"
              >
                {user.first_name[0]?.toUpperCase()}
              </Link>
              <button
                onClick={logout}
                className="text-sm text-muted-foreground hover:text-foreground transition-colors"
              >
                Log out
              </button>
            </>
          ) : (
            <>
              <Link href="/login" className="text-sm text-muted-foreground hover:text-foreground transition-colors">
                Log in
              </Link>
              <Link
                href="/register"
                className="rounded-full bg-brand px-4 py-1.5 text-sm font-medium text-brand-foreground hover:opacity-90 transition-opacity"
              >
                Sign up
              </Link>
            </>
          )}
        </div>

        <button
          className="md:hidden flex h-9 w-9 items-center justify-center rounded border border-border"
          onClick={() => setMenuOpen((v) => !v)}
          aria-label="Toggle menu"
        >
          <span className="sr-only">Menu</span>
          <div className="flex flex-col gap-1">
            <span className="h-0.5 w-4 bg-foreground" />
            <span className="h-0.5 w-4 bg-foreground" />
            <span className="h-0.5 w-4 bg-foreground" />
          </div>
        </button>
      </div>

      {menuOpen && (
        <div className="md:hidden border-t border-border px-4 py-4 flex flex-col gap-4">
          {NAV_LINKS.map((link) => (
            <Link key={link.href} href={link.href} className="text-sm" onClick={() => setMenuOpen(false)}>
              {link.label}
            </Link>
          ))}
          <div className="h-px bg-border" />
          {user ? (
            <>
              <Link href="/profile" className="text-sm" onClick={() => setMenuOpen(false)}>
                Profile ({user.first_name})
              </Link>
              <button onClick={logout} className="text-sm text-left text-muted-foreground">
                Log out
              </button>
            </>
          ) : (
            <>
              <Link href="/login" className="text-sm" onClick={() => setMenuOpen(false)}>
                Log in
              </Link>
              <Link href="/register" className="text-sm font-medium text-brand" onClick={() => setMenuOpen(false)}>
                Sign up
              </Link>
            </>
          )}
        </div>
      )}
    </header>
  );
}
