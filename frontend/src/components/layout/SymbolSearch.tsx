"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { api } from "@/lib/api";
import type { TickerInfo } from "@/lib/types";
import { symbolHref } from "@/lib/format";
import { Flag } from "@/components/ui/Flag";
import { SourceBadge } from "@/components/ui/Badges";

export function SymbolSearch() {
  const router = useRouter();
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<TickerInfo[]>([]);
  const [open, setOpen] = useState(false);
  const [active, setActive] = useState(0);
  const box = useRef<HTMLDivElement>(null);

  const visible = query.trim() ? results : [];

  useEffect(() => {
    const text = query.trim();
    if (!text) return;
    const timer = setTimeout(() => {
      api.search(text).then(({ results }) => {
        setResults(results);
        setActive(0);
      }).catch(() => setResults([]));
    }, 180);
    return () => clearTimeout(timer);
  }, [query]);

  useEffect(() => {
    const onClick = (e: MouseEvent) => box.current && !box.current.contains(e.target as Node) && setOpen(false);
    const onKey = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "k") {
        e.preventDefault();
        box.current?.querySelector("input")?.focus();
      }
    };
    document.addEventListener("mousedown", onClick);
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("mousedown", onClick);
      document.removeEventListener("keydown", onKey);
    };
  }, []);

  const go = (t: TickerInfo) => {
    setOpen(false);
    setQuery("");
    router.push(symbolHref(t.symbol));
  };

  return (
    <div ref={box} className="relative w-full">
      <input
        className="input rounded-full bg-surface-muted pl-9"
        placeholder="Search symbol or company (Ctrl+K)"
        value={query}
        onFocus={() => setOpen(true)}
        onChange={(e) => {
          setQuery(e.target.value);
          setOpen(true);
        }}
        onKeyDown={(e) => {
          if (e.key === "ArrowDown") setActive((a) => Math.min(a + 1, visible.length - 1));
          if (e.key === "ArrowUp") setActive((a) => Math.max(a - 1, 0));
          if (e.key === "Enter" && visible[active]) go(visible[active]);
          if (e.key === "Escape") setOpen(false);
        }}
        aria-label="Search symbols"
      />
      <svg className="pointer-events-none absolute left-3 top-3.5 h-4 w-4 text-muted-foreground" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
        <circle cx="11" cy="11" r="7" />
        <path d="m20 20-3.5-3.5" />
      </svg>
      {open && visible.length > 0 && (
        <ul className="absolute left-0 right-0 top-12 z-50 max-h-96 overflow-y-auto rounded-xl border border-border bg-surface py-1 shadow-xl sm:w-[26rem]">
          {visible.map((t, i) => (
            <li key={t.symbol}>
              <button
                onMouseEnter={() => setActive(i)}
                onClick={() => go(t)}
                className={`flex w-full items-center gap-3 px-3 py-2 text-left text-sm ${i === active ? "bg-surface-muted" : ""}`}
              >
                <Flag code={t.country_code} size={20} />
                <span className="w-24 shrink-0 font-semibold">{t.display_symbol}</span>
                <span className="min-w-0 flex-1 truncate text-muted-foreground">{t.name}</span>
                <SourceBadge source={t.data_source} />
                <span className="text-[11px] text-muted-foreground">{t.kind === "index" ? "Index" : t.exchange}</span>
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
