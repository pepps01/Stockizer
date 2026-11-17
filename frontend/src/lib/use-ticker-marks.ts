"use client";

import { useState } from "react";
import { api } from "./api";
import { useAsync } from "./use-async";
import type { Stance } from "./types";

/** The signed-in investor's marks on tickers: their assumed buy / hold / sell
 * call and whether the ticker is on their watchlist. Changes apply instantly
 * and roll back if the server refuses them. One instance is shared by an
 * index's stock table and its Financials panel so both stay in step. */
export interface TickerMarks {
  signedIn: boolean;
  stanceOf: (symbol: string) => Stance | null;
  isWatching: (symbol: string) => boolean;
  assume: (symbol: string, stance: Stance | null) => void;
  toggleWatch: (symbol: string) => void;
  error: string | null;
}

export function useTickerMarks(token: string | null, enabled = true): TickerMarks {
  const load = enabled && token;
  const saved = useAsync(() => (load ? api.assumptions(token) : Promise.resolve(null)), [token, enabled]);
  const watch = useAsync(() => (load ? api.watchlist(token) : Promise.resolve(null)), [token, enabled]);
  const [stances, setStances] = useState<Record<string, Stance | null>>({});
  const [watching, setWatching] = useState<Record<string, boolean>>({});
  const [error, setError] = useState<string | null>(null);

  const stanceOf = (symbol: string): Stance | null =>
    symbol in stances ? stances[symbol] : (saved.data?.assumptions.find((a) => a.symbol === symbol)?.stance ?? null);
  const isWatching = (symbol: string): boolean =>
    symbol in watching ? watching[symbol] : Boolean(watch.data?.items.some((i) => i.symbol === symbol));

  const assume = async (symbol: string, stance: Stance | null) => {
    if (!token) return;
    const before = stanceOf(symbol);
    setStances((s) => ({ ...s, [symbol]: stance }));
    setError(null);
    try {
      if (stance) await api.setAssumption(token, symbol, stance);
      else await api.clearAssumption(token, symbol);
    } catch {
      setStances((s) => ({ ...s, [symbol]: before }));
      setError("Couldn't save that call. Check your connection and try again.");
    }
  };

  const toggleWatch = async (symbol: string) => {
    if (!token) return;
    const before = isWatching(symbol);
    setWatching((w) => ({ ...w, [symbol]: !before }));
    setError(null);
    try {
      if (before) await api.removeFromWatchlist(token, symbol);
      else await api.addToWatchlist(token, symbol);
    } catch {
      setWatching((w) => ({ ...w, [symbol]: before }));
      setError("Couldn't update your watchlist. Check your connection and try again.");
    }
  };

  return { signedIn: Boolean(token), stanceOf, isWatching, assume, toggleWatch, error };
}
