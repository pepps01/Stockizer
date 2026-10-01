"use client";

import { useEffect, useMemo, useState, useSyncExternalStore } from "react";
import { API_BASE_URL } from "./api";
import type { Quote, SignalEvent } from "./types";

export type ConnectionState = "connecting" | "open" | "closed";
type QuoteListener = (quotes: Record<string, Quote>) => void;
type SignalListener = (signal: SignalEvent) => void;

const WS_URL = process.env.NEXT_PUBLIC_WS_URL ?? `${API_BASE_URL.replace(/^http/, "ws")}/ws`;

/**
 * One shared WebSocket to the backend gateway (/ws). Components subscribe to
 * symbols (reference-counted, so the same symbol on two widgets is sent once)
 * and listen for quote batches and Adviser signals. Reconnects with backoff and
 * re-subscribes everything after a reconnect.
 */
export class RealtimeClient {
  private socket: WebSocket | null = null;
  private token: string | null = null;
  private readonly subscriptions = new Map<string, number>();
  private readonly quoteListeners = new Set<QuoteListener>();
  private readonly signalListeners = new Set<SignalListener>();
  private readonly stateListeners = new Set<() => void>();
  private readonly latest = new Map<string, Quote>();
  private state: ConnectionState = "closed";
  private retryDelay = 1000;
  private retryTimer: ReturnType<typeof setTimeout> | null = null;
  private heartbeat: ReturnType<typeof setInterval> | null = null;

  constructor(private readonly url: string) {}

  getState = (): ConnectionState => this.state;

  subscribeState = (listener: () => void) => {
    this.stateListeners.add(listener);
    return () => this.stateListeners.delete(listener);
  };

  latestQuote(symbol: string): Quote | undefined {
    return this.latest.get(symbol);
  }

  setToken(token: string | null): void {
    if (token === this.token) return;
    this.token = token;
    if (this.socket) this.reconnectNow();
  }

  subscribe(symbols: string[]): () => void {
    const added: string[] = [];
    for (const raw of symbols) {
      const symbol = raw.toUpperCase();
      const count = this.subscriptions.get(symbol) ?? 0;
      this.subscriptions.set(symbol, count + 1);
      if (count === 0) added.push(symbol);
    }
    this.ensureConnected();
    if (added.length) this.send({ type: "subscribe", symbols: added });
    return () => {
      const removed: string[] = [];
      for (const raw of symbols) {
        const symbol = raw.toUpperCase();
        const count = (this.subscriptions.get(symbol) ?? 1) - 1;
        if (count <= 0) {
          this.subscriptions.delete(symbol);
          removed.push(symbol);
        } else this.subscriptions.set(symbol, count);
      }
      if (removed.length) this.send({ type: "unsubscribe", symbols: removed });
    };
  }

  onQuotes(listener: QuoteListener): () => void {
    this.quoteListeners.add(listener);
    return () => this.quoteListeners.delete(listener);
  }

  onSignal(listener: SignalListener): () => void {
    this.signalListeners.add(listener);
    this.ensureConnected();
    return () => this.signalListeners.delete(listener);
  }

  // ---- connection management ----

  private ensureConnected(): void {
    if (typeof window === "undefined" || this.socket) return;
    this.setState("connecting");
    const url = this.token ? `${this.url}?token=${encodeURIComponent(this.token)}` : this.url;
    const socket = new WebSocket(url);
    this.socket = socket;

    socket.onopen = () => {
      this.retryDelay = 1000;
      this.setState("open");
      if (this.subscriptions.size) this.send({ type: "subscribe", symbols: [...this.subscriptions.keys()] });
      this.heartbeat = setInterval(() => this.send({ type: "ping" }), 25_000);
    };
    socket.onmessage = (event) => this.dispatch(event.data);
    socket.onclose = () => {
      if (this.socket !== socket) return;
      this.teardown();
      this.retryTimer = setTimeout(() => this.ensureConnected(), this.retryDelay);
      this.retryDelay = Math.min(this.retryDelay * 2, 30_000);
    };
  }

  private reconnectNow(): void {
    const socket = this.socket;
    this.teardown();
    socket?.close();
    this.ensureConnected();
  }

  private teardown(): void {
    if (this.heartbeat) clearInterval(this.heartbeat);
    if (this.retryTimer) clearTimeout(this.retryTimer);
    this.heartbeat = this.retryTimer = null;
    this.socket = null;
    this.setState("closed");
  }

  private send(message: object): void {
    if (this.socket?.readyState === WebSocket.OPEN) this.socket.send(JSON.stringify(message));
  }

  private dispatch(raw: string): void {
    let message: { type: string; quotes?: Record<string, Quote>; signal?: SignalEvent };
    try {
      message = JSON.parse(raw);
    } catch {
      return;
    }
    if (message.type === "quotes" && message.quotes) {
      for (const [symbol, quote] of Object.entries(message.quotes)) this.latest.set(symbol, quote);
      this.quoteListeners.forEach((l) => l(message.quotes!));
    } else if (message.type === "signal" && message.signal) {
      this.signalListeners.forEach((l) => l(message.signal!));
    }
  }

  private setState(state: ConnectionState): void {
    this.state = state;
    this.stateListeners.forEach((l) => l());
  }
}

export const realtime = new RealtimeClient(WS_URL);

/** Live quotes for `symbols`, merged over whatever the page fetched initially. */
export function useLiveQuotes(symbols: string[]): Record<string, Quote> {
  const key = useMemo(() => [...new Set(symbols.map((s) => s.toUpperCase()))].sort().join(","), [symbols]);
  const [quotes, setQuotes] = useState<Record<string, Quote>>({});

  useEffect(() => {
    if (!key) return;
    const wanted = new Set(key.split(","));
    const off = realtime.onQuotes((batch) => {
      const relevant = Object.entries(batch).filter(([s]) => wanted.has(s));
      if (relevant.length) setQuotes((prev) => ({ ...prev, ...Object.fromEntries(relevant) }));
    });
    const unsubscribe = realtime.subscribe([...wanted]);
    return () => {
      off();
      unsubscribe();
    };
  }, [key]);

  return quotes;
}

export function useSignalListener(listener: SignalListener, enabled = true): void {
  useEffect(() => {
    if (!enabled) return;
    return realtime.onSignal(listener);
  }, [listener, enabled]);
}

export function useConnectionState(): ConnectionState {
  return useSyncExternalStore(realtime.subscribeState, realtime.getState, () => "closed");
}
