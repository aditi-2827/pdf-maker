import 'package:flutter/material.dart';

// ─── Color constants ──────────────────────────────────────────────────────────
// These are used for hardcoded cases (dark-only widgets like scan screen).
// Theme-aware widgets should use Theme.of(context).colorScheme instead.

class AppColors {
  // Dark palette
  static const bg = Color(0xFF0B1120);
  static const surface = Color(0xFF111A2E);
  static const primary = Color(0xFF2F6FEE);
  static const primaryDark = Color(0xFF1E4FC4);
  static const danger = Color(0xFFE5484D);
  static const textFaint = Color(0xFF9AA4B2);
  static const divider = Color(0xFFE5E7EB);

  // Light palette aliases (used for light mode specific overrides)
  static const bgLight = Color(0xFFF4F6FB);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const textFaintLight = Color(0xFF6B7280);

  // Legacy aliases kept for compatibility
  static const card = Colors.white;
  static const textDark = Color(0xFF111827);
  static const textGray = Color(0xFF6B7280);
  static const chipBg = Color(0xFFF1F5F9);
}

// ─── Global theme notifier ────────────────────────────────────────────────────
// Any widget can call: themeNotifier.value = ThemeMode.light;
final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);

// ─── Theme definitions ────────────────────────────────────────────────────────

class AppTheme {
  // ── Dark theme ───────────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        primary: AppColors.primary,
        surface: AppColors.surface,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: const BorderSide(color: AppColors.divider),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.primary : Colors.grey,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.primary.withValues(alpha: 0.4)
              : Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(color: AppColors.textFaint),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFF1E2D4A), thickness: 0.8),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        labelStyle: const TextStyle(color: AppColors.textFaint),
        hintStyle: const TextStyle(color: AppColors.textFaint),
      ),
    );
  }

  // ── Light theme ──────────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    const primaryColor = AppColors.primary;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.bgLight,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        primary: primaryColor,
        surface: AppColors.surfaceLight,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: Color(0xFF111827),
        elevation: 0,
        centerTitle: false,
        shadowColor: Color(0x1A000000),
        titleTextStyle: TextStyle(
          color: Color(0xFF111827),
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: const BorderSide(color: Color(0xFFD1D5DB)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? primaryColor : Colors.grey,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? primaryColor.withValues(alpha: 0.35)
              : Colors.grey.withValues(alpha: 0.25),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceLight,
        elevation: 1,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(color: Color(0xFF6B7280)),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFE5E7EB), thickness: 0.8),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        labelStyle: const TextStyle(color: Color(0xFF6B7280)),
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
      ),
    );
  }

  // Legacy getter — kept for any old references
  static ThemeData get theme => darkTheme;
}

// ─── PDF file icon widget ─────────────────────────────────────────────────────

class PdfFileIcon extends StatelessWidget {
  final double size;
  const PdfFileIcon({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? AppColors.chipBg : const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.description, color: AppColors.primary, size: size * 0.55),
          Positioned(
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text(
                'PDF',
                style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}