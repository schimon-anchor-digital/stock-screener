"""
QuantApp Backend — FastAPI + yfinance
Deployed as a Cloud Run service on Google Cloud.

Endpoints:
  GET  /score-stocks          → Score & rank top 100 stocks
  GET  /stock/{ticker}        → Single stock detail + history
  GET  /portfolio             → Current paper portfolio
  POST /trade                 → Execute a paper trade
  GET  /export                → Export buy/sell signals as CSV/JSON
  GET  /health                → Health check
"""

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
import yfinance as yf
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import json, csv, io

# TODO: ALPACA — import alpaca_trade_api as tradeapi

app = FastAPI(title="QuantApp API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Lock down to your Flutter app domain in production
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─── Stock Universe ────────────────────────────────────────────────────────────
# S&P 100 tickers — expand to 500 as needed
STOCK_UNIVERSE = [
    "AAPL","MSFT","GOOGL","AMZN","NVDA","META","BRK-B","LLY","JPM","V",
    "UNH","XOM","MA","JNJ","PG","HD","COST","ABBV","MRK","CRM",
    "ADBE","AMD","ACN","TXN","NFLX","AVGO","TMO","NKE","LOW","PM",
    "UNP","HON","BA","CAT","DE","GE","CVX","COP","WMT","KO",
    "PEP","BAC","WFC","GS","BLK","SPGI","ISRG","SYK","ZTS","NOW",
    "TSLA","PYPL","INTC","QCOM","IBM","ORCL","SAP","SNOW","UBER","LYFT",
    "SQ","COIN","HOOD","SOFI","AFRM","SHOP","MELI","SE","PDD","BABA",
    "TSM","ASML","SMCI","ARM","PLTR","RKLB","IONQ","DELL","HPQ","CSCO",
    "T","VZ","TMUS","CMCSA","DIS","PARA","WBD","SPOT","PINS","SNAP",
    "F","GM","RIVN","LCID","TM","STLA","RACE","TTM","MBLY","MOBILEYE",
]

# ─── In-memory paper portfolio (replace with Firestore/Supabase in production) ─
portfolio = {
    "cash": 100_000.0,
    "positions": {},   # { ticker: { shares, avg_cost, entry_date } }
    "trades": [],      # list of executed trade dicts
}

# ─── Scoring Weights (defaults — Flutter app sends custom weights) ─────────────
DEFAULT_WEIGHTS = {
    "momentum":      0.30,  # 6-month price momentum (first derivative)
    "pe":            0.25,  # P/E ratio vs sector average
    "profit_margin": 0.25,  # Net income / Revenue
    "debt_equity":   0.10,  # Lower is better
    "roe":           0.10,  # Return on Equity — higher is better
}

# Sector average P/E benchmarks for relative scoring
SECTOR_PE = {
    "Technology": 32, "Healthcare": 25, "Financials": 13,
    "Consumer Discretionary": 28, "Consumer Staples": 22,
    "Energy": 14, "Industrials": 22, "Communication Services": 20,
    "Utilities": 18, "Real Estate": 30, "Materials": 18,
}

# ─── Scoring Logic ─────────────────────────────────────────────────────────────

def score_momentum(hist: pd.DataFrame) -> float:
    """
    6-month price momentum as first derivative (linear regression slope).
    Normalised to 0–100.
    """
    if hist is None or len(hist) < 20:
        return 0.0
    prices = hist["Close"].dropna().values
    x = np.arange(len(prices))
    slope, _ = np.polyfit(x, prices, 1)
    # Normalise slope relative to mean price
    mean_price = prices.mean()
    pct_slope = (slope / mean_price) * 100 if mean_price > 0 else 0
    return float(np.clip((pct_slope + 1) * 50, 0, 100))  # centre at 50

def score_pe(pe: Optional[float], sector: str) -> float:
    """Score P/E: penalise negative or very high, reward near/below sector avg."""
    if pe is None or pe <= 0 or pe > 200:
        return 20.0  # penalise unknown/negative earnings
    benchmark = SECTOR_PE.get(sector, 22)
    ratio = pe / benchmark
    if ratio <= 0.5:   return 85.0   # very cheap
    if ratio <= 0.8:   return 75.0
    if ratio <= 1.0:   return 65.0   # at benchmark
    if ratio <= 1.3:   return 50.0
    if ratio <= 1.8:   return 35.0
    return 15.0  # expensive

def score_profit_margin(margin: Optional[float]) -> float:
    """Net profit margin → 0-100 score."""
    if margin is None: return 30.0
    pct = margin * 100
    if pct >= 30: return 95.0
    if pct >= 20: return 80.0
    if pct >= 10: return 65.0
    if pct >= 5:  return 50.0
    if pct >= 0:  return 35.0
    return 10.0  # loss-making

def score_debt_equity(de: Optional[float]) -> float:
    """Lower D/E is better → 0-100 score."""
    if de is None: return 40.0
    if de < 0:    return 20.0   # negative equity
    if de <= 0.3: return 95.0
    if de <= 0.7: return 80.0
    if de <= 1.2: return 65.0
    if de <= 2.0: return 45.0
    if de <= 3.5: return 30.0
    return 10.0

def score_roe(roe: Optional[float]) -> float:
    """Return on Equity → higher is better."""
    if roe is None: return 30.0
    pct = roe * 100
    if pct >= 30: return 95.0
    if pct >= 20: return 80.0
    if pct >= 15: return 65.0
    if pct >= 10: return 50.0
    if pct >= 5:  return 35.0
    return 15.0

def compute_total_score(scores: dict, weights: dict) -> float:
    return sum(scores[k] * weights.get(k, 0) for k in scores)

def fetch_and_score(ticker: str, weights: dict) -> Optional[dict]:
    try:
        stock = yf.Ticker(ticker)
        info = stock.info or {}
        hist = stock.history(period="6mo")

        pe            = info.get("trailingPE")
        profit_margin = info.get("profitMargins")
        de_ratio      = info.get("debtToEquity", None)
        if de_ratio:
            de_ratio /= 100  # yfinance returns as percentage
        roe           = info.get("returnOnEquity")
        sector        = info.get("sector", "Technology")
        price         = info.get("currentPrice") or info.get("regularMarketPrice")
        name          = info.get("shortName", ticker)
        market_cap    = info.get("marketCap")

        scores = {
            "momentum":      score_momentum(hist),
            "pe":            score_pe(pe, sector),
            "profit_margin": score_profit_margin(profit_margin),
            "debt_equity":   score_debt_equity(de_ratio),
            "roe":           score_roe(roe),
        }
        total = compute_total_score(scores, weights)

        # Simple buy/sell/hold signal
        if total >= 68:   signal = "BUY"
        elif total <= 40: signal = "SELL"
        else:             signal = "HOLD"

        return {
            "ticker":         ticker,
            "name":           name,
            "sector":         sector,
            "price":          round(price, 2) if price else None,
            "market_cap":     market_cap,
            "pe_ratio":       round(pe, 2) if pe else None,
            "profit_margin":  round(profit_margin * 100, 2) if profit_margin else None,
            "debt_equity":    round(de_ratio, 2) if de_ratio else None,
            "roe":            round(roe * 100, 2) if roe else None,
            "scores":         {k: round(v, 1) for k, v in scores.items()},
            "total_score":    round(total, 1),
            "signal":         signal,
            "scored_at":      datetime.utcnow().isoformat(),
        }
    except Exception as e:
        print(f"[WARN] Failed to score {ticker}: {e}")
        return None


# ─── Endpoints ──────────────────────────────────────────────────────────────────

@app.get("/health")
def health():
    return {"status": "ok", "timestamp": datetime.utcnow().isoformat()}


@app.get("/score-stocks")
def score_stocks(
    limit: int = Query(20, ge=1, le=len(STOCK_UNIVERSE)),
    momentum_w: float = Query(0.30),
    pe_w: float = Query(0.25),
    profit_margin_w: float = Query(0.25),
    debt_equity_w: float = Query(0.10),
    roe_w: float = Query(0.10),
):
    """
    Score and rank all stocks in the universe.
    Weights are passed from the Flutter app sliders.
    Returns top `limit` stocks sorted by total score descending.
    """
    weights = {
        "momentum":      momentum_w,
        "pe":            pe_w,
        "profit_margin": profit_margin_w,
        "debt_equity":   debt_equity_w,
        "roe":           roe_w,
    }

    results = []
    for ticker in STOCK_UNIVERSE[:limit]:
        scored = fetch_and_score(ticker, weights)
        if scored:
            results.append(scored)

    results.sort(key=lambda x: x["total_score"], reverse=True)

    return {
        "count":    len(results),
        "weights":  weights,
        "stocks":   results,
        "buy_signals":  [s for s in results if s["signal"] == "BUY"],
        "sell_signals": [s for s in results if s["signal"] == "SELL"],
    }


@app.get("/stock/{ticker}")
def get_stock(ticker: str):
    """Full detail for a single stock including 6-month price history."""
    stock = yf.Ticker(ticker.upper())
    hist  = stock.history(period="6mo")
    info  = stock.info or {}

    if hist.empty:
        raise HTTPException(status_code=404, detail=f"No data for {ticker}")

    history_points = [
        {"date": str(d.date()), "close": round(float(c), 2)}
        for d, c in zip(hist.index, hist["Close"])
    ]

    scored = fetch_and_score(ticker.upper(), DEFAULT_WEIGHTS)
    return {
        "info":    scored,
        "history": history_points,
    }


@app.get("/portfolio")
def get_portfolio():
    """Return current paper portfolio with unrealised P&L."""
    positions_with_pnl = []
    total_value = portfolio["cash"]

    for ticker, pos in portfolio["positions"].items():
        try:
            price = yf.Ticker(ticker).info.get("currentPrice", pos["avg_cost"])
            market_value = price * pos["shares"]
            pnl = (price - pos["avg_cost"]) * pos["shares"]
            pnl_pct = ((price - pos["avg_cost"]) / pos["avg_cost"]) * 100
            total_value += market_value

            positions_with_pnl.append({
                "ticker":       ticker,
                "shares":       pos["shares"],
                "avg_cost":     round(pos["avg_cost"], 2),
                "current_price": round(price, 2),
                "market_value": round(market_value, 2),
                "pnl":          round(pnl, 2),
                "pnl_pct":      round(pnl_pct, 2),
                "entry_date":   pos["entry_date"],
            })
        except:
            pass

    return {
        "cash":           round(portfolio["cash"], 2),
        "total_value":    round(total_value, 2),
        "starting_value": 100_000.0,
        "total_return_pct": round(((total_value - 100_000) / 100_000) * 100, 2),
        "positions":      positions_with_pnl,
        "trade_count":    len(portfolio["trades"]),
    }


class TradeRequest(BaseModel):
    ticker: str
    action: str          # "BUY" or "SELL"
    shares: Optional[float] = None
    dollar_amount: Optional[float] = None   # buy $X worth instead of N shares

@app.post("/trade")
def execute_trade(req: TradeRequest):
    """
    Paper trade execution.
    TODO: ALPACA — replace portfolio mutation with:
        api = tradeapi.REST(ALPACA_KEY, ALPACA_SECRET, base_url=ALPACA_BASE)
        api.submit_order(symbol=req.ticker, qty=shares, side=req.action.lower(),
                         type='market', time_in_force='day')
    """
    ticker = req.ticker.upper()
    action = req.action.upper()

    # Fetch current price
    try:
        price = yf.Ticker(ticker).info.get("currentPrice")
        if not price:
            raise HTTPException(status_code=400, detail="Could not fetch price")
    except:
        raise HTTPException(status_code=400, detail="Invalid ticker")

    # Resolve share count
    if req.shares:
        shares = req.shares
    elif req.dollar_amount:
        shares = req.dollar_amount / price
    else:
        raise HTTPException(status_code=400, detail="Provide shares or dollar_amount")

    shares = round(shares, 4)
    cost   = round(shares * price, 2)

    if action == "BUY":
        if portfolio["cash"] < cost:
            raise HTTPException(status_code=400, detail="Insufficient cash")
        portfolio["cash"] -= cost
        if ticker in portfolio["positions"]:
            pos = portfolio["positions"][ticker]
            total_shares = pos["shares"] + shares
            avg_cost = ((pos["avg_cost"] * pos["shares"]) + cost) / total_shares
            portfolio["positions"][ticker] = {"shares": total_shares, "avg_cost": avg_cost, "entry_date": pos["entry_date"]}
        else:
            portfolio["positions"][ticker] = {"shares": shares, "avg_cost": price, "entry_date": datetime.utcnow().isoformat()}

    elif action == "SELL":
        if ticker not in portfolio["positions"]:
            raise HTTPException(status_code=400, detail="Position not held")
        pos = portfolio["positions"][ticker]
        if shares > pos["shares"]:
            raise HTTPException(status_code=400, detail="Not enough shares")
        portfolio["cash"] += cost
        new_shares = pos["shares"] - shares
        if new_shares < 0.0001:
            del portfolio["positions"][ticker]
        else:
            portfolio["positions"][ticker]["shares"] = new_shares

    trade_record = {
        "id":        len(portfolio["trades"]) + 1,
        "ticker":    ticker,
        "action":    action,
        "shares":    shares,
        "price":     price,
        "total":     cost,
        "timestamp": datetime.utcnow().isoformat(),
    }
    portfolio["trades"].append(trade_record)

    return {"success": True, "trade": trade_record, "cash_remaining": round(portfolio["cash"], 2)}


@app.get("/export")
def export_signals(format: str = Query("json", enum=["json", "csv"])):
    """Export current BUY/SELL signals from last score run."""
    # Quick re-score top 50 for export
    results = []
    for ticker in STOCK_UNIVERSE[:50]:
        scored = fetch_and_score(ticker, DEFAULT_WEIGHTS)
        if scored and scored["signal"] != "HOLD":
            results.append(scored)
    results.sort(key=lambda x: x["total_score"], reverse=True)

    if format == "csv":
        output = io.StringIO()
        fields = ["ticker","name","sector","price","total_score","signal",
                  "pe_ratio","profit_margin","debt_equity","roe"]
        writer = csv.DictWriter(output, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(results)
        return {"csv": output.getvalue(), "count": len(results)}

    return {"signals": results, "count": len(results), "exported_at": datetime.utcnow().isoformat()}
