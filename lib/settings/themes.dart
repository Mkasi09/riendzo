import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const primaryColor = Color(0xFF2563EB);
  static const secondaryColor = Color(0xFF14B8A6);
  static const accentColor = Color(0xFFF97316);
  static const surfaceColor = Color(0xFFF8FAFC);
  static const cardColor = Color(0xFFFFFFFF);
  static const textColor = Color(0xFF0F172A);
  static const mutedTextColor = Color(0xFF64748B);
  static const outlineColor = Color(0xFFE2E8F0);
  static const shadowColor = Color(0x1A0F172A);

  static final ThemeData defaultTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: surfaceColor,
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.light,
        ).copyWith(
          primary: primaryColor,
          secondary: secondaryColor,
          tertiary: accentColor,
          surface: surfaceColor,
          onSurface: textColor,
          outline: outlineColor,
          shadow: shadowColor,
        ),
    fontFamily: 'Roboto',
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: textColor,
        fontSize: 34,
        fontWeight: FontWeight.w800,
        height: 1.05,
      ),
      displayMedium: TextStyle(
        color: textColor,
        fontSize: 29,
        fontWeight: FontWeight.w800,
        height: 1.1,
      ),
      headlineLarge: TextStyle(
        color: textColor,
        fontSize: 25,
        fontWeight: FontWeight.w800,
      ),
      headlineMedium: TextStyle(
        color: textColor,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: TextStyle(
        color: textColor,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: TextStyle(
        color: Color(0xFF334155),
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(
        color: Color(0xFF334155),
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: TextStyle(
        color: mutedTextColor,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: TextStyle(
        color: Color(0xFF334155),
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: surfaceColor,
      foregroundColor: textColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: textColor,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    ),
    cardTheme: CardThemeData(
      color: cardColor,
      elevation: 0,
      shadowColor: shadowColor,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: outlineColor),
      ),
      margin: EdgeInsets.zero,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      backgroundColor: cardColor,
      surfaceTintColor: Colors.transparent,
      indicatorColor: primaryColor.withValues(alpha: 0.12),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          color: selected ? primaryColor : mutedTextColor,
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? primaryColor : mutedTextColor,
          size: 24,
        );
      }),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFE2E8F0),
        disabledForegroundColor: mutedTextColor,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryColor,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardColor,
      hintStyle: const TextStyle(color: mutedTextColor),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: outlineColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: outlineColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primaryColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
