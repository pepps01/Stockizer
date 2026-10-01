import type {
  AdviserSession,
  AdviserSignal,
  Bar,
  Country,
  DataSource,
  Exchange,
  ExchangeListing,
  MarketRow,
  Movers,
  OptimizerRun,
  ParamOption,
  SelectorRun,
  SignalEvent,
  SignalParams,
  SymbolDetail,
  TickerInfo,
  User,
  UserActionType,
} from "./types";

export const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:5000";

export class ApiError extends Error {
  constructor(
    message: string,
    public status: number,
  ) {
    super(message);
  }
}

type RequestOptions = RequestInit & { token?: string | null };

/** Thin typed client for the Algizer REST API. */
export class ApiClient {
  constructor(private readonly baseUrl: string) {}

  private async request<T>(path: string, { token, headers, ...rest }: RequestOptions = {}): Promise<T> {
    const res = await fetch(`${this.baseUrl}${path}`, {
      ...rest,
      headers: {
        "Content-Type": "application/json",
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
        ...headers,
      },
    });
    if (res.status === 204) return undefined as T;
    const body = await res.json().catch(() => ({}));
    if (!res.ok) throw new ApiError(body.error ?? `Request failed (${res.status})`, res.status);
    return body as T;
  }

  private post<T>(path: string, body: unknown, token?: string | null) {
    return this.request<T>(path, { method: "POST", body: JSON.stringify(body), token });
  }

  // ---- auth ----
  register = (data: { first_name: string; last_name: string; email: string; password: string }) =>
    this.post<{ user: User }>("/api/auth/register", data);
  verifyEmail = (token: string) => this.request<{ user: User }>(`/api/auth/verify-email?token=${encodeURIComponent(token)}`);
  login = (data: { email: string; password: string }) => this.post<{ access_token: string; user: User }>("/api/auth/login", data);
  getMe = (token: string) => this.request<{ user: User }>("/api/auth/me", { token });
  updateMe = (token: string, data: Partial<Pick<User, "first_name" | "last_name" | "risk_profile" | "alert_channels" | "default_exchange">>) =>
    this.request<{ user: User }>("/api/auth/me", { method: "PUT", token, body: JSON.stringify(data) });

  // ---- markets ----
  countries = () => this.request<{ countries: Country[] }>("/api/countries");
  exchanges = (country?: string | null) =>
    this.request<{ exchanges: Exchange[] }>(`/api/exchanges${country ? `?country=${country}` : ""}`);
  exchange = (code: string) => this.request<ExchangeListing>(`/api/exchanges/${encodeURIComponent(code)}`);
  indices = (country?: string | null) => this.request<{ indices: MarketRow[] }>(`/api/indices${country ? `?country=${country}` : ""}`);
  movers = (params: { country?: string | null; exchange?: string; limit?: number }) => {
    const q = new URLSearchParams();
    if (params.country) q.set("country", params.country);
    if (params.exchange) q.set("exchange", params.exchange);
    if (params.limit) q.set("limit", String(params.limit));
    return this.request<Movers>(`/api/movers?${q}`);
  };
  search = (text: string) => this.request<{ results: TickerInfo[] }>(`/api/search?q=${encodeURIComponent(text)}`);
  symbol = (symbol: string) => this.request<SymbolDetail>(`/api/symbols/${encodeURIComponent(symbol)}`);
  history = (symbol: string, range: string) =>
    this.request<{ symbol: string; range: string; data_source: DataSource; bars: Bar[] }>(
      `/api/symbols/${encodeURIComponent(symbol)}/history?range=${range}`,
    );
  signal = (symbol: string, token?: string | null) =>
    this.request<{ signal: AdviserSignal; optimizer_run_id: string | null }>(`/api/symbols/${encodeURIComponent(symbol)}/signal`, { token });

  // ---- selector ----
  selectorOptions = () =>
    this.request<{ metrics: { value: string; label: string }[]; default_period: { start: string; end: string } }>("/api/selector/options");
  runSelector = (token: string, data: { exchange: string; period_start: string; period_end: string; metric: string; top_n: number }) =>
    this.post<{ run: SelectorRun }>("/api/selector/runs", data, token);
  selectorRuns = (token: string) => this.request<{ runs: SelectorRun[] }>("/api/selector/runs", { token });
  selectorRun = (token: string, id: string) => this.request<{ run: SelectorRun }>(`/api/selector/runs/${id}`, { token });

  // ---- optimizer ----
  optimizerOptions = () => this.request<{ objectives: string[]; parameters: ParamOption[] }>("/api/optimizer/options");
  runOptimizer = (
    token: string,
    data: {
      symbols?: string[];
      selector_run_id?: string;
      top_k?: number;
      training_start: string;
      training_end: string;
      objective: string;
      bounds?: Partial<Record<keyof SignalParams, [number, number]>>;
    },
  ) => this.post<{ runs: OptimizerRun[] }>("/api/optimizer/runs", data, token);
  optimizerRuns = (token: string, symbol?: string) =>
    this.request<{ runs: OptimizerRun[] }>(`/api/optimizer/runs${symbol ? `?symbol=${encodeURIComponent(symbol)}` : ""}`, { token });
  optimizerRun = (token: string, id: string) => this.request<{ run: OptimizerRun }>(`/api/optimizer/runs/${id}`, { token });

  // ---- adviser ----
  sessions = (token: string) => this.request<{ sessions: AdviserSession[] }>("/api/adviser/sessions", { token });
  createSession = (token: string, data: { symbol: string; interval_sec: number; optimizer_run_id?: string | null }) =>
    this.post<{ session: AdviserSession }>("/api/adviser/sessions", data, token);
  updateSession = (token: string, id: string, status: AdviserSession["status"]) =>
    this.request<{ session: AdviserSession }>(`/api/adviser/sessions/${id}`, { method: "PATCH", token, body: JSON.stringify({ status }) });
  evaluateSession = (token: string, id: string) =>
    this.post<{ session: AdviserSession; signal: SignalEvent | null }>(`/api/adviser/sessions/${id}/evaluate`, {}, token);
  signals = (token: string, sessionId?: string) =>
    this.request<{ signals: SignalEvent[] }>(`/api/adviser/signals${sessionId ? `?session_id=${sessionId}` : ""}`, { token });

  // ---- account ----
  watchlist = (token: string) => this.request<{ items: MarketRow[] }>("/api/watchlist", { token });
  addToWatchlist = (token: string, symbol: string) => this.post<{ symbol: string }>("/api/watchlist", { symbol }, token);
  removeFromWatchlist = (token: string, symbol: string) =>
    this.request<void>(`/api/watchlist/${encodeURIComponent(symbol)}`, { method: "DELETE", token });
  recordAction = (token: string, symbol: string, action: UserActionType) => this.post("/api/actions", { symbol, action }, token);

  /** Downloads a pipeline artifact (ticker file / params JSON) with the bearer token. */
  async downloadArtifact(token: string, artifactId: string, fallbackName: string): Promise<void> {
    const res = await fetch(`${this.baseUrl}/api/artifacts/${artifactId}/download`, { headers: { Authorization: `Bearer ${token}` } });
    if (!res.ok) throw new ApiError("Download failed", res.status);
    const disposition = res.headers.get("Content-Disposition") ?? "";
    const name = /filename="?([^"]+)"?/.exec(disposition)?.[1] ?? fallbackName;
    const url = URL.createObjectURL(await res.blob());
    const link = Object.assign(document.createElement("a"), { href: url, download: name });
    link.click();
    URL.revokeObjectURL(url);
  }
}

export const api = new ApiClient(API_BASE_URL);
