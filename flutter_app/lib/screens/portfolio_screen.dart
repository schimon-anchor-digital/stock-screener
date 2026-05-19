import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/app_state.dart';
import '../models/portfolio.dart';
import '../main.dart';

final _currency = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
final _pct      = NumberFormat('+0.00;-0.00');

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});
  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadPortfolio();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (ctx, state, _) => Scaffold(
        appBar: AppBar(
          title: const Text('PORTFOLIO'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: state.loadPortfolio,
            ),
          ],
        ),
        body: state.portfolioState == LoadState.loading
            ? const Center(child: CircularProgressIndicator())
            : state.portfolioState == LoadState.error
                ? Center(child: Text(state.portfolioError,
                    style: TextStyle(color: Theme.of(ctx).extension<QuantColors>()!.sell)))
                : state.portfolio == null
                    ? const SizedBox()
                    : _PortfolioBody(portfolio: state.portfolio!),
      ),
    );
  }
}

class _PortfolioBody extends StatelessWidget {
  final Portfolio portfolio;
  const _PortfolioBody({required this.portfolio});

  @override
  Widget build(BuildContext context) {
    final qc = Theme.of(context).extension<QuantColors>()!;
    final returnColor = portfolio.totalReturnPct >= 0 ? qc.buy : qc.sell;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Summary card ──────────────────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TOTAL VALUE', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(_currency.format(portfolio.totalValue),
                    style: GoogleFonts.spaceMono(
                        fontSize: 32, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: returnColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${_pct.format(portfolio.totalReturnPct)}%',
                      style: GoogleFonts.spaceMono(
                          color: returnColor, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('vs \$100,000 starting capital',
                      style: Theme.of(context).textTheme.bodySmall),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  _MiniStat('CASH', _currency.format(portfolio.cash), context),
                  const SizedBox(width: 24),
                  _MiniStat('POSITIONS', '${portfolio.positions.length}', context),
                  const SizedBox(width: 24),
                  _MiniStat('TRADES', '${portfolio.tradeCount}', context),
                ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // ── Positions ─────────────────────────────────────────────────────
        if (portfolio.positions.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text('No open positions.\nUse the Trade tab to buy stocks.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          )
        else ...[
          Text('OPEN POSITIONS',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          ...portfolio.positions.map((p) => _PositionCard(pos: p)),
        ],
      ],
    );
  }
}

Widget _MiniStat(String label, String value, BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );

class _PositionCard extends StatelessWidget {
  final Position pos;
  const _PositionCard({required this.pos});

  @override
  Widget build(BuildContext context) {
    final qc    = Theme.of(context).extension<QuantColors>()!;
    final color = pos.pnl >= 0 ? qc.buy : qc.sell;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pos.ticker,
                      style: GoogleFonts.spaceMono(fontWeight: FontWeight.w700)),
                  Text('${pos.shares.toStringAsFixed(2)} shares @ '
                      '${_currency.format(pos.avgCost)}',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_currency.format(pos.marketValue),
                    style: Theme.of(context).textTheme.titleMedium),
                Text(
                  '${pos.pnl >= 0 ? '+' : ''}'
                  '${_currency.format(pos.pnl)} '
                  '(${_pct.format(pos.pnlPct)}%)',
                  style: GoogleFonts.spaceMono(color: color, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
