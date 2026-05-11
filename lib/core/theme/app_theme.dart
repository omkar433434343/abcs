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
  static const Color surface = Color(0x99FFFFFF);
  static const Color card = Color(0x8FFFFFFF);
  static const Color cardBorder = Color(0x99E8FFF0);
  static const Color glassGlow = Color(0x6622C55E);

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
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 14,
        shadowColor: AppColors.glassGlow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.cardBorder, width: 1.2),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0x99FFFFFF),
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
          borderSide: const BorderSide(color: Color(0xFF22A34F), width: 2),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xCC2E7D32),
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
          side: const BorderSide(color: Color(0x66FFFFFF)),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dividerTheme: const DividerThemeData(color: Color(0x55FFFFFF), thickness: 1),
      listTileTheme: const ListTileThemeData(
        tileColor: Color(0x8FFFFFFF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          side: BorderSide(color: Color(0x99E8FFF0)),
        ),
      ),
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
    colors: [Color(0xFFEFFBF3), Color(0xFFDDF5E5), Color(0xFFEDF8F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static Color severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'red': return AppColors.severityRed;
      case 'yellow': return AppColors.severityYellow;
      default: return AppColors.severityGreen;
    }
  }
}
