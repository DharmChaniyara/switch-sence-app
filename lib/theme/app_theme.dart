import 'package:flutter/material.dart';

/// Centralized Material 3 Design System for Switch Sense.
class AppTheme {
  AppTheme._();

  // Curated Color Palette
  static const Color primaryBlue = Color(0xFF0070F3);
  static const Color cyanAccent = Color(0xFF00D2FF);
  static const Color emeraldActive = Color(0xFF10B981);
  static const Color amberWarning = Color(0xFFF59E0B);
  static const Color roseDanger = Color(0xFFEF4444);

  // Dark Theme Base Colors
  static const Color darkBackground = Color(0xFF0F172A); // Slate 900
  static const Color darkSurface = Color(0xFF1E293B);    // Slate 800
  static const Color darkSurfaceElevated = Color(0xFF334155);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);

  // Light Theme Base Colors
  static const Color lightBackground = Color(0xFFF8FAFC); // Slate 50
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFF1F5F9);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);

  /// Dark Theme Definition
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.dark(
      primary: cyanAccent,
      onPrimary: const Color(0xFF00363F),
      primaryContainer: const Color(0xFF004E5C),
      onPrimaryContainer: const Color(0xFFB8EAFF),
      secondary: emeraldActive,
      onSecondary: Colors.white,
      surface: darkSurface,
      onSurface: darkTextPrimary,
      error: roseDanger,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: darkBackground,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: darkTextPrimary,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFF334155), width: 1.2),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return emeraldActive;
          }
          return const Color(0xFF64748B);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF064E3B);
          }
          return const Color(0xFF1E293B);
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 48),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: Color(0xFF475569)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  /// Light Theme Definition
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.light(
      primary: primaryBlue,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFD8E7FF),
      onPrimaryContainer: const Color(0xFF001A41),
      secondary: emeraldActive,
      onSecondary: Colors.white,
      surface: lightSurface,
      onSurface: lightTextPrimary,
      error: roseDanger,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: lightBackground,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBackground,
        foregroundColor: lightTextPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: lightTextPrimary,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0.5,
        shadowColor: Colors.black.withValues(alpha: 0.04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return emeraldActive;
          }
          return const Color(0xFF94A3B8);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFFA7F3D0);
          }
          return const Color(0xFFE2E8F0);
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 48),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: Color(0xFFCBD5E1)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
