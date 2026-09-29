"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth-context";
import { api } from "@/lib/api";
import type { UserActionType } from "@/lib/types";

const ACTIONS: { type: UserActionType; label: string }[] = [
  { type: "view", label: "View" },
  { type: "hold", label: "Hold" },
  { type: "buy", label: "Buy" },
  { type: "sell", label: "Sell" },
];

const ACTION_STYLES: Record<UserActionType, string> = {
  view: "border-border text-foreground hover:bg-surface-muted",
  hold: "border-border text-foreground hover:bg-surface-muted",
  buy: "border-gain text-gain hover:bg-gain/10",
  sell: "border-loss text-loss hover:bg-loss/10",
};

export function ActionButtons({ symbol }: { symbol: string }) {
  const router = useRouter();
  const { token } = useAuth();
  const [pending, setPending] = useState<UserActionType | null>(null);
  const [confirmed, setConfirmed] = useState<UserActionType | null>(null);

  const handleClick = async (action: UserActionType) => {
    if (!token) {
      router.push("/login");
      return;
    }
    setPending(action);
    try {
      await api.recordSelectorAction(token, { symbol, action });
      setConfirmed(action);
      setTimeout(() => setConfirmed(null), 2000);
    } finally {
      setPending(null);
    }
  };

  return (
    <div className="flex flex-wrap gap-2">
      {ACTIONS.map(({ type, label }) => (
        <button
          key={type}
          onClick={() => handleClick(type)}
          disabled={pending === type}
          className={`rounded-lg border px-3 py-1.5 text-sm font-medium transition-colors disabled:opacity-50 ${ACTION_STYLES[type]}`}
        >
          {confirmed === type ? "Saved" : label}
        </button>
      ))}
    </div>
  );
}
