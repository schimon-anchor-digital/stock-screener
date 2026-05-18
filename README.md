# stock-screener — Algorithmic Stock Screener & Paper Trader
Finance app that automatically buys and sells the ‘best’ 100 stocks based on a set of rules.
Cross-platform Flutter app + FastAPI backend scoring stocks across 5 factors and executing paper trades.

---

## Architecture

```
Flutter App (iOS + Android)
      │
      │  HTTP/JSON
      ▼
FastAPI Backend (Google Cloud Run)
      │
      ├── yfinance  ──→  Yahoo Finance (stock data)
      └── TODO: ALPACA ──→  Alpaca Markets (live trading)
```

---

## Project Structure

```
quantapp/
├── backend/
│   ├── main.py            # FastAPI app — all endpoints
│   ├── requirements.txt
│   └── Dockerfile         # Cloud Run deployment
│
└── flutter_app/
    ├── pubspec.yaml
    └── lib/
        ├── main.dart                        # App entry, theme
        ├── models/
        │   ├── stock.dart                   # Stock, ScoreResult, PricePoint
        │   └── portfolio.dart               # Portfolio, Position, Trade
        ├── services/
        │   ├── api_service.dart             # All backend calls
        │   └── app_state.dart               # Provider state management
        └── screens/
            ├── home_screen.dart             # Bottom nav shell
            ├── screener_screen.dart         # Stock ranking + weight sliders
            ├── portfolio_screen.dart        # P&L dashboard
            ├── trade_screen.dart            # Buy/sell orders
            ├── export_screen.dart           # CSV/JSON export
            └── stock_detail_screen.dart     # Chart + score breakdown
```

---

## Scoring Rules

| Metric | Weight (default) | Logic |
|---|---|---|
| 6-Month Momentum | 30% | Linear regression slope on closing prices, normalised |
| P/E Ratio | 25% | Scored vs sector benchmark (Tech 32×, Financials 13×, etc.) |
| Profit Margin | 25% | Net income ÷ revenue. >20% = excellent |
| Debt/Equity | 10% | Lower is better. <0.3× = excellent |
| Return on Equity | 10% | >20% = strong. Used as 4th "extra" metric |

Signals: **BUY ≥ 68** | **HOLD 40–67** | **SELL ≤ 39**

Weights are adjustable in the app via sliders (automatically normalised).

---

## Setup

### 1. Backend — Local development

```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --reload --port 8080

# Test it:
curl http://localhost:8080/health
curl "http://localhost:8080/score-stocks?limit=10"
```

### 2. Backend — Deploy to Cloud Run

```bash
# Build & push to Artifact Registry
gcloud builds submit --tag gcr.io/YOUR_PROJECT_ID/quantapp-backend

# Deploy
gcloud run deploy quantapp-backend \
  --image gcr.io/YOUR_PROJECT_ID/quantapp-backend \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --memory 1Gi \
  --timeout 120

# Copy the HTTPS URL it gives you
```

### 3. Flutter App

1. Open `flutter_app/lib/services/api_service.dart`
2. Replace `baseUrl` with your Cloud Run URL
3. Run:

```bash
cd flutter_app
flutter pub get
flutter run          # connects to your phone or simulator
```

---

## Alpaca Live Trading (TODO)

Search for `# TODO: ALPACA` across both files. Steps when ready:

1. Get API keys at https://alpaca.markets (free paper trading account)
2. Add to Cloud Run environment variables:
   ```
   ALPACA_KEY=your_key
   ALPACA_SECRET=your_secret
   ALPACA_BASE=https://paper-api.alpaca.markets   # paper trading
   # ALPACA_BASE=https://api.alpaca.markets       # live trading
   ```
3. Uncomment `alpaca-trade-api` in `requirements.txt`
4. In `main.py /trade` endpoint, replace the portfolio dict mutations with:
   ```python
   api = tradeapi.REST(os.environ['ALPACA_KEY'], os.environ['ALPACA_SECRET'],
                       base_url=os.environ['ALPACA_BASE'])
   api.submit_order(symbol=ticker, qty=shares,
                    side=action.lower(), type='market', time_in_force='day')
   ```
5. Add live/paper mode toggle in `trade_screen.dart`

---

## Extending the Stock Universe

Edit `STOCK_UNIVERSE` list in `backend/main.py`. Supports any ticker yfinance covers.
Rate limit: yfinance is free but unofficial — for production, consider a paid data provider
(Polygon.io, Tiingo, or Alpha Vantage) to avoid throttling on large universes.

---

## Disclaimer

⚠️ Not financial advice. This is a research and educational tool.
Always do your own due diligence before making investment decisions.
