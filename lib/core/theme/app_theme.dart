import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Brand gradient — fresh greens
  static const Color primary = Color(0xFF2E7D32); // Green
  static const Color primaryDark = Color(0xFF1B5E20);
  static const Color primaryLight = Color(0xFF66BB6A);
  static const Color accent = Color(0xFF81C784);

  // Severity
  static const Color severityRed = Color(0xFFEF5350);
  static const Color severityYellow = Color(0xFFFFCA28);
  static const Color severityGreen = Color(0xFF66BB6A);

  // ASHA theme — soft green
  static const Color ashaStart = Color(0xFF4CAF50);
  static const Color ashaEnd = Color(0xFF81C784);

  // THO theme — deep forest green
  static const Color thoStart = Color(0xFF1B5E20);
  static const Color thoEnd = Color(0xFF43A047);

  // Backgrounds
  static const Color background = Color(0xFFF7FBF7); // Very light tinted green/white
  static const Color surface = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFE0E0E0);

  // Text
  static const Color textPrimary = Color(0xFF1B1B1B);
  static const Color textSecondary = Color(0xFF5E5E5E);
  static const Color textMuted = Color(0xFF9E9E9E);

  // Status
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFEF5350);
  static const Color info = Color(0xFF29B6F6);

  // Offline indicator
  static const Color offline = Color(0xFF757575);
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
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
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 2,
        shadowColor: Colors.black12,
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
          elevation: 2,
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
        elevation: 8,
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
    colors: [Color(0xFFF7FBF7), Color(0xFFE8F5E9)],
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
