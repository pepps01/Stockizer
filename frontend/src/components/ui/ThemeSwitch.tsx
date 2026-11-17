"use client";

import { setThemePreference, useThemePreference, type ThemePreference } from "@/lib/theme";

const OPTIONS: { value: ThemePreference; label: string; icon: React.ReactNode }[] = [
  { value: "light", label: "Light", icon: <path d="M12 4V2M12 22v-2M4 12H2M22 12h-2M5.6 5.6 4.2 4.2M19.8 19.8l-1.4-1.4M5.6 18.4l-1.4 1.4M19.8 4.2l-1.4 1.4M12 16a4 4 0 1 0 0-8 4 4 0 0 0 0 8z" /> },
  { value: "dark", label: "Dark", icon: <path d="M20 14.5A8 8 0 0 1 9.5 4 8 8 0 1 0 20 14.5z" /> },
  { value: "system", label: "System", icon: <path d="M3 5h18v11H3zM8 20h8M12 16v4" /> },
];

/** Light · Dark · System, applied instantly and remembered in this browser. */
export function ThemeSwitch() {
  const current = useThemePreference();
  return (
    <div role="radiogroup" aria-label="Appearance" className="inline-flex gap-1 rounded-full bg-surface-muted p-1">
      {OPTIONS.map((o) => {
        const active = current === o.value;
        return (
          <button
            key={o.value}
            type="button"
            role="radio"
            aria-checked={active}
            onClick={() => setThemePreference(o.value)}
            className={`flex min-h-9 items-center gap-2 rounded-full px-4 text-sm font-bold transition-colors ${
              active ? "bg-ink text-ink-foreground" : "text-muted-foreground hover:text-foreground"
            }`}
          >
            <svg viewBox="0 0 24 24" className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth={1.9} strokeLinecap="round" strokeLinejoin="round" aria-hidden>
              {o.icon}
            </svg>
            {o.label}
          </button>
        );
      })}
    </div>
  );
}
