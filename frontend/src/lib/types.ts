export type DataSource = "yahoo" | "synthetic";
export type SignalType = "BUY" | "SELL" | "HOLD";
export type RiskProfile = "conservative" | "moderate" | "aggressive";
export type AlertChannel = "in_app" | "email" | "push";
export type StockType = "equity" | "growth" | "value";
export type StockStyle = "growth" | "value" | "blend";
export type StrategyKey = "algebraic" | "indicators";
export type Stance = "buy" | "hold" | "sell";
export type UserActionType = "hold" | "buy" | "sell" | "view";

export interface User {
  id: string;
  email: string;
  first_name: string;
  last_name: string;
  is_verified: boolean;
  is_admin?: boolean;
  is_active?: boolean;
  risk_profile: RiskProfile;
  alert_channels: AlertChannel[];
  default_exchange: string | null;
  created_at: string;
}

export interface Country {
  code: string;
  name: string;
  region: string;
  currency: string;
  exchange_count: number;
}

export interface Exchange {
  id: string;
  code: string;
  name: string;
  country_code: string;
  country: string;
  region: string;
  timezone: string;
  opens_at: string;
  closes_at: string;
  trading_days: number[];
  currency: string;
  data_source: DataSource;
  is_open: boolean;
  local_time: string;
  stock_count?: number;
}

export interface Quote {
  symbol: string;
  price: number;
  prev_close: number | null;
  change: number | null;
  change_percent: number | null;
  open: number;
  high: number;
  low: number;
  volume: number;
  as_of: string;
  currency: string;
  source: DataSource;
  market_open: boolean;
  updated_at: string;
}

export interface TickerInfo {
  id: string;
  symbol: string;
  display_symbol: string;
  name: string;
  sector: string | null;
  kind: "stock" | "index";
  currency: string;
  data_source: DataSource;
  exchange: string;
  exchange_name: string;
  country: string;
  country_code: string;
}

export interface Technicals {
  summary: number | null;
  label: string | null;
  moving_averages: number | null;
  ma_label: string | null;
  oscillators: number | null;
  osc_label: string | null;
  indicators?: Record<string, number | null>;
}

export interface Performance {
  perf_1w?: number | null;
  perf_1m?: number | null;
  perf_3m?: number | null;
  perf_6m?: number | null;
  perf_ytd?: number | null;
  perf_1y?: number | null;
  volatility_1m?: number | null;
}

export interface MarketRow extends TickerInfo {
  quote: Quote | null;
  technicals?: Technicals;
  performance?: Performance;
  range_percent?: number;
}

export interface Movers {
  highest_volume: MarketRow[];
  most_volatile: MarketRow[];
  gainers: MarketRow[];
  losers: MarketRow[];
  universe_size: number;
}

export interface ExchangeListing {
  exchange: Exchange;
  indices: MarketRow[];
  stocks: MarketRow[];
}

export interface Fundamentals {
  market_cap?: number | null;
  pe_ratio?: number | null;
  forward_pe?: number | null;
  eps?: number | null;
  dividend_yield?: number | null;
  beta?: number | null;
  fifty_two_week_high?: number | null;
  fifty_two_week_low?: number | null;
  avg_volume_30d?: number | null;
  employees?: number | null;
  industry?: string | null;
  website?: string | null;
  description?: string | null;
  simulated?: boolean;
}

export interface SymbolDetail {
  ticker: TickerInfo;
  exchange: Exchange;
  quote: Quote | null;
  fundamentals: Fundamentals;
  technicals: Technicals;
  performance: Performance;
}

export interface Bar {
  time: string;
  open: number;
  high: number;
  low: number;
  close: number;
  volume: number;
}

/** Parameter values by name; the names depend on the strategy (see ParamOption). */
export type SignalParams = Record<string, number>;

export interface AdviserSignal {
  signal_type: SignalType;
  score: number;
  confidence: number;
  price: number;
  as_of: string;
  reason: string;
  strategy: StrategyKey;
  /** algebraic: trend, z · indicators: macd_hist, rsi, stoch_d */
  components: Record<string, number>;
  parameters: SignalParams;
  data_source: DataSource;
  market_open: boolean;
}

export interface SignalEvent {
  id: string;
  session_id: string;
  symbol: string;
  display_symbol: string;
  name: string;
  currency: string;
  signal_type: SignalType;
  confidence: number;
  price: number;
  score: number;
  reason: string;
  emitted_at: string;
}

interface TickerBrief {
  symbol: string;
  display_symbol: string;
  name: string;
  exchange: string;
  currency: string;
  data_source: DataSource;
}

export interface SelectorResult extends TickerBrief {
  rank: number;
  score: number;
  metrics: {
    total_return: number;
    cagr: number;
    volatility: number;
    sharpe: number;
    sortino: number;
    max_drawdown: number;
    calmar: number;
    momentum: number;
    start_price: number;
    end_price: number;
    bars: number;
    style?: StockStyle | null;
    style_score?: number | null;
  };
}

export interface SelectorRun {
  id: string;
  exchange: string;
  exchange_name: string;
  period_start: string;
  period_end: string;
  metric: string;
  top_n: number;
  stock_type: StockType;
  universe_size: number;
  artifact_id: string | null;
  created_at: string;
  results?: SelectorResult[];
}

export interface StrategyStats {
  total_return: number;
  cagr: number;
  volatility: number;
  sharpe: number;
  sortino: number;
  max_drawdown: number;
  calmar: number;
}

export interface BacktestSummary {
  strategy: StrategyStats;
  buy_and_hold: StrategyStats;
  trades: number;
  win_rate: number | null;
  exposure: number;
}

export interface CurvePoint {
  time: string;
  strategy: number;
  buy_and_hold: number;
}

export interface OptimizerRun extends TickerBrief {
  id: string;
  selector_run_id: string | null;
  training_start: string;
  training_end: string;
  bounds: Record<string, [number, number]>;
  objective: string;
  strategy: StrategyKey;
  best_score: number | null;
  parameters: SignalParams;
  metrics: {
    evaluations?: number;
    min_trades?: number;
    min_trades_met?: boolean;
    train?: BacktestSummary;
    test?: BacktestSummary | null;
    test_period?: { start: string; end: string; bars: number } | null;
    curves?: { train: CurvePoint[]; test: CurvePoint[] };
  };
  status: "completed" | "failed";
  error: string | null;
  artifact_id: string | null;
  created_at: string;
}

export interface ParamOption {
  name: string;
  type: "int" | "float";
  low: number;
  high: number;
  default: number;
  description: string;
}

export interface AdviserSession extends TickerBrief {
  id: string;
  optimizer_run_id: string | null;
  parameters: SignalParams | null;
  interval_sec: number;
  status: "active" | "paused" | "stopped";
  started_at: string;
  stopped_at: string | null;
  last_evaluated_at: string | null;
  last_signal_type: SignalType | null;
  last_price: number | null;
  last_score: number | null;
  last_confidence: number | null;
}

export interface UserActionRecord {
  id: string;
  symbol: string;
  action: UserActionType;
  created_at: string;
}

export interface StockTypeOption {
  value: StockType;
  label: string;
  description: string;
}

export interface StrategyOption {
  key: StrategyKey;
  label: string;
  description: string;
  parameters: ParamOption[];
}

// ---- admin ----

export interface AdminUser extends User {
  activity: { selector_runs: number; optimizer_runs: number; active_sessions: number };
  access: { signup_ip: string | null; last_ip: string | null; last_seen_at: string | null };
}

/** One sign-up, sign-in or app launch on a saved session, as admins see it. */
export interface AdminAccessEntry {
  id: string;
  event: "register" | "login" | "resume";
  ip: string | null;
  platform: "web" | "android" | "ios" | "other";
  user_agent: string | null;
  created_at: string;
}

export interface AdminAuditEntry {
  id: string;
  admin_email: string | null;
  action: string;
  target_type: string;
  target_id: string;
  detail: Record<string, unknown>;
  created_at: string;
}

export interface AdminOverview {
  users: { total: number; verified: number; admins: number; disabled: number; new_7d: number };
  pipeline: { selector_runs: number; optimizer_runs: number; active_sessions: number; signals_24h: number; push_devices: number };
  system: { market_data_mode: string; push_enabled: boolean; email_enabled: boolean; adviser_worker: boolean };
  recent_users: User[];
  recent_signals: (SignalEvent & { user_email: string })[];
  recent_actions: AdminAuditEntry[];
}

export interface AdminExchange {
  code: string;
  name: string;
  country_code: string;
  data_source: DataSource;
  active_stocks: number;
  total_stocks: number;
}

export interface AdminTicker {
  symbol: string;
  display_symbol: string;
  name: string;
  sector: string | null;
  kind: "stock" | "index";
  data_source: DataSource;
  active: boolean;
}

// ---- index members & financials ----

export interface IndexMembers {
  index: TickerInfo;
  countries: string[];
  stocks: MarketRow[];
}

export interface FinancialStock extends TickerInfo {
  quote: Quote | null;
  style: StockStyle | null;
  style_score: number | null;
  fundamentals: {
    market_cap: number | null;
    pe_ratio: number | null;
    forward_pe: number | null;
    price_to_book: number | null;
    dividend_yield: number | null;
    revenue_growth: number | null;
    earnings_growth: number | null;
  };
}

export interface FinancialSegment {
  key: "growth" | "value" | "equity";
  label: string;
  definition: string;
  traits: string[];
  stocks: FinancialStock[];
}

export interface IndexFinancials {
  index: TickerInfo;
  countries: string[];
  segments: FinancialSegment[];
  unclassified: number;
}

export interface Assumption extends TickerInfo {
  id: string;
  stance: Stance;
  /** Price when the call was made. */
  price: number | null;
  quote: Quote | null;
  change_since_percent: number | null;
  created_at: string;
  updated_at: string;
}
