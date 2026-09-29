export interface User {
  id: number;
  first_name: string;
  last_name: string;
  email: string;
  is_verified: boolean;
  created_at: string;
}

export interface Exchange {
  code: string;
  name: string;
  country: string;
  timezone: string;
  open_time: string;
  close_time: string;
  trading_days: number[];
  is_open: boolean;
}

export interface Quote {
  symbol: string;
  price: number | null;
  previous_close: number | null;
  change: number | null;
  change_percent: number | null;
  currency: string | null;
}

export interface Financials {
  symbol: string;
  pe_ratio: number | null;
  forward_pe: number | null;
  market_cap: number | null;
  eps: number | null;
  dividend_yield: number | null;
  fifty_two_week_high: number | null;
  fifty_two_week_low: number | null;
}

export interface TickerMeta {
  symbol: string;
  name: string;
  exchange: string;
  sector: string;
  country: string;
  description: string;
}

export type Ticker = TickerMeta & Partial<Quote> & Partial<Financials>;

export type StockType = "growth" | "value" | "equity";
export type UserActionType = "hold" | "buy" | "sell" | "view";

export interface SelectorResult {
  symbol: string;
  name: string;
  description: string | null;
  sector: string | null;
  country: string | null;
  index_memberships: string[];
  stock_type: StockType;
  price: number | null;
  change_percent: number | null;
  score: number | null;
  recommended_action: "buy" | "sell" | "hold";
}

export interface AdviserSignal {
  symbol: string;
  signal: "buy" | "sell" | "hold";
  confidence: number | null;
  status: string;
  message: string;
}
