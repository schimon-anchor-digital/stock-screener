import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/app_state.dart';
import '../main.dart';

class TradeScreen extends StatefulWidget {
  const TradeScreen({super.key});
  @override
  State<TradeScreen> createState() => _TradeScreenState();
}

class _TradeScreenState extends State<TradeScreen> {
  final _tickerCtrl  = TextEditingController();
  final _amountCtrl  = TextEditingController();
  String _action     = 'BUY';
  String _inputType  = 'dollar'; // 'dollar' or 'shares'

  @override
  void dispose() {
    _tickerCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(AppState state) async {
    final ticker = _tickerCtrl.text.trim().toUpperCase();
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (ticker.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid ticker and amount')));
      return;
    }

    final success = await state.executeTrade(
      ticker: ticker,
      action: _action,
      dollarAmount: _inputType == 'dollar' ? amount : null,
      shares: _inputType == 'shares' ? amount : null,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(state.tradeMessage),
        backgroundColor: success
            ? Theme.of(context).extension<QuantColors>()!.buy
            : Theme.of(context).extension<QuantColors>()!.sell,
      ));
      if (success) {
        _tickerCtrl.clear();
        _amountCtrl.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (ctx, state, _) {
        final qc     = Theme.of(context).extension<QuantColors>()!;
        final accent = Theme.of(context).colorScheme.primary;
        final isBuy  = _action == 'BUY';

        return Scaffold(
          appBar: AppBar(title: const Text('PAPER TRADE')),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // ── Paper trading notice ─────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accent.withOpacity(0.3)),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline_rounded, color: accent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'Paper trading — no real money. Starting capital: \$100,000.',
                    style: Theme.of(context).textTheme.bodySmall,
                  )),
                  // TODO: ALPACA — add "Switch to Live" toggle here
                ]),
              ),
              const SizedBox(height: 32),

              // ── BUY / SELL toggle ────────────────────────────────────────
              Row(children: [
                Expanded(child: _ActionButton(
                  label: 'BUY',
                  active: isBuy,
                  color: qc.buy,
                  onTap: () => setState(() => _action = 'BUY'),
                )),
                const SizedBox(width: 12),
                Expanded(child: _ActionButton(
                  label: 'SELL',
                  active: !isBuy,
                  color: qc.sell,
                  onTap: () => setState(() => _action = 'SELL'),
                )),
              ]),
              const SizedBox(height: 24),

              // ── Ticker input ─────────────────────────────────────────────
              _Label('TICKER SYMBOL'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _tickerCtrl,
                textCapitalization: TextCapitalization.characters,
                style: GoogleFonts.spaceMono(fontSize: 18, fontWeight: FontWeight.w700),
                decoration: _inputDecoration('e.g. AAPL'),
              ),
              const SizedBox(height: 20),

              // ── Dollar / Shares toggle ───────────────────────────────────
              _Label('ORDER TYPE'),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'dollar', label: Text('Dollar Amount')),
                  ButtonSegment(value: 'shares', label: Text('Share Count')),
                ],
                selected: {_inputType},
                onSelectionChanged: (s) => setState(() => _inputType = s.first),
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.resolveWith((states) =>
                    states.contains(MaterialState.selected)
                      ? accent.withOpacity(0.2) : Colors.transparent),
                ),
              ),
              const SizedBox(height: 16),

              // ── Amount input ─────────────────────────────────────────────
              _Label(_inputType == 'dollar' ? 'DOLLAR AMOUNT' : 'NUMBER OF SHARES'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                style: GoogleFonts.spaceMono(fontSize: 18),
                decoration: _inputDecoration(_inputType == 'dollar' ? '\$1000.00' : '10.5'),
              ),
              const SizedBox(height: 32),

              // ── Submit ───────────────────────────────────────────────────
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: state.isTrading ? null : () => _submit(state),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isBuy ? qc.buy : qc.sell,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: state.isTrading
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      : Text(
                          '$_action ${_tickerCtrl.text.isNotEmpty ? _tickerCtrl.text.toUpperCase() : ''}',
                          style: GoogleFonts.spaceMono(
                              fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // TODO: ALPACA — add "Connect Alpaca API" section below
              // When Alpaca keys are ready:
              // 1. Add ALPACA_KEY + ALPACA_SECRET to Cloud Run env vars
              // 2. Uncomment alpaca-trade-api in requirements.txt
              // 3. Replace portfolio mutations in /trade endpoint with api.submit_order(...)
              // 4. Add a live/paper mode toggle to this screen
            ],
          ),
        );
      },
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
              color: Theme.of(context).extension<QuantColors>()!.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
              color: Theme.of(context).extension<QuantColors>()!.border),
        ),
      );
}

Widget _Label(String text) => Text(text,
    style: const TextStyle(
        fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF8B949E),
        letterSpacing: 1.2));

class _ActionButton extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({required this.label, required this.active,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 48,
          decoration: BoxDecoration(
            color: active ? color.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? color : Theme.of(context).extension<QuantColors>()!.border,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Text(label,
                style: GoogleFonts.spaceMono(
                  color: active ? color : Theme.of(context).extension<QuantColors>()!.textSub,
                  fontWeight: FontWeight.w700,
                )),
          ),
        ),
      );
}
