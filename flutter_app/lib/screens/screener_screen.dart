import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/app_state.dart';
import '../models/stock.dart';
import '../main.dart';
import 'stock_detail_screen.dart';

class ScreenerScreen extends StatelessWidget {
  const ScreenerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (ctx, state, _) => Scaffold(
        appBar: AppBar(
          title: const Text('QUANT SCREENER'),
          actions: [
            IconButton(
              icon: const Icon(Icons.tune_rounded),
              onPressed: () => _showWeightsSheet(ctx, state),
              tooltip: 'Adjust scoring weights',
            ),
          ],
        ),
        body: Column(
          children: [
            _SummaryBar(state: state),
            Expanded(child: _StockList(state: state)),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: state.screenerState == LoadState.loading ? null : state.runScreener,
          icon: state.screenerState == LoadState.loading
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.play_arrow_rounded),
          label: Text(state.screenerState == LoadState.loading ? 'Scoring...' : 'Run Screener'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  void _showWeightsSheet(BuildContext ctx, AppState state) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Theme.of(ctx).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _WeightsSheet(state: state),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  final AppState state;
  const _SummaryBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final qc = Theme.of(context).extension<QuantColors>()!;
    final result = state.scoreResult;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: qc.border)),
      ),
      child: Row(
        children: [
          _Stat('STOCKS', result?.count.toString() ?? '–', Colors.white),
          const SizedBox(width: 24),
          _Stat('BUY', result?.buySignals.length.toString() ?? '–', qc.buy),
          const SizedBox(width: 24),
          _Stat('SELL', result?.sellSignals.length.toString() ?? '–', qc.sell),
          const Spacer(),
          if (state.screenerState == LoadState.error)
            Text('Error', style: TextStyle(color: qc.sell, fontSize: 12)),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Stat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(value, style: GoogleFonts.spaceMono(
          color: color, fontSize: 18, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _StockList extends StatelessWidget {
  final AppState state;
  const _StockList({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.screenerState == LoadState.idle) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_rounded, size: 48,
                color: Theme.of(context).extension<QuantColors>()!.textSub),
            const SizedBox(height: 12),
            Text('Tap Run Screener to score stocks',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
    }

    if (state.screenerState == LoadState.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.screenerState == LoadState.error) {
      return Center(child: Text(state.screenerError,
          style: TextStyle(color: Theme.of(context).extension<QuantColors>()!.sell)));
    }

    final stocks = state.scoreResult!.stocks;
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: stocks.length,
      itemBuilder: (ctx, i) => _StockTile(stock: stocks[i], rank: i + 1),
    );
  }
}

class _StockTile extends StatelessWidget {
  final Stock stock;
  final int rank;
  const _StockTile({required this.stock, required this.rank});

  @override
  Widget build(BuildContext context) {
    final qc = Theme.of(context).extension<QuantColors>()!;
    return InkWell(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => StockDetailScreen(ticker: stock.ticker))),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: qc.border, width: 0.5)),
        ),
        child: Row(
          children: [
            // Rank
            SizedBox(
              width: 32,
              child: Text('$rank',
                  style: GoogleFonts.spaceMono(color: qc.textSub, fontSize: 12)),
            ),
            // Ticker + name
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stock.ticker, style: GoogleFonts.spaceMono(
                      fontSize: 14, fontWeight: FontWeight.w700)),
                  Text(stock.name,
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            // Score bar
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(stock.totalScore.toStringAsFixed(1),
                          style: GoogleFonts.spaceMono(
                            fontSize: 16, fontWeight: FontWeight.w700,
                            color: _scoreColor(stock.totalScore),
                          )),
                      const SizedBox(width: 8),
                      _SignalBadge(signal: stock.signal),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: stock.totalScore / 100,
                    backgroundColor: qc.border,
                    valueColor: AlwaysStoppedAnimation(_scoreColor(stock.totalScore)),
                    minHeight: 3,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 68) return const Color(0xFF00C896);
    if (score >= 50) return const Color(0xFFFFB703);
    return const Color(0xFFFF4D6D);
  }
}

class _SignalBadge extends StatelessWidget {
  final String signal;
  const _SignalBadge({required this.signal});

  @override
  Widget build(BuildContext context) {
    final color = signal == 'BUY'
        ? const Color(0xFF00C896)
        : signal == 'SELL'
            ? const Color(0xFFFF4D6D)
            : const Color(0xFFFFB703);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(signal,
          style: GoogleFonts.spaceMono(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

// ── Weights Sheet ─────────────────────────────────────────────────────────────
class _WeightsSheet extends StatefulWidget {
  final AppState state;
  const _WeightsSheet({required this.state});
  @override
  State<_WeightsSheet> createState() => _WeightsSheetState();
}

class _WeightsSheetState extends State<_WeightsSheet> {
  late double momentum, pe, profitMargin, debtEquity, roe;

  @override
  void initState() {
    super.initState();
    final w = widget.state.weights;
    momentum    = w.momentum * 100;
    pe          = w.pe * 100;
    profitMargin = w.profitMargin * 100;
    debtEquity  = w.debtEquity * 100;
    roe         = w.roe * 100;
  }

  double get total => momentum + pe + profitMargin + debtEquity + roe;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('SCORING WEIGHTS',
                style: Theme.of(context).appBarTheme.titleTextStyle),
            const Spacer(),
            Text('Total: ${total.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: (total - 100).abs() < 1 ? accent
                      : Theme.of(context).extension<QuantColors>()!.sell,
                  fontWeight: FontWeight.w600,
                )),
          ]),
          const SizedBox(height: 4),
          Text('Weights don\'t need to sum to 100 — they\'re normalised automatically.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 20),
          _Slider('6-Month Momentum', momentum, (v) => setState(() => momentum = v), accent),
          _Slider('P/E Ratio',         pe,       (v) => setState(() => pe = v),       accent),
          _Slider('Profit Margin',     profitMargin, (v) => setState(() => profitMargin = v), accent),
          _Slider('Debt / Equity',     debtEquity, (v) => setState(() => debtEquity = v), accent),
          _Slider('Return on Equity',  roe,      (v) => setState(() => roe = v),      accent),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.state.updateWeights(ScoringWeights(
                  momentum:     momentum / 100,
                  pe:           pe / 100,
                  profitMargin: profitMargin / 100,
                  debtEquity:   debtEquity / 100,
                  roe:          roe / 100,
                ));
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: accent),
              child: const Text('Apply Weights'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Slider extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final Color color;
  const _Slider(this.label, this.value, this.onChanged, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 130,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: 0, max: 60,
            divisions: 60,
            activeColor: color,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 36,
          child: Text('${value.toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.right),
        ),
      ],
    );
  }
}
