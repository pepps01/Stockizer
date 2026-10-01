"use client";

import { useEffect, useState } from "react";
import { api } from "@/lib/api";
import type { Exchange } from "@/lib/types";

const REGION_ORDER = ["North America", "Europe", "Asia", "Pacific", "Middle East / Africa", "Mexico and South America"];

export function ExchangePicker({ value, onChange }: { value: string; onChange: (code: string) => void }) {
  const [exchanges, setExchanges] = useState<Exchange[]>([]);

  useEffect(() => {
    api.exchanges().then(({ exchanges }) => setExchanges(exchanges)).catch(() => undefined);
  }, []);

  return (
    <select className="input" value={value} onChange={(e) => onChange(e.target.value)} required>
      <option value="" disabled>
        Choose an exchange…
      </option>
      {REGION_ORDER.map((region) => (
        <optgroup key={region} label={region}>
          {exchanges
            .filter((e) => e.region === region)
            .map((e) => (
              <option key={e.code} value={e.code}>
                {e.country} — {e.name} ({e.code}){e.data_source === "synthetic" ? " · simulated" : ""}
              </option>
            ))}
        </optgroup>
      ))}
    </select>
  );
}
