import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Brand gradient — deep teal to emerald
  static const Color primary = Color(0xFF00897B);
  static const Color primaryDark = Color(0xFF00695C);
  static const Color primaryLight = Color(0xFF4DB6AC);
  static const Color accent = Color(0xFF26C6DA);

  // Severity
  static const Color severityRed = Color(0xFFEF5350);
  static const Color severityYellow = Color(0xFFFFCA28);
  static const Color severityGreen = Color(0xFF66BB6A);

  // ASHA theme — warm teal
  static const Color ashaStart = Color(0xFF00897B);
  static const Color ashaEnd = Color(0xFF26C6DA);

  // THO theme — deep indigo
  static const Color thoStart = Color(0xFF3949AB);
  static const Color thoEnd = Color(0xFF7C4DFF);

  // Backgrounds
  static const Color background = Color(0xFF0A0F1E);
  static const Color surface = Color(0xFF141929);
  static const Color card = Color(0xFF1C2438);
  static const Color cardBorder = Color(0xFF2A3450);

  // Text
  static const Color textPrimary = Color(0xFFF0F4FF);
  static const Color textSecondary = Color(0xFF8A9BB8);
  static const Color textMuted = Color(0xFF4A5568);

  // Status
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFEF5350);
  static const Color info = Color(0xFF29B6F6);

  // Offline indicator
  static const Color offline = Color(0xFFBDBDBD);
}

class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.cardBorder, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.cardBorder, thickness: 1),
    );
  }

  // Gradient helpers
  static LinearGradient get ashaGradient => const LinearGradient(
    colors: [AppColors.ashaStart, AppColors.ashaEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get thoGradient => const LinearGradient(
    colors: [AppColors.thoStart, AppColors.thoEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get backgroundGradient => const LinearGradient(
    colors: [Color(0xFF0A0F1E), Color(0xFF111827)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static Color severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'red': return AppColors.severityRed;
      case 'yellow': return AppColors.severityYellow;
      default: return AppColors.severityGreen;
    }
  }
}
