import 'package:flutter/material.dart';
import '../models/stock.dart';
import '../models/portfolio.dart';
import '../services/api_service.dart';

enum LoadState { idle, loading, loaded, error }

class AppState extends ChangeNotifier {
  // ── Screener ───────────────────────────────────────────────────────────────
  LoadState screenerState = LoadState.idle;
  ScoreResult? scoreResult;
  String screenerError = '';
  ScoringWeights weights = ScoringWeights.defaults();

  // ── Portfolio ──────────────────────────────────────────────────────────────
  LoadState portfolioState = LoadState.idle;
  Portfolio? portfolio;
  String portfolioError = '';

  // ── Trade ──────────────────────────────────────────────────────────────────
  bool isTrading = false;
  String tradeMessage = '';

  // ── Export ─────────────────────────────────────────────────────────────────
  bool isExporting = false;
  String exportMessage = '';

  // ── Screener Actions ───────────────────────────────────────────────────────
  Future<void> runScreener() async {
    screenerState = LoadState.loading;
    screenerError = '';
    notifyListeners();

    try {
      scoreResult = await ApiService.scoreStocks(weights: weights);
      screenerState = LoadState.loaded;
    } catch (e) {
      screenerState = LoadState.error;
      screenerError = e.toString();
    }
    notifyListeners();
  }

  void updateWeights(ScoringWeights newWeights) {
    weights = newWeights;
    notifyListeners();
  }

  // ── Portfolio Actions ──────────────────────────────────────────────────────
  Future<void> loadPortfolio() async {
    portfolioState = LoadState.loading;
    portfolioError = '';
    notifyListeners();

    try {
      portfolio = await ApiService.getPortfolio();
      portfolioState = LoadState.loaded;
    } catch (e) {
      portfolioState = LoadState.error;
      portfolioError = e.toString();
    }
    notifyListeners();
  }

  // ── Trade Actions ──────────────────────────────────────────────────────────
  Future<bool> executeTrade({
    required String ticker,
    required String action,
    double? shares,
    double? dollarAmount,
  }) async {
    isTrading = true;
    tradeMessage = '';
    notifyListeners();

    try {
      final result = await ApiService.executeTrade(
        ticker: ticker,
        action: action,
        shares: shares,
        dollarAmount: dollarAmount,
      );
      tradeMessage = '${result.trade.action} ${result.trade.shares.toStringAsFixed(2)} '
          '${result.trade.ticker} @ \$${result.trade.price.toStringAsFixed(2)}';
      isTrading = false;
      notifyListeners();
      await loadPortfolio(); // refresh portfolio after trade
      return true;
    } catch (e) {
      tradeMessage = e.toString();
      isTrading = false;
      notifyListeners();
      return false;
    }
  }

  // ── Export ─────────────────────────────────────────────────────────────────
  Future<String?> exportSignals({String format = 'csv'}) async {
    isExporting = true;
    exportMessage = '';
    notifyListeners();

    try {
      final result = await ApiService.exportSignals(format: format);
      isExporting = false;
      exportMessage = 'Exported ${result.count} signals';
      notifyListeners();
      return format == 'csv' ? result.data as String : null;
    } catch (e) {
      isExporting = false;
      exportMessage = e.toString();
      notifyListeners();
      return null;
    }
  }
}
