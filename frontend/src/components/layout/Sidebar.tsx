"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState, type ReactNode } from "react";
import { useAuth } from "@/lib/auth-context";
import { useConnectionState } from "@/lib/realtime";
import { SymbolSearch } from "./SymbolSearch";
import { BrandMark } from "./BrandMark";

function Icon({ children }: { children: ReactNode }) {
  return (
    <svg aria-hidden width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round">
      {children}
    </svg>
  );
}

const MAIN_LINKS = [
  { href: "/", label: "Home", icon: <path d="M3.5 10.5L12 3.5l8.5 7V20.5h-5.5v-6h-6v6H3.5z" /> },
  {
    href: "/markets",
    label: "Markets",
    icon: (
      <>
        <circle cx="12" cy="12" r="8.5" />
        <path d="M3.5 12h17M12 3.5c2.5 2.6 2.5 14.4 0 17M12 3.5c-2.5 2.6-2.5 14.4 0 17" />
      </>
    ),
  },
  { href: "/watchlist", label: "Watchlist", icon: <path d="M12 3.5l2.6 5.3 5.9.9-4.25 4.1 1 5.8L12 16.9l-5.25 2.7 1-5.8L3.5 9.7l5.9-.9z" /> },
  {
    href: "/profile",
    label: "Investor profile",
    icon: (
      <>
        <circle cx="12" cy="8" r="4" />
        <path d="M4.5 20c1.4-3.6 4.2-5.5 7.5-5.5s6.1 1.9 7.5 5.5" />
      </>
    ),
  },
  {
    href: "/settings",
    label: "Settings",
    icon: (
      <>
        <circle cx="12" cy="12" r="3" />
        <path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z" />
      </>
    ),
  },
];

const STRATEGY_LINKS = [
  { href: "/selector", label: "Selector", step: 1 },
  { href: "/optimizer", label: "Optimizer", step: 2 },
  { href: "/adviser", label: "Adviser", step: 3 },
];

function isActive(pathname: string, href: string) {
  return href === "/" ? pathname === "/" : pathname === href || pathname.startsWith(`${href}/`);
}

/** Desktop: a fixed left sidebar. Below `lg`: a top bar whose menu opens the same links. */
/** Pages that bring their own full-width chrome instead of the app sidebar. */
export function useStandalonePage(): boolean {
  const pathname = usePathname();
  const { user, isLoading } = useAuth();
  // The admin console has its own chrome; investors never see it in their app.
  if (pathname === "/admin" || pathname.startsWith("/admin/")) return true;
  return pathname === "/" && !isLoading && !user;
}

export function Sidebar() {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);
  const standalone = useStandalonePage();
  if (standalone) return null;

  return (
    <>
      <header className="sticky top-0 z-50 flex h-14 items-center justify-between border-b border-border bg-surface/95 px-4 backdrop-blur lg:hidden">
        <Link href="/" className="flex items-center gap-2.5">
          <BrandMark size={28} />
          <span className="text-[17px] font-bold">Stockiser</span>
        </Link>
        <button onClick={() => setOpen((v) => !v)} aria-label={open ? "Close menu" : "Open menu"} aria-expanded={open} className="flex h-11 w-11 items-center justify-center rounded-full">
          <Icon>{open ? <path d="M6 6l12 12M18 6L6 18" /> : <path d="M4 7h16M4 12h16M4 17h16" />}</Icon>
        </button>
      </header>
      {open && (
        <div className="fixed inset-x-0 bottom-0 top-14 z-40 overflow-y-auto bg-sidebar lg:hidden" onClick={() => setOpen(false)}>
          <SidebarBody pathname={pathname} />
        </div>
      )}
      <aside className="sticky top-0 hidden h-screen w-64 shrink-0 flex-col border-r border-border bg-sidebar lg:flex">
        <Link href="/" className="flex items-center gap-2.5 px-6 pb-2 pt-7">
          <BrandMark size={28} />
          <span className="text-[17px] font-bold">Stockiser</span>
        </Link>
        <SidebarBody pathname={pathname} />
      </aside>
    </>
  );
}

function SidebarBody({ pathname }: { pathname: string }) {
  const { user, logout, isLoading } = useAuth();
  const connection = useConnectionState();
  const linkClass = (active: boolean) =>
    `flex min-h-10 items-center gap-2.5 rounded-xl px-2.5 text-sm font-bold transition-colors ${
      active ? "bg-surface text-foreground shadow-[0_0_0_1px_var(--border)]" : "text-muted-foreground hover:text-foreground"
    }`;

  return (
    <div className="flex flex-1 flex-col gap-7 px-4 py-5">
      <div onClick={(e) => e.stopPropagation()}>
        <SymbolSearch />
      </div>

      <nav aria-label="Main" className="flex flex-col gap-0.5">
        {MAIN_LINKS.map((l) => (
          <Link key={l.href} href={l.href} aria-current={isActive(pathname, l.href) ? "page" : undefined} className={linkClass(isActive(pathname, l.href))}>
            <Icon>{l.icon}</Icon>
            {l.label}
          </Link>
        ))}
      </nav>

      <nav aria-label="Strategy" className="flex flex-col gap-0.5">
        <span className="label-caps px-2.5 pb-1.5">Strategy</span>
        {STRATEGY_LINKS.map((l) => (
          <Link key={l.href} href={l.href} aria-current={isActive(pathname, l.href) ? "page" : undefined} className={linkClass(isActive(pathname, l.href))}>
            <span className="tabular w-[18px] text-center text-xs">{l.step}</span>
            {l.label}
          </Link>
        ))}
      </nav>

      <div className="mt-auto flex flex-col gap-3 border-t border-border pt-4">
        <span className="flex items-center gap-2 px-2.5 text-xs font-bold text-muted-foreground">
          <span className={`h-2 w-2 rounded-full ${connection === "open" ? "bg-gain" : connection === "connecting" ? "bg-hold" : "bg-border"}`} />
          {connection === "open" ? "Live data" : connection === "connecting" ? "Connecting…" : "Live data offline"}
        </span>
        {isLoading ? null : user ? (
          <div className="flex items-center gap-2.5 px-1">
            <Link href="/profile" className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-border text-sm font-bold" aria-label="Investor profile">
              {user.first_name[0]?.toUpperCase()}
            </Link>
            <div className="min-w-0 flex-1">
              <p className="truncate text-sm font-bold">{user.first_name}</p>
              <p className="truncate text-xs text-muted-foreground">{user.email}</p>
            </div>
            <button onClick={logout} className="text-xs font-bold text-muted-foreground hover:text-foreground">
              Log out
            </button>
          </div>
        ) : (
          <div className="flex gap-2">
            <Link href="/login" className="btn-secondary flex-1">
              Log in
            </Link>
            <Link href="/register" className="btn-primary flex-1">
              Sign up
            </Link>
          </div>
        )}
      </div>
    </div>
  );
}
