import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/app_state.dart';
import '../main.dart';

class ExportScreen extends StatelessWidget {
  const ExportScreen({super.key});

  Future<void> _exportCsv(BuildContext ctx, AppState state) async {
    final csv = await state.exportSignals(format: 'csv');
    if (csv == null || !ctx.mounted) return;

    final dir  = await getTemporaryDirectory();
    final file = File('${dir.path}/quant_signals_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(csv);
    await Share.shareXFiles([XFile(file.path)], text: 'QuantApp Buy/Sell Signals');
  }

  @override
  Widget build(BuildContext context) {
    final qc = Theme.of(context).extension<QuantColors>()!;
    return Consumer<AppState>(
      builder: (ctx, state, _) => Scaffold(
        appBar: AppBar(title: const Text('EXPORT SIGNALS')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // ── Description ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: qc.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('HOW SIGNALS ARE GENERATED',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(letterSpacing: 1.2)),
                  const SizedBox(height: 12),
                  _Rule(icon: Icons.trending_up_rounded,
                      color: const Color(0xFF58A6FF),
                      title: '6-Month Momentum',
                      desc: 'Linear regression slope on closing prices normalised to stock\'s mean price.'),
                  _Rule(icon: Icons.price_change_rounded,
                      color: const Color(0xFFFFB703),
                      title: 'P/E Ratio',
                      desc: 'Scored relative to sector benchmark. Tech ~32×, Financials ~13×, S&P avg ~22×.'),
                  _Rule(icon: Icons.waterfall_chart_rounded,
                      color: const Color(0xFF00C896),
                      title: 'Profit Margin',
                      desc: 'Net income ÷ revenue. >20% excellent, >10% healthy, negative = penalised.'),
                  _Rule(icon: Icons.account_balance_rounded,
                      color: const Color(0xFFFF4D6D),
                      title: 'Debt / Equity',
                      desc: 'Lower is better. <0.3× excellent, >3.5× penalised heavily.'),
                  _Rule(icon: Icons.speed_rounded,
                      color: const Color(0xFFBB86FC),
                      title: 'Return on Equity',
                      desc: 'Efficiency of shareholder capital. >20% strong, <5% weak.'),
                  const Divider(height: 24),
                  Row(children: [
                    _Badge('BUY ≥ 68', const Color(0xFF00C896)),
                    const SizedBox(width: 8),
                    _Badge('HOLD 40–67', const Color(0xFFFFB703)),
                    const SizedBox(width: 8),
                    _Badge('SELL ≤ 39', const Color(0xFFFF4D6D)),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ── Export buttons ───────────────────────────────────────────
            Text('EXPORT OPTIONS',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(letterSpacing: 1.2)),
            const SizedBox(height: 12),

            _ExportButton(
              icon: Icons.table_chart_rounded,
              label: 'Export as CSV',
              sublabel: 'Share via Files, email, or any app',
              color: const Color(0xFF00C896),
              loading: state.isExporting,
              onTap: () => _exportCsv(ctx, state),
            ),
            const SizedBox(height: 12),
            _ExportButton(
              icon: Icons.code_rounded,
              label: 'Export as JSON',
              sublabel: 'Full signal data with all metric scores',
              color: const Color(0xFF58A6FF),
              loading: state.isExporting,
              onTap: () async {
                await state.exportSignals(format: 'json');
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(state.exportMessage)));
                }
              },
            ),

            if (state.exportMessage.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(state.exportMessage,
                  style: TextStyle(color: qc.buy, fontSize: 13),
                  textAlign: TextAlign.center),
            ],

            const SizedBox(height: 40),
            Text(
              '⚠️  Not financial advice. QuantApp is a research tool.\n'
              'Always do your own due diligence before investing.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, desc;
  const _Rule({required this.icon, required this.color,
      required this.title, required this.desc});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 2),
                Text(desc, style: Theme.of(context).textTheme.bodySmall),
              ],
            )),
          ],
        ),
      );
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(label,
            style: GoogleFonts.spaceMono(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      );
}

class _ExportButton extends StatelessWidget {
  final IconData icon;
  final String label, sublabel;
  final Color color;
  final bool loading;
  final VoidCallback onTap;
  const _ExportButton({required this.icon, required this.label,
      required this.sublabel, required this.color,
      required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final qc = Theme.of(context).extension<QuantColors>()!;
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: qc.border),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: loading
                ? Padding(padding: const EdgeInsets.all(12),
                    child: CircularProgressIndicator(color: color, strokeWidth: 2))
                : Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(sublabel, style: Theme.of(context).textTheme.bodySmall),
            ],
          )),
          Icon(Icons.chevron_right_rounded, color: qc.textSub),
        ]),
      ),
    );
  }
}
