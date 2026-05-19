// ── Position ──────────────────────────────────────────────────────────────
class Position {
  final String ticker;
  final double shares;
  final double avgCost;
  final double currentPrice;
  final double marketValue;
  final double pnl;
  final double pnlPct;
  final String entryDate;

  Position({
    required this.ticker,
    required this.shares,
    required this.avgCost,
    required this.currentPrice,
    required this.marketValue,
    required this.pnl,
    required this.pnlPct,
    required this.entryDate,
  });

  factory Position.fromJson(Map<String, dynamic> j) => Position(
        ticker:       j['ticker'],
        shares:       (j['shares'] as num).toDouble(),
        avgCost:      (j['avg_cost'] as num).toDouble(),
        currentPrice: (j['current_price'] as num).toDouble(),
        marketValue:  (j['market_value'] as num).toDouble(),
        pnl:          (j['pnl'] as num).toDouble(),
        pnlPct:       (j['pnl_pct'] as num).toDouble(),
        entryDate:    j['entry_date'] ?? '',
      );
}

// ── Portfolio ──────────────────────────────────────────────────────────────
class Portfolio {
  final double cash;
  final double totalValue;
  final double startingValue;
  final double totalReturnPct;
  final List<Position> positions;
  final int tradeCount;

  Portfolio({
    required this.cash,
    required this.totalValue,
    required this.startingValue,
    required this.totalReturnPct,
    required this.positions,
    required this.tradeCount,
  });

  factory Portfolio.fromJson(Map<String, dynamic> j) => Portfolio(
        cash:            (j['cash'] as num).toDouble(),
        totalValue:      (j['total_value'] as num).toDouble(),
        startingValue:   (j['starting_value'] as num).toDouble(),
        totalReturnPct:  (j['total_return_pct'] as num).toDouble(),
        positions:       (j['positions'] as List)
            .map((e) => Position.fromJson(e))
            .toList(),
        tradeCount:      j['trade_count'],
      );
}

// ── Trade ──────────────────────────────────────────────────────────────────
class Trade {
  final int id;
  final String ticker;
  final String action;
  final double shares;
  final double price;
  final double total;
  final String timestamp;

  Trade({
    required this.id,
    required this.ticker,
    required this.action,
    required this.shares,
    required this.price,
    required this.total,
    required this.timestamp,
  });

  factory Trade.fromJson(Map<String, dynamic> j) => Trade(
        id:        j['id'],
        ticker:    j['ticker'],
        action:    j['action'],
        shares:    (j['shares'] as num).toDouble(),
        price:     (j['price'] as num).toDouble(),
        total:     (j['total'] as num).toDouble(),
        timestamp: j['timestamp'],
      );
}

class TradeResult {
  final bool success;
  final Trade trade;
  final double cashRemaining;

  TradeResult({required this.success, required this.trade, required this.cashRemaining});

  factory TradeResult.fromJson(Map<String, dynamic> j) => TradeResult(
        success:        j['success'],
        trade:          Trade.fromJson(j['trade']),
        cashRemaining:  (j['cash_remaining'] as num).toDouble(),
      );
}

// ── Export ─────────────────────────────────────────────────────────────────
class ExportResult {
  final int count;
  final String format;
  final dynamic data; // List<Stock> for json, String for csv

  ExportResult({required this.count, required this.format, required this.data});

  factory ExportResult.fromJson(Map<String, dynamic> j, String format) =>
      ExportResult(
        count:  j['count'],
        format: format,
        data:   format == 'csv' ? j['csv'] : j['signals'],
      );
}
