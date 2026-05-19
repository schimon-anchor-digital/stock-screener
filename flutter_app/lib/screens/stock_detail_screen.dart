import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/app_state.dart';
import '../models/stock.dart';
import '../main.dart';

class StockDetailScreen extends StatefulWidget {
  final String ticker;
  const StockDetailScreen({super.key, required this.ticker});
  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen> {
  StockDetail? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await ApiService.getStock(widget.ticker);
      setState(() { _detail = d; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final qc = Theme.of(context).extension<QuantColors>()!;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.ticker),
        actions: [
          if (_detail != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _SignalBadge(signal: _detail!.info.signal),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: TextStyle(color: qc.sell)))
              : _DetailBody(detail: _detail!),
    );
  }
}

class _DetailBody extends StatelessWidget {
  final StockDetail detail;
  const _DetailBody({required this.detail});

  @override
  Widget build(BuildContext context) {
    final stock = detail.info;
    final qc    = Theme.of(context).extension<QuantColors>()!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Header ────────────────────────────────────────────────────────
        Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(stock.name, style: Theme.of(context).textTheme.headlineMedium),
              Text(stock.sector, style: Theme.of(context).textTheme.bodySmall),
            ],
          )),
          if (stock.price != null)
            Text('\$${stock.price!.toStringAsFixed(2)}',
                style: GoogleFonts.spaceMono(fontSize: 28, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 20),

        // ── Total score ───────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: qc.border),
          ),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('COMPOSITE SCORE', style: Theme.of(context).textTheme.bodySmall),
              Text(stock.totalScore.toStringAsFixed(1),
                  style: GoogleFonts.spaceMono(
                    fontSize: 40, fontWeight: FontWeight.w700,
                    color: _scoreColor(stock.totalScore),
                  )),
            ]),
            const Spacer(),
            _SignalBadge(signal: stock.signal, large: true),
          ]),
        ),
        const SizedBox(height: 16),

        // ── Price chart ───────────────────────────────────────────────────
        if (detail.history.isNotEmpty) ...[
          Text('6-MONTH PRICE', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          _PriceChart(history: detail.history),
          const SizedBox(height: 20),
        ],

        // ── Score breakdown ───────────────────────────────────────────────
        Text('SCORE BREAKDOWN', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        ...stock.scores.entries.map((e) => _ScoreRow(
          label: _metricLabel(e.key),
          score: e.value,
          raw: _rawValue(stock, e.key),
        )),
        const SizedBox(height: 20),

        // ── Fundamentals ──────────────────────────────────────────────────
        Text('FUNDAMENTALS', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Card(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _FundRow('P/E Ratio',     stock.peRatio != null ? '${stock.peRatio!.toStringAsFixed(1)}×' : '–'),
            _FundRow('Profit Margin', stock.profitMargin != null ? '${stock.profitMargin!.toStringAsFixed(1)}%' : '–'),
            _FundRow('Debt/Equity',   stock.debtEquity != null ? '${stock.debtEquity!.toStringAsFixed(2)}×' : '–'),
            _FundRow('ROE',           stock.roe != null ? '${stock.roe!.toStringAsFixed(1)}%' : '–'),
          ]),
        )),
        const SizedBox(height: 20),

        // ── Quick trade ───────────────────────────────────────────────────
        _QuickTrade(ticker: stock.ticker),
      ],
    );
  }

  String _metricLabel(String key) {
    switch (key) {
      case 'momentum':      return '6-Month Momentum';
      case 'pe':            return 'P/E Ratio';
      case 'profit_margin': return 'Profit Margin';
      case 'debt_equity':   return 'Debt / Equity';
      case 'roe':           return 'Return on Equity';
      default:              return key;
    }
  }

  String _rawValue(Stock s, String key) {
    switch (key) {
      case 'pe':            return s.peRatio != null ? '${s.peRatio!.toStringAsFixed(1)}×' : '–';
      case 'profit_margin': return s.profitMargin != null ? '${s.profitMargin!.toStringAsFixed(1)}%' : '–';
      case 'debt_equity':   return s.debtEquity != null ? '${s.debtEquity!.toStringAsFixed(2)}×' : '–';
      case 'roe':           return s.roe != null ? '${s.roe!.toStringAsFixed(1)}%' : '–';
      default:              return '';
    }
  }

  Color _scoreColor(double s) {
    if (s >= 68) return const Color(0xFF00C896);
    if (s >= 50) return const Color(0xFFFFB703);
    return const Color(0xFFFF4D6D);
  }
}

class _PriceChart extends StatelessWidget {
  final List<PricePoint> history;
  const _PriceChart({required this.history});

  @override
  Widget build(BuildContext context) {
    final qc     = Theme.of(context).extension<QuantColors>()!;
    final prices = history.map((p) => p.close).toList();
    final minY   = prices.reduce((a, b) => a < b ? a : b) * 0.98;
    final maxY   = prices.reduce((a, b) => a > b ? a : b) * 1.02;
    final isUp   = prices.last >= prices.first;
    final color  = isUp ? qc.buy : qc.sell;

    final spots = history.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.close))
        .toList();

    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: qc.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LineChart(LineChartData(
          minY: minY, maxY: maxY,
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 2,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withOpacity(0.1),
              ),
            ),
          ],
        )),
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final String label, raw;
  final double score;
  const _ScoreRow({required this.label, required this.score, required this.raw});

  @override
  Widget build(BuildContext context) {
    final qc = Theme.of(context).extension<QuantColors>()!;
    final color = score >= 70 ? qc.buy : score >= 45 ? const Color(0xFFFFB703) : qc.sell;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        SizedBox(
          width: 150,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(child: LinearProgressIndicator(
          value: score / 100,
          backgroundColor: qc.border,
          valueColor: AlwaysStoppedAnimation(color),
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        )),
        const SizedBox(width: 10),
        SizedBox(
          width: 36,
          child: Text(score.toStringAsFixed(0),
              style: GoogleFonts.spaceMono(color: color, fontSize: 12),
              textAlign: TextAlign.right),
        ),
        if (raw.isNotEmpty) ...[
          const SizedBox(width: 6),
          SizedBox(
            width: 44,
            child: Text(raw,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.right),
          ),
        ],
      ]),
    );
  }
}

Widget _FundRow(String label, String value) => Builder(builder: (ctx) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Text(label, style: Theme.of(ctx).textTheme.bodySmall),
        const Spacer(),
        Text(value, style: GoogleFonts.spaceMono(fontSize: 13)),
      ]),
    ));

class _SignalBadge extends StatelessWidget {
  final String signal;
  final bool large;
  const _SignalBadge({required this.signal, this.large = false});

  @override
  Widget build(BuildContext context) {
    final color = signal == 'BUY'
        ? const Color(0xFF00C896)
        : signal == 'SELL'
            ? const Color(0xFFFF4D6D)
            : const Color(0xFFFFB703);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: large ? 16 : 8, vertical: large ? 8 : 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(signal,
          style: GoogleFonts.spaceMono(
              color: color,
              fontSize: large ? 20 : 12,
              fontWeight: FontWeight.w700)),
    );
  }
}

class _QuickTrade extends StatefulWidget {
  final String ticker;
  const _QuickTrade({required this.ticker});
  @override
  State<_QuickTrade> createState() => _QuickTradeState();
}

class _QuickTradeState extends State<_QuickTrade> {
  final _ctrl = TextEditingController();
  String _action = 'BUY';

  @override
  Widget build(BuildContext context) {
    final qc = Theme.of(context).extension<QuantColors>()!;
    return Consumer<AppState>(builder: (ctx, state, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('QUICK TRADE', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Card(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              _SmallToggle('BUY', _action == 'BUY', qc.buy, () => setState(() => _action = 'BUY')),
              const SizedBox(width: 8),
              _SmallToggle('SELL', _action == 'SELL', qc.sell, () => setState(() => _action = 'SELL')),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(
                controller: _ctrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    hintText: '\$ amount', isDense: true,
                    border: OutlineInputBorder()),
              )),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: state.isTrading ? null : () async {
                  final amount = double.tryParse(_ctrl.text);
                  if (amount == null) return;
                  await state.executeTrade(
                    ticker: widget.ticker, action: _action, dollarAmount: amount);
                  _ctrl.clear();
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: _action == 'BUY' ? qc.buy : qc.sell),
                child: Text(_action, style: const TextStyle(color: Colors.white)),
              ),
            ]),
          ]),
        )),
      ],
    ));
  }
}

Widget _SmallToggle(String label, bool active, Color color, VoidCallback onTap) =>
    Builder(builder: (ctx) => GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active ? color : Theme.of(ctx).extension<QuantColors>()!.border),
        ),
        child: Text(label,
            style: GoogleFonts.spaceMono(
              color: active ? color : Theme.of(ctx).extension<QuantColors>()!.textSub,
              fontSize: 12, fontWeight: FontWeight.w700)),
      ),
    ));
