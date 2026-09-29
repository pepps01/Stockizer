"""One-time script that builds backend/data/data.json — a local dataset mimicking
tradingview.com/markets (exchanges with trading hours + a curated ticker universe
with company metadata). yfinance is lookup-by-symbol only and can't browse an
exchange's ticker directory, so this static, checked-in file is what powers
browsing/filtering; live price and fundamentals are still fetched from yfinance
at request time (see app/services/yfinance_market_data.py).

Run with:  python -m data.seed.generate_market_data
"""

import json
import os

EXCHANGES = [
    {
        "code": "NASDAQ",
        "name": "Nasdaq",
        "country": "United States",
        "timezone": "America/New_York",
        "open_time": "09:30",
        "close_time": "16:00",
        "trading_days": [0, 1, 2, 3, 4],
    },
    {
        "code": "NYSE",
        "name": "New York Stock Exchange",
        "country": "United States",
        "timezone": "America/New_York",
        "open_time": "09:30",
        "close_time": "16:00",
        "trading_days": [0, 1, 2, 3, 4],
    },
    {
        "code": "LSE",
        "name": "London Stock Exchange",
        "country": "United Kingdom",
        "timezone": "Europe/London",
        "open_time": "08:00",
        "close_time": "16:30",
        "trading_days": [0, 1, 2, 3, 4],
    },
    {
        "code": "TSX",
        "name": "Toronto Stock Exchange",
        "country": "Canada",
        "timezone": "America/Toronto",
        "open_time": "09:30",
        "close_time": "16:00",
        "trading_days": [0, 1, 2, 3, 4],
    },
    {
        "code": "JPX",
        "name": "Japan Exchange (Tokyo)",
        "country": "Japan",
        "timezone": "Asia/Tokyo",
        "open_time": "09:00",
        "close_time": "15:00",
        "trading_days": [0, 1, 2, 3, 4],
    },
]

TICKERS = [
    # NASDAQ
    {"symbol": "AAPL", "name": "Apple Inc.", "exchange": "NASDAQ", "sector": "Technology", "country": "United States", "description": "Designs, manufactures, and markets smartphones, personal computers, and wearables."},
    {"symbol": "MSFT", "name": "Microsoft Corporation", "exchange": "NASDAQ", "sector": "Technology", "country": "United States", "description": "Develops, licenses, and supports software, services, devices, and solutions."},
    {"symbol": "GOOGL", "name": "Alphabet Inc.", "exchange": "NASDAQ", "sector": "Communication Services", "country": "United States", "description": "Provides search, advertising, cloud computing, and other internet-related services."},
    {"symbol": "AMZN", "name": "Amazon.com, Inc.", "exchange": "NASDAQ", "sector": "Consumer Discretionary", "country": "United States", "description": "Operates e-commerce, cloud computing, and digital streaming businesses."},
    {"symbol": "NVDA", "name": "NVIDIA Corporation", "exchange": "NASDAQ", "sector": "Technology", "country": "United States", "description": "Designs graphics processing units and AI computing hardware/software."},
    {"symbol": "TSLA", "name": "Tesla, Inc.", "exchange": "NASDAQ", "sector": "Consumer Discretionary", "country": "United States", "description": "Designs and manufactures electric vehicles and energy storage systems."},
    {"symbol": "META", "name": "Meta Platforms, Inc.", "exchange": "NASDAQ", "sector": "Communication Services", "country": "United States", "description": "Builds social media, advertising, and virtual/augmented reality products."},
    # NYSE
    {"symbol": "JPM", "name": "JPMorgan Chase & Co.", "exchange": "NYSE", "sector": "Financials", "country": "United States", "description": "Provides investment banking, financial services, and asset management."},
    {"symbol": "V", "name": "Visa Inc.", "exchange": "NYSE", "sector": "Financials", "country": "United States", "description": "Operates a global digital payments network."},
    {"symbol": "JNJ", "name": "Johnson & Johnson", "exchange": "NYSE", "sector": "Healthcare", "country": "United States", "description": "Develops pharmaceuticals, medical devices, and consumer health products."},
    {"symbol": "PG", "name": "Procter & Gamble Co.", "exchange": "NYSE", "sector": "Consumer Staples", "country": "United States", "description": "Manufactures and markets consumer packaged goods."},
    {"symbol": "KO", "name": "The Coca-Cola Company", "exchange": "NYSE", "sector": "Consumer Staples", "country": "United States", "description": "Manufactures and distributes nonalcoholic beverages."},
    {"symbol": "XOM", "name": "Exxon Mobil Corporation", "exchange": "NYSE", "sector": "Energy", "country": "United States", "description": "Explores, produces, and refines oil and natural gas."},
    # LSE
    {"symbol": "SHEL.L", "name": "Shell plc", "exchange": "LSE", "sector": "Energy", "country": "United Kingdom", "description": "Global energy and petrochemical company."},
    {"symbol": "AZN.L", "name": "AstraZeneca plc", "exchange": "LSE", "sector": "Healthcare", "country": "United Kingdom", "description": "Researches, develops, and markets prescription medicines."},
    {"symbol": "HSBA.L", "name": "HSBC Holdings plc", "exchange": "LSE", "sector": "Financials", "country": "United Kingdom", "description": "Provides international banking and financial services."},
    # TSX
    {"symbol": "RY.TO", "name": "Royal Bank of Canada", "exchange": "TSX", "sector": "Financials", "country": "Canada", "description": "Provides diversified financial services across Canada and internationally."},
    {"symbol": "SHOP.TO", "name": "Shopify Inc.", "exchange": "TSX", "sector": "Technology", "country": "Canada", "description": "Provides a commerce platform for online and retail merchants."},
    # JPX
    {"symbol": "7203.T", "name": "Toyota Motor Corporation", "exchange": "JPX", "sector": "Consumer Discretionary", "country": "Japan", "description": "Designs, manufactures, and sells automobiles worldwide."},
    {"symbol": "6758.T", "name": "Sony Group Corporation", "exchange": "JPX", "sector": "Technology", "country": "Japan", "description": "Develops electronics, gaming, music, and entertainment products."},
]

# Benchmarks shown on the dashboard's "Market summary" (mirrors tradingview.com/markets).
# Not tied to a single tradable exchange, so they're kept separate from TICKERS.
INDICES = [
    {"symbol": "^GSPC", "name": "S&P 500", "sector": "Index", "country": "United States", "description": "Tracks 500 large-cap U.S. companies."},
    {"symbol": "^IXIC", "name": "Nasdaq Composite", "sector": "Index", "country": "United States", "description": "Tracks nearly all stocks listed on the Nasdaq exchange."},
    {"symbol": "^DJI", "name": "Dow Jones Industrial Average", "sector": "Index", "country": "United States", "description": "Tracks 30 large publicly-owned U.S. companies."},
    {"symbol": "BTC-USD", "name": "Bitcoin", "sector": "Crypto", "country": "Global", "description": "The largest cryptocurrency by market capitalization."},
    {"symbol": "DX-Y.NYB", "name": "US Dollar Index", "sector": "Currency", "country": "Global", "description": "Measures the US dollar's value against a basket of foreign currencies."},
    {"symbol": "^TNX", "name": "US 10 Year Treasury Yield", "sector": "Bond", "country": "United States", "description": "Yield on the 10-year U.S. Treasury note."},
]


def main():
    data = {"exchanges": EXCHANGES, "tickers": TICKERS, "indices": INDICES}
    out_path = os.path.join(os.path.dirname(__file__), "..", "data.json")
    out_path = os.path.abspath(out_path)

    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)

    print(f"Wrote {len(EXCHANGES)} exchanges, {len(TICKERS)} tickers, and {len(INDICES)} indices to {out_path}")


if __name__ == "__main__":
    main()
