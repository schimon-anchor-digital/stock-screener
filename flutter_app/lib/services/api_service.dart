import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/stock.dart';
import '../models/portfolio.dart';
import '../models/trade.dart';

class ApiService {
  // ── Change this to your Cloud Run URL after deployment ──
  static const String baseUrl = 'https://stock-screener-180328327923.us-east4.run.app';
  // For local development:  'http://localhost:8080'

  static const Duration _timeout = Duration(seconds: 30);

  // ── Score Stocks ───────────────────────────────────────────────────────────
  static Future<ScoreResult> scoreStocks({
    int limit = 100,
    ScoringWeights? weights,
  }) async {
    final w = weights ?? ScoringWeights.defaults();
    final uri = Uri.parse('$baseUrl/score-stocks').replace(queryParameters: {
      'limit': '$limit',
      'momentum_w': '${w.momentum}',
      'pe_w': '${w.pe}',
      'profit_margin_w': '${w.profitMargin}',
      'debt_equity_w': '${w.debtEquity}',
      'roe_w': '${w.roe}',
    });

    final res = await http.get(uri).timeout(_timeout);
    if (res.statusCode != 200) throw ApiException('Score failed: ${res.body}');

    final json = jsonDecode(res.body);
    return ScoreResult.fromJson(json);
  }

  // ── Single Stock Detail ────────────────────────────────────────────────────
  static Future<StockDetail> getStock(String ticker) async {
    final res = await http
        .get(Uri.parse('$baseUrl/stock/$ticker'))
        .timeout(_timeout);
    if (res.statusCode == 404) throw ApiException('Ticker not found');
    if (res.statusCode != 200) throw ApiException('Error: ${res.body}');
    return StockDetail.fromJson(jsonDecode(res.body));
  }

  // ── Portfolio ──────────────────────────────────────────────────────────────
  static Future<Portfolio> getPortfolio() async {
    final res = await http
        .get(Uri.parse('$baseUrl/portfolio'))
        .timeout(_timeout);
    if (res.statusCode != 200) throw ApiException('Portfolio error');
    return Portfolio.fromJson(jsonDecode(res.body));
  }

  // ── Execute Trade ──────────────────────────────────────────────────────────
  static Future<TradeResult> executeTrade({
    required String ticker,
    required String action, // 'BUY' or 'SELL'
    double? shares,
    double? dollarAmount,
  }) async {
    final body = {
      'ticker': ticker,
      'action': action,
      if (shares != null) 'shares': shares,
      if (dollarAmount != null) 'dollar_amount': dollarAmount,
    };

    final res = await http
        .post(
          Uri.parse('$baseUrl/trade'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(_timeout);

    if (res.statusCode != 200) {
      final err = jsonDecode(res.body)['detail'] ?? 'Trade failed';
      throw ApiException(err);
    }
    return TradeResult.fromJson(jsonDecode(res.body));
  }

  // ── Export Signals ─────────────────────────────────────────────────────────
  static Future<ExportResult> exportSignals({String format = 'json'}) async {
    final uri = Uri.parse('$baseUrl/export')
        .replace(queryParameters: {'format': format});
    final res = await http.get(uri).timeout(_timeout);
    if (res.statusCode != 200) throw ApiException('Export failed');
    return ExportResult.fromJson(jsonDecode(res.body), format);
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}
