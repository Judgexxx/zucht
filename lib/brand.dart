import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Optik nach der Vorlage "AviarySoft Dashboard": dunkles Anthrazit (slate) mit grünen Akzenten (emerald).
class Brand {
  static const String appName = 'Vogelzucht Manager';
  static const String tagline = 'Live-Sync mit deiner Homepage';

  static const Color bg = Color(0xFF020617); // slate-950
  static const Color panel = Color(0xFF0F172A); // slate-900
  static const Color panelAlt = Color(0xFF1E293B); // slate-800
  static const Color line = Color(0xFF1E293B); // slate-800
  static const Color line2 = Color(0xFF334155); // slate-700
  static const Color text = Color(0xFFF1F5F9); // slate-100
  static const Color soft = Color(0xFFCBD5E1); // slate-300
  static const Color muted = Color(0xFF94A3B8); // slate-400
  static const Color faint = Color(0xFF64748B); // slate-500

  static const Color emerald = Color(0xFF059669); // emerald-600
  static const Color emeraldHi = Color(0xFF10B981); // emerald-500
  static const Color emeraldText = Color(0xFF34D399); // emerald-400
  static const Color amber = Color(0xFFFBBF24); // amber-400
  static const Color amberSolid = Color(0xFFF59E0B); // amber-500
  static const Color blue = Color(0xFF60A5FA); // blue-400
  static const Color purple = Color(0xFFC084FC); // purple-400
  static const Color red = Color(0xFFF87171); // red-400
  static const Color pink = Color(0xFFF472B6); // pink-400
}

/// Farbe mit Transparenz (0..1).
Color tint(Color c, double opacity) => c.withAlpha((opacity * 255).round());

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: Brand.emerald, brightness: Brightness.dark).copyWith(
    primary: Brand.emerald,
    onPrimary: Colors.white,
    secondary: Brand.amberSolid,
    onSecondary: Brand.bg,
    surface: Brand.panel,
    onSurface: Brand.text,
    outline: Brand.line2,
    error: Brand.red,
  );
  final base = ThemeData(useMaterial3: true, brightness: Brightness.dark, colorScheme: scheme);
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c, width: w),
      );
  return base.copyWith(
    scaffoldBackgroundColor: Brand.bg,
    canvasColor: Brand.panel,
    textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(bodyColor: Brand.text, displayColor: Colors.white),
    appBarTheme: const AppBarTheme(
      backgroundColor: Brand.panel,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: Brand.panel, surfaceTintColor: Colors.transparent),
    dialogTheme: DialogThemeData(
      backgroundColor: Brand.panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Brand.line)),
    ),
    cardTheme: CardThemeData(
      color: Brand.panel,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Brand.line)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Brand.emerald,
        foregroundColor: Colors.white,
        minimumSize: const Size(44, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Brand.soft,
        backgroundColor: Brand.panelAlt,
        side: const BorderSide(color: Brand.line2),
        minimumSize: const Size(44, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: Brand.emeraldText)),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Brand.emerald,
      foregroundColor: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Brand.bg,
      labelStyle: const TextStyle(color: Brand.muted),
      hintStyle: const TextStyle(color: Brand.faint),
      border: border(Brand.line),
      enabledBorder: border(Brand.line),
      disabledBorder: border(Brand.line),
      focusedBorder: border(Brand.emeraldHi, 1.5),
      errorBorder: border(Brand.red),
      focusedErrorBorder: border(Brand.red, 1.5),
    ),
    chipTheme: base.chipTheme.copyWith(
      selectedColor: Brand.emerald,
      backgroundColor: Brand.panelAlt,
      labelStyle: const TextStyle(color: Brand.soft, fontWeight: FontWeight.w600, fontSize: 12),
      secondaryLabelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
      checkmarkColor: Colors.white,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    dividerColor: Brand.line,
    listTileTheme: const ListTileThemeData(iconColor: Brand.emeraldText, textColor: Brand.text),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Brand.panelAlt,
      contentTextStyle: const TextStyle(color: Brand.text),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : Brand.muted),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Brand.emerald : Brand.line2),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Brand.emeraldText),
  );
}

PreferredSizeWidget brandAppBar({required Widget title, List<Widget>? actions}) {
  return AppBar(
    title: title,
    actions: actions,
    bottom: const PreferredSize(
      preferredSize: Size.fromHeight(1),
      child: SizedBox(height: 1, width: double.infinity, child: ColoredBox(color: Brand.line)),
    ),
  );
}

/// Grünes Logo-Quadrat mit Vogel-Symbol.
class BrandLogo extends StatelessWidget {
  final double size;

  const BrandLogo({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Brand.emerald,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [BoxShadow(color: tint(Brand.emerald, 0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Icon(Icons.flutter_dash, color: Colors.white, size: size * 0.6),
    );
  }
}

/// Seitenkopf (Anmeldung): Logo, Name und Untertitel.
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Brand.panel,
        border: Border(bottom: BorderSide(color: Brand.line)),
      ),
      child: Row(
        children: [
          const BrandLogo(size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(Brand.appName, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
                Text(Brand.tagline, style: const TextStyle(color: Brand.emeraldText, fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Abgerundete Kachel im Stil der Vorlage (dunkle Fläche, feine Kontur).
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;

  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? Brand.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor ?? Brand.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

/// Kleines farbiges Etikett ("Voliere 01", "Tag 8" …).
class Tag extends StatelessWidget {
  final String text;
  final Color color;
  final bool solid;

  const Tag(this.text, {super.key, required this.color, this.solid = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: solid ? color : tint(color, 0.12),
        borderRadius: BorderRadius.circular(6),
        border: solid ? null : Border.all(color: tint(color, 0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(color: solid ? Brand.bg : color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}
