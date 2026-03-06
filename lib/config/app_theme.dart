import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

ThemeData lightTheme() {
  return ThemeData(
    primarySwatch: sageSwatch,
    primaryColor: AppColors.sage,
    scaffoldBackgroundColor: AppColors.cream,
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: AppColors.sage,
      secondary: AppColors.honey,
      tertiary: AppColors.terracotta,
      surface: AppColors.warmWhite,
      error: AppColors.terracotta,
      onPrimary: Colors.white,
      onSecondary: AppColors.ink,
      onSurface: AppColors.ink,
      onError: Colors.white,
      onSurfaceVariant: AppColors.muted,
      outlineVariant: AppColors.border,
      outline: AppColors.borderMedium,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.cream,
      foregroundColor: AppColors.ink,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.sage,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.ink),
      bodyMedium: TextStyle(color: AppColors.charcoal),
      bodySmall: TextStyle(color: AppColors.muted),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.inputFill,
      border: OutlineInputBorder(
        borderSide: BorderSide.none,
        borderRadius: BorderRadius.circular(16),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide.none,
        borderRadius: BorderRadius.circular(16),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.sage.withValues(alpha: 0.3), width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

ThemeData darkTheme() {
  return ThemeData(
    primarySwatch: sageSwatch,
    primaryColor: AppColors.sage,
    scaffoldBackgroundColor: AppColors.darkBackground,
    useMaterial3: true,
    colorScheme: ColorScheme.dark(
      primary: AppColors.sage,
      secondary: AppColors.honey,
      tertiary: AppColors.terracotta,
      surface: AppColors.darkSurface,
      error: AppColors.terracotta,
      onPrimary: Colors.white,
      onSecondary: AppColors.lightInk,
      onSurface: AppColors.lightInk,
      onError: Colors.white,
      onSurfaceVariant: AppColors.darkMuted,
      outlineVariant: AppColors.darkBorder,
      outline: AppColors.darkBorderMedium,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkBackground,
      foregroundColor: AppColors.lightInk,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.sage,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.lightInk),
      bodyMedium: TextStyle(color: AppColors.lightCharcoal),
      bodySmall: TextStyle(color: AppColors.darkMuted),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkSurface,
      border: OutlineInputBorder(
        borderSide: BorderSide.none,
        borderRadius: BorderRadius.circular(16),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide.none,
        borderRadius: BorderRadius.circular(16),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.sage.withValues(alpha: 0.3), width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
