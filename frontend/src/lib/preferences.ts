"use client";

import { useSyncExternalStore } from "react";
import type { MarketRow, Quote } from "./types";

/** Small per-browser display preferences (Settings → Watchlist). Like the theme,
 * they are conveniences kept in this browser, not account data. */
const EVENT = "stockiser-pref-change";

export type WatchlistSort = "added" | "name" | "change";

export const PREFS = {
  watchlistSort: { key: "stockiser-watchlist-sort", fallback: "added" as WatchlistSort, values: ["added", "name", "change"] as WatchlistSort[] },
  homeWatchlist: { key: "stockiser-home-watchlist", fallback: "show" as "show" | "hide", values: ["show", "hide"] as ("show" | "hide")[] },
};

type Pref<T extends string> = { key: string; fallback: T; values: T[] };

function read<T extends string>(pref: Pref<T>): T {
  try {
    const value = localStorage.getItem(pref.key) as T | null;
    return value && pref.values.includes(value) ? value : pref.fallback;
  } catch {
    return pref.fallback;
  }
}

function subscribe(onChange: () => void) {
  window.addEventListener(EVENT, onChange);
  window.addEventListener("storage", onChange);
  return () => {
    window.removeEventListener(EVENT, onChange);
    window.removeEventListener("storage", onChange);
  };
}

export function useBrowserPref<T extends string>(pref: Pref<T>): T {
  return useSyncExternalStore(subscribe, () => read(pref), () => pref.fallback);
}

export function setBrowserPref<T extends string>(pref: Pref<T>, value: T) {
  try {
    localStorage.setItem(pref.key, value);
  } catch {
    // Storage blocked: the change lasts for this page view only.
  }
  window.dispatchEvent(new Event(EVENT));
}

/** Watchlist rows in the chosen order. The API returns them oldest first. */
export function sortWatchlist(rows: MarketRow[], sort: WatchlistSort, live: Record<string, Quote> = {}): MarketRow[] {
  if (sort === "name") return [...rows].sort((a, b) => a.display_symbol.localeCompare(b.display_symbol));
  if (sort === "change") {
    const pct = (r: MarketRow) => (live[r.symbol] ?? r.quote)?.change_percent ?? -Infinity;
    return [...rows].sort((a, b) => pct(b) - pct(a));
  }
  return [...rows].reverse();
}
