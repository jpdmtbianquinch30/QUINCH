import 'package:flutter/material.dart';

/// Identité visuelle QUINCH, reprise du frontend Angular (`frontend/src/styles.scss`).
///
/// Lot V1 : jetons de design (couleurs sombre/clair, rayons, espacements), police
/// Inter (déclarée dans `pubspec.yaml`, fichiers dans `assets/fonts/`) et thèmes
/// de composants. Les écrans eux-mêmes ne sont pas modifiés dans ce lot.
///
/// Constantes historiques : conservées sous leur nom d'origine car d'autres
/// fichiers les utilisent (`QuinchColors.accent`, `QuinchColors.secondary`).
abstract final class QuinchColors {
  static const accent = Color(0xFF4F6EF7);
  static const secondary = Color(0xFF10B981);
  static const danger = Color(0xFFEF4444);
  static const darkBackground = Color(0xFF0A0E1A);
  static const darkSurface = Color(0xFF1A1F35);
  static const lightBackground = Color(0xFFF5F7FA);
  static const lightSurface = Color(0xFFFFFFFF);

  /// Doré réservé au Premium (`--q-premium` d'Angular : #fbbf24).
  static const premium = Color(0xFFFBBF24);
}

/// Rayons d'Angular : `--q-radius-sm/md/lg/xl`.
abstract final class QuinchRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}

/// Espacements d'Angular : `--q-space-xs/sm/md/lg/xl`.
abstract final class QuinchSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

/// Valeurs de couleur propres à un mode (sombre ou clair), tirées d'Angular :
/// `:root` pour le sombre, `body.quinch-light` pour le clair.
@immutable
class QuinchPalette {
  const QuinchPalette({
    required this.brightness,
    required this.background,
    required this.card,
    required this.elevated,
    required this.input,
    required this.navBar,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accentText,
    required this.gradientEnd,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
  });

  final Brightness brightness;

  /// Fond de page (`--q-bg-primary`).
  final Color background;

  /// Fond des cartes (`--q-bg-card`).
  final Color card;

  /// Fond des éléments surélevés : dialogues, feuilles (`--q-bg-elevated`).
  final Color elevated;

  /// Fond des champs de saisie (`--q-bg-input`).
  final Color input;

  /// Fond de la barre de navigation du bas.
  final Color navBar;

  /// Bordure fine translucide (`--q-border`).
  final Color border;

  final Color textPrimary;
  final Color textSecondary;

  /// Texte discret (indices, textes secondaires non essentiels).
  final Color textMuted;

  /// Accent utilisable comme COULEUR DE TEXTE sur le fond du mode
  /// (`--q-accent-light` d'Angular) : contraste suffisant, contrairement à
  /// l'accent #4f6ef7 seul sur fond sombre.
  final Color accentText;

  /// Seconde couleur du dégradé du bouton principal (`--q-accent-light`).
  final Color gradientEnd;

  final Color success;
  final Color warning;
  final Color danger;
  final Color info;

  bool get isDark => brightness == Brightness.dark;

  static const dark = QuinchPalette(
    brightness: Brightness.dark,
    background: Color(0xFF0A0E1A),
    card: Color(0xFF1A1F35),
    elevated: Color(0xFF242A42),
    input: Color(0xFF1E2438),
    navBar: Color(0xFF0C1120),
    border: Color(0x14FFFFFF), // blanc à 8 %
    textPrimary: Color(0xFFF0F2F7),
    textSecondary: Color(0xFF9CA3B8),
    textMuted: Color(0xFF6B7280),
    accentText: Color(0xFF6B8AFF),
    gradientEnd: Color(0xFF6B8AFF),
    success: Color(0xFF22C55E),
    warning: Color(0xFFF59E0B),
    danger: Color(0xFFEF4444),
    info: Color(0xFF3B82F6),
  );

  static const light = QuinchPalette(
    brightness: Brightness.light,
    background: Color(0xFFF5F7FA),
    card: Color(0xFFFFFFFF),
    elevated: Color(0xFFFFFFFF),
    input: Color(0xFFF0F2F5),
    navBar: Color(0xFFFFFFFF),
    border: Color(0x14000000), // noir à 8 %
    textPrimary: Color(0xFF1A1D26),
    textSecondary: Color(0xFF4B5563),
    textMuted: Color(0xFF9CA3AF),
    accentText: Color(0xFF3B5DE7),
    gradientEnd: Color(0xFF3B5DE7),
    success: Color(0xFF16A34A),
    warning: Color(0xFFD97706),
    danger: Color(0xFFDC2626),
    info: Color(0xFF2563EB),
  );

  /// Palette du thème courant (selon la luminosité du `Theme` actif).
  static QuinchPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// Dégradés (Angular : bouton principal `linear-gradient(135deg, accent, accent-light)`).
abstract final class QuinchGradients {
  static LinearGradient primary(QuinchPalette palette, {bool dimmed = false}) {
    Color tone(Color c) => dimmed ? c.withValues(alpha: 0.4) : c;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [tone(QuinchColors.accent), tone(palette.gradientEnd)],
    );
  }
}

abstract final class QuinchTheme {
  /// Police embarquée (voir `pubspec.yaml`).
  static const fontFamily = 'Inter';

  /// Accent translucide : fond de l'élément sélectionné (indicateur de navigation,
  /// puces, segments). Équivaut à `--q-accent-subtle` renforcé pour rester visible.
  static const Color _accentTint = Color(0x384F6EF7); // accent à 22 %
  static const Color _navIndicator = Color(0x1C4F6EF7); // accent à 11 %

  static ThemeData light() => _build(QuinchPalette.light);

  static ThemeData dark() => _build(QuinchPalette.dark);

  static ColorScheme _scheme(QuinchPalette p) {
    final dark = p.isDark;
    return ColorScheme(
      brightness: p.brightness,
      primary: QuinchColors.accent,
      onPrimary: Colors.white,
      primaryContainer: dark
          ? const Color(0xFF252F5C)
          : const Color(0xFFEAEEFE),
      onPrimaryContainer: dark ? p.textPrimary : const Color(0xFF3A54D4),
      secondary: QuinchColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: dark
          ? const Color(0xFF183640)
          : const Color(0xFFD1FAE5),
      onSecondaryContainer: dark
          ? const Color(0xFF34D399)
          : const Color(0xFF065F46),
      error: p.danger,
      onError: Colors.white,
      errorContainer: dark ? const Color(0xFF3A2537) : const Color(0xFFFEE2E2),
      onErrorContainer: dark
          ? const Color(0xFFFCA5A5)
          : const Color(0xFFB91C1C),
      surface: p.card,
      onSurface: p.textPrimary,
      onSurfaceVariant: p.textSecondary,
      // `outline` sert d'ICÔNE ou de texte discret dans les écrans : il doit
      // rester bien visible. La bordure translucide d'Angular est `outlineVariant`.
      outline: p.textMuted,
      outlineVariant: p.border,
      shadow: Colors.black,
      scrim: Colors.black,
      surfaceTint: Colors.transparent,
      inverseSurface: p.textPrimary,
      onInverseSurface: p.background,
      inversePrimary: p.accentText,
      surfaceContainerLowest: dark ? p.background : const Color(0xFFFFFFFF),
      surfaceContainerLow: dark
          ? const Color(0xFF111827)
          : const Color(0xFFF8F9FB),
      surfaceContainer: p.card,
      surfaceContainerHigh: dark ? p.input : const Color(0xFFECEFF3),
      surfaceContainerHighest: dark ? p.elevated : const Color(0xFFE5E7EB),
    );
  }

  static TextTheme _textTheme(QuinchPalette p) {
    TextStyle s(double size, FontWeight weight, Color color, double height) =>
        TextStyle(
          fontFamily: fontFamily,
          fontSize: size,
          fontWeight: weight,
          color: color,
          height: height,
        );
    return TextTheme(
      headlineMedium: s(28, FontWeight.w700, p.textPrimary, 1.25),
      headlineSmall: s(24, FontWeight.w700, p.textPrimary, 1.3),
      titleLarge: s(20, FontWeight.w700, p.textPrimary, 1.3),
      titleMedium: s(16, FontWeight.w600, p.textPrimary, 1.4),
      titleSmall: s(14, FontWeight.w600, p.textPrimary, 1.4),
      bodyLarge: s(16, FontWeight.w400, p.textPrimary, 1.5),
      bodyMedium: s(14, FontWeight.w400, p.textPrimary, 1.45),
      bodySmall: s(12, FontWeight.w400, p.textSecondary, 1.4),
      labelLarge: s(14, FontWeight.w600, p.textPrimary, 1.4),
      labelMedium: s(12, FontWeight.w600, p.textSecondary, 1.4),
      labelSmall: s(11, FontWeight.w600, p.textSecondary, 1.4),
    );
  }

  static OutlineInputBorder _outline(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(QuinchRadius.md),
        borderSide: BorderSide(color: color, width: width),
      );

  static ThemeData _build(QuinchPalette p) {
    final scheme = _scheme(p);
    final textTheme = _textTheme(p);
    final buttonText = textTheme.labelLarge!.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w600,
    );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(QuinchRadius.md),
    );
    const buttonPadding = EdgeInsets.symmetric(horizontal: 24, vertical: 12);
    const buttonMinSize = Size(64, 48);

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: scheme,
      fontFamily: fontFamily,
      textTheme: textTheme,
      scaffoldBackgroundColor: p.background,
      // Zones tactiles d'au moins 48 dp (accessibilité).
      materialTapTargetSize: MaterialTapTargetSize.padded,
      appBarTheme: AppBarThemeData(
        backgroundColor: p.background,
        foregroundColor: p.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: p.card,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(QuinchRadius.lg),
          side: BorderSide(color: p.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: p.input,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        // Tous les états sont définis ici : une `border:` posée sur un écran
        // n'a plus d'effet visible sur ces états.
        border: _outline(p.border),
        enabledBorder: _outline(p.border),
        disabledBorder: _outline(p.border),
        focusedBorder: _outline(QuinchColors.accent, width: 2),
        errorBorder: _outline(p.danger),
        focusedErrorBorder: _outline(p.danger, width: 2),
        labelStyle: textTheme.bodyMedium?.copyWith(color: p.textSecondary),
        hintStyle: textTheme.bodyMedium?.copyWith(color: p.textMuted),
        errorStyle: textTheme.bodySmall?.copyWith(color: p.danger),
        prefixIconColor: p.textSecondary,
        suffixIconColor: p.textSecondary,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: QuinchColors.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: QuinchColors.accent.withValues(alpha: 0.4),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.6),
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: buttonText,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          backgroundColor: p.card,
          side: BorderSide(color: p.border),
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.accentText,
          minimumSize: buttonMinSize,
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: p.navBar,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        indicatorColor: _navIndicator,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? p.accentText
                : p.textSecondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: fontFamily,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? p.accentText : p.textSecondary,
          );
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.input,
        selectedColor: _accentTint,
        // Même couleur de texte pour l'état normal et sélectionné : la lisibilité
        // ne dépend pas de l'état (fond sélectionné = accent translucide).
        labelStyle: textTheme.labelLarge?.copyWith(
          fontSize: 13,
          color: p.textPrimary,
        ),
        checkmarkColor: p.textPrimary,
        side: BorderSide(color: p.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(QuinchRadius.sm + 2),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color?>(
            (states) =>
                states.contains(WidgetState.selected) ? _accentTint : p.input,
          ),
          foregroundColor: WidgetStatePropertyAll<Color>(p.textPrimary),
          side: WidgetStatePropertyAll<BorderSide>(BorderSide(color: p.border)),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(QuinchRadius.sm + 2),
            ),
          ),
          textStyle: WidgetStatePropertyAll<TextStyle>(
            textTheme.labelLarge!.copyWith(fontSize: 13),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : p.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith<Color?>(
          (states) => states.contains(WidgetState.selected)
              ? QuinchColors.accent
              : p.input,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith<Color?>(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : p.border,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.elevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(QuinchRadius.lg),
          side: BorderSide(color: p.border),
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(fontSize: 18),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: p.textSecondary,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.elevated,
        modalBackgroundColor: p.elevated,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: p.textMuted,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(QuinchRadius.xl),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.elevated,
        contentTextStyle: textTheme.bodyMedium,
        actionTextColor: p.accentText,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.accentText,
        selectionColor: const Color(0x594F6EF7),
        selectionHandleColor: QuinchColors.accent,
      ),
    );
  }
}
