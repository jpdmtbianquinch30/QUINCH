import 'package:flutter/material.dart';

/// Identité visuelle QUINCH, reprise du frontend Angular (`frontend/src/styles.scss`) :
/// accent #4f6ef7, secondaire #10b981, fond sombre #0a0e1a, fond clair #f5f7fa.
/// La police Inter d'Angular n'est pas embarquée : la police système est utilisée
/// (évite d'ajouter des fichiers de police avant validation du design).
/// Les thèmes de composants (boutons, champs, barres) seront ajoutés à l'étape 5,
/// quand l'analyseur pourra valider leur API sur Flutter 3.38.4.
abstract final class QuinchColors {
  static const accent = Color(0xFF4F6EF7);
  static const secondary = Color(0xFF10B981);
  static const danger = Color(0xFFEF4444);
  static const darkBackground = Color(0xFF0A0E1A);
  static const darkSurface = Color(0xFF1A1F35);
  static const lightBackground = Color(0xFFF5F7FA);
  static const lightSurface = Color(0xFFFFFFFF);
}

abstract final class QuinchTheme {
  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: QuinchColors.accent,
          brightness: Brightness.light,
        ).copyWith(
          primary: QuinchColors.accent,
          secondary: QuinchColors.secondary,
          error: QuinchColors.danger,
          surface: QuinchColors.lightSurface,
        );
    return _base(scheme, QuinchColors.lightBackground);
  }

  static ThemeData dark() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: QuinchColors.accent,
          brightness: Brightness.dark,
        ).copyWith(
          primary: QuinchColors.accent,
          secondary: QuinchColors.secondary,
          error: QuinchColors.danger,
          surface: QuinchColors.darkSurface,
        );
    return _base(scheme, QuinchColors.darkBackground);
  }

  static ThemeData _base(ColorScheme scheme, Color background) => ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    // Zones tactiles d'au moins 48 dp (accessibilité).
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );
}
