import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Seed ────────────────────────────────────────────────────
  static const Color seedColor = Color(0xFFFF5A1F);

  // ── Static color tokens ─────────────────────────────────────
  static const Color black       = Color(0xFF111827);
  static const Color white       = Color(0xFFFFFFFF);
  static const Color background  = Color(0xFFF3F2EE); // blanc chaud premium
  static const Color accent      = seedColor;
  static const Color accentLight = Color(0xFFFFF1EA);
  static const Color accentDark  = Color(0xFFD4410A);

  static const Color success      = Color(0xFF12A06B); // vert fintech
  static const Color successLight = Color(0xFFECFDF5);
  static const Color warning      = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFFFBEB);
  static const Color error        = Color(0xFFDC2626);
  static const Color errorLight   = Color(0xFFFEF2F2);
  static const Color info         = Color(0xFF3B82F6);
  static const Color infoLight    = Color(0xFFEFF6FF);

  // Couleurs de marques externes (utilisées pour le bouton "Partager via …")
  static const Color whatsapp     = Color(0xFF25D366);

  static const Color textPrimary   = Color(0xFF1A1620); // encre chaude
  static const Color textSecondary = Color(0xFF6C6873);
  static const Color textTertiary  = Color(0xFFA7A3AD);
  static const Color divider       = Color(0xFFE9E5DF); // hairline chaude
  static const Color cardBg        = Color(0xFFFFFFFF);
  static const Color shimmer       = Color(0xFFF3F4F6);

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFFF5A1F), Color(0xFFFF8C42)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Shadows (vraie profondeur) ───────────────────────────────
  // Ombres douces et chaudes (spread négatif = halo discret sous la carte, pas un drop lourd).
  static const Color _shadowColor = Color(0xFF2A1E12);
  static List<BoxShadow> get shadowSm => [
    BoxShadow(color: _shadowColor.withValues(alpha: 0.035), blurRadius: 12, spreadRadius: -3, offset: const Offset(0, 3)),
  ];
  static List<BoxShadow> get shadowMd => [
    BoxShadow(color: _shadowColor.withValues(alpha: 0.05), blurRadius: 20, spreadRadius: -5, offset: const Offset(0, 6)),
  ];
  static List<BoxShadow> get shadowLg => [
    BoxShadow(color: _shadowColor.withValues(alpha: 0.07), blurRadius: 30, spreadRadius: -7, offset: const Offset(0, 12)),
  ];

  // ── Radius ──────────────────────────────────────────────────
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 20;
  static const double radiusXl = 28;

  // ── Chiffres (montants) — police d'affichage à chiffres TABULAIRES, alignés.
  // L'argent est le héros. (Nom « mono » conservé pour ne pas casser les appels ;
  // ce n'est plus une chasse fixe mais des tabular-figures Manrope.)
  static TextStyle mono({
    double size = 16,
    FontWeight weight = FontWeight.w700,
    Color? color,
    double spacing = -0.5,
  }) =>
      GoogleFonts.manrope(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: spacing,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  // ── Themes ──────────────────────────────────────────────────
  static ThemeData get lightTheme => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor:  seedColor,
      brightness: brightness,
    ).copyWith(
      // Forcer les surfaces à rester neutres — évite la teinte orange de M3
      surface:                    isDark ? null : white,
      surfaceContainerLow:        isDark ? null : white,
      surfaceContainer:           isDark ? null : const Color(0xFFF7F5F1),
      surfaceContainerHigh:       isDark ? null : const Color(0xFFF7F5F1),
      surfaceContainerHighest:    isDark ? null : const Color(0xFFEEEDE8),
    );
    final baseText = GoogleFonts.manropeTextTheme(
      ThemeData(brightness: brightness).textTheme,
    );
    final text = baseText.copyWith(
      displayLarge:  baseText.displayLarge?.copyWith(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.8, height: 1.15),
      displayMedium: baseText.displayMedium?.copyWith(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.6, height: 1.2),
      headlineLarge: baseText.headlineLarge?.copyWith(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.4, height: 1.25),
      headlineMedium:baseText.headlineMedium?.copyWith(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.3, height: 1.3),
      titleLarge:    baseText.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.2),
      titleMedium:   baseText.titleMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.1),
      titleSmall:    baseText.titleSmall?.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
      bodyLarge:     baseText.bodyLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5),
      bodyMedium:    baseText.bodyMedium?.copyWith(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5),
      bodySmall:     baseText.bodySmall?.copyWith(fontSize: 12, fontWeight: FontWeight.w400, height: 1.4),
      labelLarge:    baseText.labelLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
      labelMedium:   baseText.labelMedium?.copyWith(fontSize: 12, fontWeight: FontWeight.w500),
      labelSmall:    baseText.labelSmall?.copyWith(fontSize: 11, fontWeight: FontWeight.w500),
    );

    return ThemeData(
      useMaterial3: true,
      brightness:   brightness,
      colorScheme:  scheme,
      textTheme:    text,
      scaffoldBackgroundColor: isDark ? scheme.surface : background,

      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: isDark ? scheme.surface : white,
        foregroundColor: isDark ? scheme.onSurface : textPrimary,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness:     isDark ? Brightness.dark  : Brightness.light,
        ),
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 17, fontWeight: FontWeight.w600,
          color: isDark ? scheme.onSurface : textPrimary,
          letterSpacing: -0.2,
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: BorderSide(color: isDark ? scheme.outlineVariant : divider, width: 1),
        ),
        color: isDark ? scheme.surfaceContainerLow : white,
        margin: EdgeInsets.zero,
      ),

      // FilledButton = CTA principal (noir, pilule)
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
          textStyle: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.1),
        ),
      ),

      // ElevatedButton = identique (rétrocompat)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: accent,
          foregroundColor: white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
          textStyle: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.1),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
          side: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
          textStyle: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.1),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: textPrimary,
          textStyle: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          // Cupertino sur Android et iOS → active le swipe-back natif depuis
          // le bord gauche sur les deux plateformes (UX moderne unifiée).
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1F2937) : const Color(0xFFF7F5F1),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: error, width: 1.5),
        ),
        hintStyle: const TextStyle(color: textTertiary, fontSize: 15),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 15),
      ),

      // NavigationBar — style maquette : labels visibles, onglet actif ORANGE.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? scheme.surface : white,
        indicatorColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 68,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? accentDark : textTertiary, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? accentDark : textTertiary,
          );
        }),
      ),

      dividerTheme: DividerThemeData(
        color: isDark ? scheme.outlineVariant : divider,
        thickness: 1,
        space: 1,
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 2,
        backgroundColor: accent,
        foregroundColor: Color(0xFFFFFFFF),
        shape: StadiumBorder(),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: black,
        contentTextStyle: GoogleFonts.manrope(fontSize: 14, color: white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
      ),
    );
  }

  // ── Backward compat ─────────────────────────────────────────
  static const Color primaryOrange  = accent;
  static const Color primaryRed     = error;
  static const Color accentGreen    = success;
  static const Color accentYellow   = warning;
  static const Color accentBlue     = info;
  static const Color deepPurple     = Color(0xFF2D1B69);

  // ── Backward compat aliases ──────────────────────────────
  static const Color darkNavy       = black;
  static const Color softWhite      = background;
  static const Color cardWhite      = white;
  static const Color textDark       = textPrimary;
  static const Color textGray       = textSecondary;
  static const Color textLight      = textTertiary;
  static const LinearGradient primaryGradient = accentGradient;
  static const LinearGradient premiumGradient = accentGradient;
  static const LinearGradient darkGradient    = accentGradient;
  static List<BoxShadow> get cardShadow     => shadowMd;
  static List<BoxShadow> get floatingShadow => shadowLg;
}

