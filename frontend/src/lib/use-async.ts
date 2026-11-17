"use client";

import { DependencyList, useCallback, useEffect, useState } from "react";
import { ApiError } from "./api";

export interface AsyncState<T> {
  data: T | null;
  error: string | null;
  loading: boolean;
  reload: () => void;
}

interface Settled<T> {
  key: string;
  data: T | null;
  error: string | null;
}

/**
 * Runs `load` whenever `deps` change (deps must be primitives). `load` may
 * return null to skip. Previous data stays visible while a new request is in
 * flight; `loading` is derived from whether the current deps have settled.
 */
export function useAsync<T>(load: () => Promise<T> | null, deps: DependencyList): AsyncState<T> {
  const [version, setVersion] = useState(0);
  const key = JSON.stringify([...deps, version]);
  const [settled, setSettled] = useState<Settled<T>>({ key: "", data: null, error: null });

  useEffect(() => {
    let cancelled = false;
    const request = load() ?? Promise.resolve(null);
    request
      .then((data) => !cancelled && setSettled({ key, data, error: null }))
      .catch((err) => !cancelled && setSettled((prev) => ({ key, data: prev.data, error: errorMessage(err, "Could not reach the Stockiser API") })));
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key]);

  const reload = useCallback(() => setVersion((v) => v + 1), []);
  return { data: settled.data, error: settled.error, loading: settled.key !== key, reload };
}

export function errorMessage(err: unknown, fallback = "Something went wrong"): string {
  return err instanceof ApiError ? err.message : fallback;
}
