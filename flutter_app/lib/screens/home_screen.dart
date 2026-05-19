import 'package:flutter/material.dart';
import 'screener_screen.dart';
import 'portfolio_screen.dart';
import 'trade_screen.dart';
import 'export_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  final _screens = const [
    ScreenerScreen(),
    PortfolioScreen(),
    TradeScreen(),
    ExportScreen(),
  ];

  final _items = const [
    BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'Screener'),
    BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_rounded), label: 'Portfolio'),
    BottomNavigationBarItem(icon: Icon(Icons.swap_horiz_rounded), label: 'Trade'),
    BottomNavigationBarItem(icon: Icon(Icons.download_rounded), label: 'Export'),
  ];

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final qc     = Theme.of(context).extension<QuantColors>()!;

    return Scaffold(
      body: IndexedStack(index: _tab, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: qc.border, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _tab,
          onTap: (i) => setState(() => _tab = i),
          items: _items,
          backgroundColor: Theme.of(context).colorScheme.surface,
          selectedItemColor: accent,
          unselectedItemColor: qc.textSub,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedFontSize: 11,
          unselectedFontSize: 11,
        ),
      ),
    );
  }
}

// Re-export QuantColors for convenience
import '../main.dart';
