import 'package:flutter/material.dart';

// ── Scoring Weights ────────────────────────────────────────────────────────
class ScoringWeights {
  double momentum;
  double pe;
  double profitMargin;
  double debtEquity;
  double roe;

  ScoringWeights({
    required this.momentum,
    required this.pe,
    required this.profitMargin,
    required this.debtEquity,
    required this.roe,
  });

  factory ScoringWeights.defaults() => ScoringWeights(
        momentum: 0.30,
        pe: 0.25,
        profitMargin: 0.25,
        debtEquity: 0.10,
        roe: 0.10,
      );

  // Ensure weights always sum to 1.0
  void normalise() {
    final total = momentum + pe + profitMargin + debtEquity + roe;
    if (total == 0) return;
    momentum /= total;
    pe /= total;
    profitMargin /= total;
    debtEquity /= total;
    roe /= total;
  }
}

// ── Stock ──────────────────────────────────────────────────────────────────
class Stock {
  final String ticker;
  final String name;
  final String sector;
  final double? price;
  final double? peRatio;
  final double? profitMargin;
  final double? debtEquity;
  final double? roe;
  final Map<String, double> scores;
  final double totalScore;
  final String signal; // BUY / SELL / HOLD
  final String scoredAt;

  Stock({
    required this.ticker,
    required this.name,
    required this.sector,
    this.price,
    this.peRatio,
    this.profitMargin,
    this.debtEquity,
    this.roe,
    required this.scores,
    required this.totalScore,
    required this.signal,
    required this.scoredAt,
  });

  factory Stock.fromJson(Map<String, dynamic> j) => Stock(
        ticker:      j['ticker'],
        name:        j['name'] ?? j['ticker'],
        sector:      j['sector'] ?? 'Unknown',
        price:       (j['price'] as num?)?.toDouble(),
        peRatio:     (j['pe_ratio'] as num?)?.toDouble(),
        profitMargin:(j['profit_margin'] as num?)?.toDouble(),
        debtEquity:  (j['debt_equity'] as num?)?.toDouble(),
        roe:         (j['roe'] as num?)?.toDouble(),
        scores:      Map<String, double>.from(
            (j['scores'] as Map).map((k, v) => MapEntry(k, (v as num).toDouble()))),
        totalScore:  (j['total_score'] as num).toDouble(),
        signal:      j['signal'],
        scoredAt:    j['scored_at'] ?? '',
      );

  Color get signalColor {
    switch (signal) {
      case 'BUY':  return const Color(0xFF00C896);
      case 'SELL': return const Color(0xFFFF4D6D);
      default:     return const Color(0xFFFFB703);
    }
  }
}

// ── Score Result (full /score-stocks response) ────────────────────────────
class ScoreResult {
  final int count;
  final List<Stock> stocks;
  final List<Stock> buySignals;
  final List<Stock> sellSignals;
  final ScoringWeights weights;

  ScoreResult({
    required this.count,
    required this.stocks,
    required this.buySignals,
    required this.sellSignals,
    required this.weights,
  });

  factory ScoreResult.fromJson(Map<String, dynamic> j) {
    List<Stock> parse(dynamic list) =>
        (list as List).map((e) => Stock.fromJson(e)).toList();
    final w = j['weights'] as Map;
    return ScoreResult(
      count:       j['count'],
      stocks:      parse(j['stocks']),
      buySignals:  parse(j['buy_signals']),
      sellSignals: parse(j['sell_signals']),
      weights: ScoringWeights(
        momentum:    (w['momentum'] as num).toDouble(),
        pe:          (w['pe'] as num).toDouble(),
        profitMargin:(w['profit_margin'] as num).toDouble(),
        debtEquity:  (w['debt_equity'] as num).toDouble(),
        roe:         (w['roe'] as num).toDouble(),
      ),
    );
  }
}

// ── Price History Point ────────────────────────────────────────────────────
class PricePoint {
  final DateTime date;
  final double close;
  PricePoint({required this.date, required this.close});
  factory PricePoint.fromJson(Map<String, dynamic> j) => PricePoint(
        date:  DateTime.parse(j['date']),
        close: (j['close'] as num).toDouble(),
      );
}

// ── Stock Detail (single stock) ────────────────────────────────────────────
class StockDetail {
  final Stock info;
  final List<PricePoint> history;
  StockDetail({required this.info, required this.history});
  factory StockDetail.fromJson(Map<String, dynamic> j) => StockDetail(
        info:    Stock.fromJson(j['info']),
        history: (j['history'] as List).map((e) => PricePoint.fromJson(e)).toList(),
      );
}
