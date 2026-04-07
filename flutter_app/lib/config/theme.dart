import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// QUINCH Design System — Theme-aware colors
/// Set AppColors.isDark from main Consumer before build.
class AppColors {
  /// Set this BEFORE build from ThemeProvider consumer
  static bool isDark = true;

  // ═══════ PRIMARY ACCENT (same in both themes) ═══════
  static const Color accent = Color(0xFF4F6EF7);
  static const Color accentLight = Color(0xFF6B8AFF);
  static const Color accentDark = Color(0xFF3A54D4);
  static const Color accentSubtle = Color(0x194F6EF7);
  static const Color accentGlow = Color(0x4D4F6EF7);

  // ═══════ SECONDARY (same in both themes) ═══════
  static const Color secondary = Color(0xFF14B8A6);
  static const Color secondaryLight = Color(0xFF2DD4BF);
  static const Color secondarySubtle = Color(0x1914B8A6);

  // ═══════ THEME-AWARE BACKGROUNDS (dark = true black, not navy) ═══════
  static Color get bgPrimary => isDark ? const Color(0xFF000000) : const Color(0xFFF5F7FA);
  static Color get bgSecondary => isDark ? const Color(0xFF0D0D0D) : const Color(0xFFFFFFFF);
  static Color get bgCard => isDark ? const Color(0xFF161616) : const Color(0xFFFFFFFF);
  static Color get bgCardHover => isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F2F5);
  static Color get bgElevated => isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF);
  static Color get bgInput => isDark ? const Color(0xFF121212) : const Color(0xFFF0F2F5);

  // ═══════ THEME-AWARE TEXT ═══════
  static Color get textPrimary => isDark ? const Color(0xFFF0F2F7) : const Color(0xFF1A1D26);
  static Color get textSecondary => isDark ? const Color(0xFF9CA3B8) : const Color(0xFF4B5563);
  static Color get textMuted => isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF);
  static const Color textAccent = Color(0xFF4F6EF7);

  // ═══════ THEME-AWARE BORDERS ═══════
  static Color get border => isDark ? const Color(0x14FFFFFF) : const Color(0x14000000);
  static Color get borderLight => isDark ? const Color(0x0AFFFFFF) : const Color(0x0A000000);

  // Keep old names for backward compat in rare direct references
  static const Color borderLightMode = Color(0x14000000);

  // ═══════ SEMANTIC (same in both themes) ═══════
  static const Color success = Color(0xFF22C55E);
  static const Color successSubtle = Color(0x1922C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningSubtle = Color(0x19F59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerSubtle = Color(0x19EF4444);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoSubtle = Color(0x193B82F6);

  // ═══════ SOCIAL (same) ═══════
  static const Color liked = Color(0xFFEF4444);
  static const Color saved = Color(0xFFF59E0B);
  static const Color online = Color(0xFF22C55E);

  // ═══════ PAYMENT (same) ═══════
  static const Color orangeMoney = Color(0xFFFF6B00);
  static const Color wave = Color(0xFF1DA1F2);
  static const Color freeMoney = Color(0xFF00A859);

  // ═══════ GRADIENTS ═══════
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [accent, accentLight],
  );
  static const LinearGradient logoGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF4F6EF7), Color(0xFF6B8AFF), Color(0xFF8B5CF6)],
  );
  static const LinearGradient publishGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [accent, accentLight],
  );
  static const LinearGradient darkBgGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF000000), Color(0xFF0D0D0D), Color(0xFF161616)],
  );
  static const LinearGradient feedCardGradient = LinearGradient(
    begin: Alignment.topCenter, end: Alignment.bottomCenter,
    colors: [Color(0xFF000000), Color(0xFF050505), Color(0xFF000000)],
    stops: [0.0, 0.5, 1.0],
  );
}

class AppTheme {
  static TextTheme _textTheme(Brightness brightness) {
    return GoogleFonts.interTextTheme(
      brightness == Brightness.dark
          ? ThemeData.dark().textTheme
          : ThemeData.light().textTheme,
    );
  }

  // ═══════ DARK THEME ═══════
  static ThemeData get darkTheme {
    const bg = Color(0xFF000000);
    const bgSec = Color(0xFF0D0D0D);
    const bgCrd = Color(0xFF161616);
    const bgElev = Color(0xFF1A1A1A);
    const bgInp = Color(0xFF121212);
    const txtPri = Color(0xFFF0F2F7);
    const txtSec = Color(0xFF9CA3B8);
    const txtMut = Color(0xFF6B7280);
    const brd = Color(0x14FFFFFF);

    return ThemeData(
      useMaterial3: true, brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent, brightness: Brightness.dark,
        primary: AppColors.accent, secondary: AppColors.secondary,
        surface: bgCrd, error: AppColors.danger,
      ),
      scaffoldBackgroundColor: bg,
      textTheme: _textTheme(Brightness.dark),
      appBarTheme: AppBarTheme(
        backgroundColor: bgSec, foregroundColor: txtPri, elevation: 0, centerTitle: true,
        titleTextStyle: GoogleFonts.inter(color: txtPri, fontSize: 18, fontWeight: FontWeight.w600),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: bgSec, selectedItemColor: AppColors.accent,
        unselectedItemColor: txtMut, type: BottomNavigationBarType.fixed, elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: bgCrd, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: brd)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent, foregroundColor: Colors.white, elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
      )),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
        foregroundColor: txtPri, side: const BorderSide(color: brd),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
      )),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: bgInp,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: brd)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: brd)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accent, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.danger)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: GoogleFonts.inter(color: txtMut, fontSize: 14),
        labelStyle: GoogleFonts.inter(color: txtSec, fontSize: 14),
      ),
      dividerTheme: const DividerThemeData(color: brd, thickness: 1),
      chipTheme: ChipThemeData(
        backgroundColor: bgCrd, selectedColor: AppColors.accentSubtle,
        side: const BorderSide(color: brd), labelStyle: GoogleFonts.inter(fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dialogTheme: DialogThemeData(backgroundColor: bgElev, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: bgElev, shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: bgElev, contentTextStyle: GoogleFonts.inter(color: txtPri),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), behavior: SnackBarBehavior.floating,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.accent, unselectedLabelColor: txtMut, indicatorColor: AppColors.accent,
        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
      ),
    );
  }

  // ═══════ LIGHT THEME ═══════
  static ThemeData get lightTheme {
    const bg = Color(0xFFF5F7FA);
    const bgSec = Color(0xFFFFFFFF);
    const bgCrd = Color(0xFFFFFFFF);
    const bgElev = Color(0xFFFFFFFF);
    const bgInp = Color(0xFFF0F2F5);
    const txtPri = Color(0xFF1A1D26);
    const txtSec = Color(0xFF4B5563);
    const txtMut = Color(0xFF9CA3AF);
    const brd = Color(0x14000000);

    return ThemeData(
      useMaterial3: true, brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent, brightness: Brightness.light,
        primary: AppColors.accent, secondary: AppColors.secondary,
        surface: bgCrd, error: AppColors.danger,
      ),
      scaffoldBackgroundColor: bg,
      textTheme: _textTheme(Brightness.light),
      appBarTheme: AppBarTheme(
        backgroundColor: bgSec, foregroundColor: txtPri, elevation: 0, centerTitle: true,
        titleTextStyle: GoogleFonts.inter(color: txtPri, fontSize: 18, fontWeight: FontWeight.w600),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: bgSec, selectedItemColor: AppColors.accent,
        unselectedItemColor: txtMut, type: BottomNavigationBarType.fixed, elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: bgCrd, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent, foregroundColor: Colors.white, elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      )),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: bgInp,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: brd)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: brd)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accent, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: GoogleFonts.inter(color: txtMut, fontSize: 14),
        labelStyle: GoogleFonts.inter(color: txtSec, fontSize: 14),
      ),
      dividerTheme: const DividerThemeData(color: brd, thickness: 1),
      dialogTheme: DialogThemeData(backgroundColor: bgElev, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: bgElev, shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1E293B), contentTextStyle: GoogleFonts.inter(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), behavior: SnackBarBehavior.floating,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.accent, unselectedLabelColor: txtMut, indicatorColor: AppColors.accent,
        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
      ),
    );
  }
}
