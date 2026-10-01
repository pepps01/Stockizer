"use client";

import Link from "next/link";
import { useCallback, useState } from "react";
import type { SignalEvent } from "@/lib/types";
import { useAuth } from "@/lib/auth-context";
import { useSignalListener } from "@/lib/realtime";
import { formatPrice, symbolHref } from "@/lib/format";
import { SignalBadge } from "@/components/ui/Badges";

const TOAST_MS = 9000;
const BORDER: Record<SignalEvent["signal_type"], string> = { BUY: "border-l-gain", SELL: "border-l-loss", HOLD: "border-l-hold" };

/** Pops a colour-coded toast (and a browser notification, if allowed) for every new Adviser signal. */
export function SignalToaster() {
  const { user } = useAuth();
  const [toasts, setToasts] = useState<SignalEvent[]>([]);

  const onSignal = useCallback((signal: SignalEvent) => {
    setToasts((current) => [signal, ...current.filter((t) => t.id !== signal.id)].slice(0, 4));
    setTimeout(() => setToasts((current) => current.filter((t) => t.id !== signal.id)), TOAST_MS);
    if (typeof Notification !== "undefined" && Notification.permission === "granted" && document.visibilityState !== "visible") {
      new Notification(`${signal.signal_type} · ${signal.display_symbol}`, { body: signal.reason, tag: signal.id });
    }
  }, []);

  useSignalListener(onSignal, Boolean(user));

  if (!toasts.length) return null;
  return (
    <div className="pointer-events-none fixed bottom-4 right-4 z-[70] flex w-[min(24rem,calc(100vw-2rem))] flex-col gap-2">
      {toasts.map((t) => (
        <div key={t.id} className={`pointer-events-auto card border-l-4 p-4 shadow-xl ${BORDER[t.signal_type]}`}>
          <div className="flex items-center justify-between gap-3">
            <Link href={symbolHref(t.symbol)} className="font-semibold hover:text-brand">
              {t.display_symbol} <span className="font-normal text-muted-foreground">· {t.name}</span>
            </Link>
            <SignalBadge type={t.signal_type} size="sm" />
          </div>
          <p className="mt-1 text-sm">
            {formatPrice(t.price, t.currency)} · {(t.confidence * 100).toFixed(0)}% confidence
          </p>
          <p className="mt-1 line-clamp-2 text-xs text-muted-foreground">{t.reason}</p>
        </div>
      ))}
    </div>
  );
}
