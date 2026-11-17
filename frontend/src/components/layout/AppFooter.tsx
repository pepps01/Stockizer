"use client";

import { useStandalonePage } from "./Sidebar";

export function AppFooter() {
  if (useStandalonePage()) return null;
  return (
    <footer className="border-t border-border px-6 py-6 text-center text-xs text-muted-foreground">
      Stockiser recommends; it never places trades. Prices marked “Simulated” are model-generated. Not investment advice.
    </footer>
  );
}
