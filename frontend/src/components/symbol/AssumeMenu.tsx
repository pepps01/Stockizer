"use client";

import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import type { Stance } from "@/lib/types";

const OPTIONS: { value: Stance; label: string; dot: string; text: string }[] = [
  { value: "buy", label: "Assume buy", dot: "bg-gain", text: "text-gain" },
  { value: "hold", label: "Assume hold", dot: "bg-hold", text: "text-hold" },
  { value: "sell", label: "Assume sell", dot: "bg-loss", text: "text-loss" },
];

export const STANCE_STYLE: Record<Stance, { label: string; pill: string }> = {
  buy: { label: "Buy", pill: "bg-gain-soft text-gain" },
  hold: { label: "Hold", pill: "bg-hold-soft text-hold" },
  sell: { label: "Sell", pill: "bg-loss-soft text-loss" },
};

/** Icon button with a dropdown: assume buy, hold or sell on a ticker (or clear it).
 * Shows the current call when one is set. Guests are asked to log in. */
export function AssumeMenu({
  symbol,
  stance,
  signedIn,
  onChange,
  watching,
  onToggleWatch,
}: {
  symbol: string;
  stance: Stance | null;
  signedIn: boolean;
  onChange: (stance: Stance | null) => void;
  /** When given, the menu also adds the ticker to (or removes it from) the watchlist. */
  watching?: boolean;
  onToggleWatch?: () => void;
}) {
  const [open, setOpen] = useState(false);
  const root = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    const onDown = (e: MouseEvent) => {
      if (!root.current?.contains(e.target as Node)) setOpen(false);
    };
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        e.stopPropagation();
        setOpen(false);
      }
    };
    document.addEventListener("mousedown", onDown);
    document.addEventListener("keydown", onKey, true);
    return () => {
      document.removeEventListener("mousedown", onDown);
      document.removeEventListener("keydown", onKey, true);
    };
  }, [open]);

  const choose = (value: Stance | null) => {
    setOpen(false);
    onChange(value);
  };

  const current = stance ? STANCE_STYLE[stance] : null;
  return (
    <div ref={root} className="relative shrink-0">
      <button
        type="button"
        aria-haspopup="menu"
        aria-expanded={open}
        aria-label={`Actions for ${symbol}${current ? `, assumed ${current.label}` : ""}${watching ? ", on your watchlist" : ""}`}
        onClick={() => setOpen((v) => !v)}
        className={`flex h-8 items-center gap-1.5 rounded-lg border px-2 text-xs font-bold transition-colors ${
          current ? `border-transparent ${current.pill}` : "border-border text-muted-foreground hover:border-foreground/30 hover:text-foreground"
        }`}
      >
        {watching && (
          <svg viewBox="0 0 24 24" className="h-3.5 w-3.5 text-hold" fill="currentColor" aria-hidden>
            <path d="M12 3.5l2.6 5.3 5.9.9-4.25 4.1 1 5.8L12 16.9l-5.25 2.7 1-5.8L3.5 9.7l5.9-.9z" />
          </svg>
        )}
        <svg viewBox="0 0 24 24" className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" aria-hidden>
          <circle cx="12" cy="12" r="8" />
          <circle cx="12" cy="12" r="3" />
          <path d="M12 2v3M12 19v3M2 12h3M19 12h3" />
        </svg>
        {current ? current.label : "Assume"}
        <svg viewBox="0 0 24 24" className={`h-3.5 w-3.5 transition-transform ${open ? "rotate-180" : ""}`} fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" aria-hidden>
          <path d="M6 9l6 6 6-6" />
        </svg>
      </button>

      {open && (
        <div role="menu" aria-label={`Actions for ${symbol}`} className="absolute right-0 top-9 z-30 w-52 overflow-hidden rounded-xl border border-border bg-surface py-1 shadow-[0_18px_40px_-18px_rgba(16,20,24,0.45)]">
          {signedIn ? (
            <>
              {OPTIONS.map((o) => (
                <button
                  key={o.value}
                  type="button"
                  role="menuitemradio"
                  aria-checked={stance === o.value}
                  onClick={() => choose(o.value)}
                  className="flex w-full items-center gap-2.5 px-3 py-2 text-left text-sm font-bold hover:bg-surface-muted"
                >
                  <span className={`h-2 w-2 rounded-full ${o.dot}`} aria-hidden />
                  <span className={stance === o.value ? o.text : ""}>{o.label}</span>
                  {stance === o.value && (
                    <svg viewBox="0 0 24 24" className="ml-auto h-4 w-4" fill="none" stroke="currentColor" strokeWidth={2.2} strokeLinecap="round" aria-hidden>
                      <path d="M5 12l5 5L20 7" />
                    </svg>
                  )}
                </button>
              ))}
              {stance && (
                <button
                  type="button"
                  role="menuitem"
                  onClick={() => choose(null)}
                  className="flex w-full items-center gap-2.5 px-3 py-2 text-left text-sm text-muted-foreground hover:bg-surface-muted"
                >
                  Clear assumption
                </button>
              )}
              {onToggleWatch && (
                <button
                  type="button"
                  role="menuitem"
                  onClick={() => {
                    setOpen(false);
                    onToggleWatch();
                  }}
                  className="mt-1 flex w-full items-center gap-2.5 border-t border-border px-3 py-2.5 text-left text-sm font-bold hover:bg-surface-muted"
                >
                  <svg viewBox="0 0 24 24" className={`h-4 w-4 ${watching ? "text-hold" : "text-muted-foreground"}`} fill={watching ? "currentColor" : "none"} stroke="currentColor" strokeWidth={1.8} strokeLinejoin="round" aria-hidden>
                    <path d="M12 3.5l2.6 5.3 5.9.9-4.25 4.1 1 5.8L12 16.9l-5.25 2.7 1-5.8L3.5 9.7l5.9-.9z" />
                  </svg>
                  {watching ? "Remove from watchlist" : "Add to watchlist"}
                </button>
              )}
            </>
          ) : (
            <p className="px-3 py-2.5 text-sm text-muted-foreground">
              <Link href="/login" className="font-bold text-foreground underline underline-offset-4">
                Log in
              </Link>{" "}
              to save buy, hold or sell calls and your watchlist.
            </p>
          )}
        </div>
      )}
    </div>
  );
}
