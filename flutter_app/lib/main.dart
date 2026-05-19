import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/app_state.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const QuantApp(),
    ),
  );
}

class QuantApp extends StatelessWidget {
  const QuantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuantApp',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const HomeScreen(),
    );
  }

  ThemeData _buildTheme() {
    const bg       = Color(0xFF0D1117);  // deep navy-black
    const surface  = Color(0xFF161B22);  // card surface
    const border   = Color(0xFF21262D);
    const accent   = Color(0xFF58A6FF);  // electric blue
    const buy      = Color(0xFF00C896);  // green
    const sell     = Color(0xFFFF4D6D);  // red
    const textPrim = Color(0xFFE6EDF3);
    const textSub  = Color(0xFF8B949E);

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        background: bg,
        surface: surface,
        primary: accent,
        secondary: buy,
        error: sell,
        onBackground: textPrim,
        onSurface: textPrim,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge:  GoogleFonts.spaceMono(color: textPrim, fontWeight: FontWeight.w700),
        headlineMedium: GoogleFonts.inter(color: textPrim, fontWeight: FontWeight.w600, fontSize: 20),
        titleMedium:   GoogleFonts.inter(color: textPrim, fontWeight: FontWeight.w500),
        bodyMedium:    GoogleFonts.inter(color: textPrim, fontSize: 14),
        bodySmall:     GoogleFonts.inter(color: textSub, fontSize: 12),
      ),
      cardTheme: CardTheme(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      dividerColor: border,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.spaceMono(
          color: textPrim, fontSize: 16, fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: textPrim),
      ),
      extensions: const [QuantColors(buy: buy, sell: sell, textSub: textSub, border: border)],
    );
  }
}

// Custom theme extension for semantic colours
class QuantColors extends ThemeExtension<QuantColors> {
  final Color buy;
  final Color sell;
  final Color textSub;
  final Color border;

  const QuantColors({
    required this.buy,
    required this.sell,
    required this.textSub,
    required this.border,
  });

  @override
  QuantColors copyWith({Color? buy, Color? sell, Color? textSub, Color? border}) =>
      QuantColors(
        buy:     buy ?? this.buy,
        sell:    sell ?? this.sell,
        textSub: textSub ?? this.textSub,
        border:  border ?? this.border,
      );

  @override
  QuantColors lerp(QuantColors? other, double t) => this;
}
