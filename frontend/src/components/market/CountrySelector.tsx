"use client";

import { useEffect, useMemo, useState } from "react";
import { api } from "@/lib/api";
import type { Country } from "@/lib/types";
import { Flag, GlobeIcon } from "@/components/ui/Flag";

const REGION_ORDER = ["North America", "Europe", "Asia", "Pacific", "Middle East / Africa", "Mexico and South America"];

/** TradingView-style "Select country" dialog: search, Entire world, countries grouped by region. */
export function CountrySelector({ value, onChange }: { value: string | null; onChange: (code: string | null) => void }) {
  const [open, setOpen] = useState(false);
  const [countries, setCountries] = useState<Country[]>([]);
  const [query, setQuery] = useState("");

  useEffect(() => {
    api.countries().then(({ countries }) => setCountries(countries)).catch(() => undefined);
  }, []);

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && setOpen(false);
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open]);

  const grouped = useMemo(() => {
    const q = query.trim().toLowerCase();
    const matches = countries.filter((c) => !q || c.name.toLowerCase().includes(q) || c.code.toLowerCase() === q);
    return REGION_ORDER.map((region) => ({ region, items: matches.filter((c) => c.region === region) })).filter((g) => g.items.length);
  }, [countries, query]);

  const selected = countries.find((c) => c.code === value);
  const choose = (code: string | null) => {
    onChange(code);
    setOpen(false);
    setQuery("");
  };

  return (
    <>
      <button onClick={() => setOpen(true)} className="btn-secondary rounded-full" aria-haspopup="dialog">
        {selected ? <Flag code={selected.code} size={18} /> : <GlobeIcon size={18} />}
        <span>{selected ? selected.name : "Entire world"}</span>
        <span aria-hidden className="text-muted-foreground">▾</span>
      </button>

      {open && (
        <div className="fixed inset-0 z-[60] flex items-start justify-center bg-black/40 p-4 sm:pt-16" onClick={() => setOpen(false)}>
          <div
            role="dialog"
            aria-label="Select country"
            className="flex max-h-[85vh] w-full max-w-3xl flex-col overflow-hidden rounded-2xl bg-surface shadow-2xl"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between border-b border-border px-6 py-4">
              <h2 className="text-xl font-semibold">Select country</h2>
              <button onClick={() => setOpen(false)} aria-label="Close" className="text-2xl leading-none text-muted-foreground hover:text-foreground">
                ×
              </button>
            </div>
            <div className="border-b border-border px-6 py-3">
              <input autoFocus className="input" placeholder="Search" value={query} onChange={(e) => setQuery(e.target.value)} />
            </div>
            <div className="overflow-y-auto px-4 pb-6">
              {!query && (
                <button
                  onClick={() => choose(null)}
                  className={`mt-4 flex w-full items-center gap-3 rounded-xl px-4 py-3 text-left sm:w-1/2 ${value === null ? "bg-foreground text-background" : "hover:bg-surface-muted"}`}
                >
                  <GlobeIcon size={26} /> <span className="text-base">Entire world</span>
                </button>
              )}
              {grouped.map(({ region, items }) => (
                <div key={region} className="mt-5">
                  <h3 className="px-2 text-xs font-semibold uppercase tracking-wider text-muted-foreground">{region}</h3>
                  <div className="mt-2 grid grid-cols-1 sm:grid-cols-2">
                    {items.map((c) => (
                      <button
                        key={c.code}
                        onClick={() => choose(c.code)}
                        className={`flex items-center gap-3 rounded-xl px-3 py-2.5 text-left ${value === c.code ? "bg-brand-soft" : "hover:bg-surface-muted"}`}
                      >
                        <Flag code={c.code} size={28} />
                        <span className="text-[15px]">{c.name}</span>
                        {c.exchange_count > 1 && <span className="text-xs text-muted-foreground">{c.exchange_count} exchanges</span>}
                      </button>
                    ))}
                  </div>
                </div>
              ))}
              {!grouped.length && <p className="px-2 pt-6 text-sm text-muted-foreground">No covered market matches “{query}”.</p>}
            </div>
          </div>
        </div>
      )}
    </>
  );
}
