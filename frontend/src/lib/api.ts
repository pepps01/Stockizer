const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:5000";

export class ApiError extends Error {
  constructor(
    message: string,
    public status: number,
  ) {
    super(message);
  }
}

async function apiFetch<T>(
  path: string,
  options: RequestInit & { token?: string } = {},
): Promise<T> {
  const { token, headers, ...rest } = options;

  const res = await fetch(`${API_BASE_URL}${path}`, {
    ...rest,
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...headers,
    },
  });

  const body = await res.json().catch(() => ({}));

  if (!res.ok) {
    throw new ApiError(body.error ?? "Request failed", res.status);
  }

  return body as T;
}

export const api = {
  register: (data: { first_name: string; last_name: string; email: string; password: string }) =>
    apiFetch<{ user: import("./types").User }>("/api/auth/register", {
      method: "POST",
      body: JSON.stringify(data),
    }),

  verifyEmail: (token: string) =>
    apiFetch<{ user: import("./types").User }>(`/api/auth/verify-email?token=${encodeURIComponent(token)}`),

  login: (data: { email: string; password: string }) =>
    apiFetch<{ access_token: string; user: import("./types").User }>("/api/auth/login", {
      method: "POST",
      body: JSON.stringify(data),
    }),

  getMe: (token: string) => apiFetch<{ user: import("./types").User }>("/api/auth/me", { token }),

  updateMe: (token: string, data: { first_name?: string; last_name?: string }) =>
    apiFetch<{ user: import("./types").User }>("/api/auth/me", {
      method: "PUT",
      token,
      body: JSON.stringify(data),
    }),

  listExchanges: () => apiFetch<{ exchanges: import("./types").Exchange[] }>("/api/exchanges"),

  getExchangeTickers: (code: string) =>
    apiFetch<{ exchange: import("./types").Exchange; tickers: import("./types").Ticker[] }>(
      `/api/exchanges/${code}/tickers`,
    ),

  getTicker: (symbol: string) => apiFetch<{ ticker: import("./types").Ticker }>(`/api/tickers/${symbol}`),

  getTickerFinancials: (symbol: string) =>
    apiFetch<{ symbol: string; financials: import("./types").Financials }>(`/api/tickers/${symbol}/financials`),

  getTickerHistory: (symbol: string, period = "1mo", interval = "1d") =>
    apiFetch<{ symbol: string; history: { time: string; value: number }[] }>(
      `/api/tickers/${symbol}/history?period=${period}&interval=${interval}`,
    ),

  runSelector: (stockType: string, topN = 10) =>
    apiFetch<{ stock_type: string; results: import("./types").SelectorResult[] }>(
      `/api/selector?type=${stockType}&top_n=${topN}`,
    ),

  recordSelectorAction: (token: string, data: { symbol: string; action: import("./types").UserActionType }) =>
    apiFetch("/api/selector/action", { method: "POST", token, body: JSON.stringify(data) }),

  getAdviserSignal: (symbol: string) =>
    apiFetch<import("./types").AdviserSignal>(`/api/adviser/${symbol}/signal`),
};
