import { MarketSummaryCard } from "@/components/market/MarketSummaryCard";
import { IndexQuoteRow } from "@/components/market/IndexQuoteRow";

export default function Home() {
  return (
    <main className="mx-auto w-full max-w-7xl flex-1 px-4 py-8 sm:px-6">
      <h1 className="mb-6 text-2xl font-semibold">
        Market summary <span className="text-muted-foreground">›</span>
      </h1>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <div className="lg:col-span-2">
          <MarketSummaryCard symbol="^GSPC" label="S&P 500" period="5d" />
        </div>
        <div className="rounded-xl border border-border bg-surface p-4 sm:p-5">
          <p className="mb-3 text-sm font-medium text-muted-foreground">Major indices</p>
          <ul className="flex flex-col divide-y divide-border">
            <IndexQuoteRow symbol="^IXIC" label="Nasdaq Composite" />
            <IndexQuoteRow symbol="^DJI" label="Dow Jones Industrial" />
          </ul>
        </div>
      </div>

      <div className="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-3">
        <MarketSummaryCard symbol="BTC-USD" label="Bitcoin" compact period="1mo" />
        <MarketSummaryCard symbol="DX-Y.NYB" label="US Dollar Index" compact period="1mo" />
        <MarketSummaryCard symbol="^TNX" label="US 10Y Yield" compact period="1mo" />
      </div>
    </main>
  );
}
