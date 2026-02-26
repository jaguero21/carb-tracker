import 'package:flutter/material.dart';

/// CarpeCarb Brand Color Palette
/// A warm, natural color scheme designed for mindful carb tracking
class AppColors {
  AppColors._(); // Private constructor to prevent instantiation

  // Background Colors
  static const Color cream = Color(0xFFFAF7F2);
  static const Color warmWhite = Color(0xFFFFFEF9);

  // Primary Brand Colors - Sage
  static const Color sage = Color(0xFF7D9B76);
  static const Color sageLight = Color(0xFFA8C2A1);
  static const Color sageDark = Color(0xFF4D6B47);

  // Accent Colors
  static const Color terracotta = Color(0xFFD4714E);
  static const Color terracottaLight = Color(0xFFE8967A);

  static const Color honey = Color(0xFFE8A93C);
  static const Color honeyLight = Color(0xFFF2C56B);

  static const Color plum = Color(0xFF7B4F72);

  static const Color sky = Color(0xFF5B8DB8);
  static const Color skyLight = Color(0xFF85AECE);

  // Text Colors
  static const Color ink = Color(0xFF2A2520);
  static const Color charcoal = Color(0xFF3D3530);
  static const Color muted = Color(0xFF8A7D74);

  // UI Colors
  static const Color border = Color(0x142A2520); // rgba(42, 37, 32, 0.08)
  static const Color borderMedium = Color(0x332A2520); // ~20% opacity

  // Dark mode adaptive colors (used in darkTheme ThemeData only)
  static const Color darkBackground = Color(0xFF1A1714);
  static const Color darkSurface = Color(0xFF252019);
  static const Color lightInk = Color(0xFFF5EFE8);
  static const Color lightCharcoal = Color(0xFFDDD4CB);
  static const Color darkMuted = Color(0xFF9A8D84);
  static const Color darkBorder = Color(0x14F5EFE8);       // 8% opacity
  static const Color darkBorderMedium = Color(0x33F5EFE8); // 20% opacity

  // Glass effect colors (Liquid Glass-inspired)
  static const Color glassLight = Color(0x99FFFFFF);       // white 60%
  static const Color glassDark = Color(0x66252019);        // dark surface 40%
  static const Color glassBorderLight = Color(0x33FFFFFF); // white 20%
  static const Color glassBorderDark = Color(0x14F5EFE8);  // light 8%

  // Semantic Colors
  static const Color success = sage;
  static const Color warning = honey;
  static const Color error = terracotta;
  static const Color info = sky;

  // Gradient Definitions
  static const LinearGradient sageGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [sageLight, sageDark],
  );

  static const LinearGradient honeyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [honeyLight, honey],
  );

  static const LinearGradient terracottaGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [terracottaLight, terracotta],
  );
}

/// Material color swatch for sage (primary color)
/// Used by ThemeData for consistent Material Design integration
const MaterialColor sageSwatch = MaterialColor(
  0xFF7D9B76, // Base sage color
  <int, Color>{
    50: Color(0xFFF0F4EF),
    100: Color(0xFFDAE4D7),
    200: Color(0xFFC1D3BD),
    300: Color(0xFFA8C2A1),
    400: Color(0xFF95B58C),
    500: Color(0xFF7D9B76), // Primary sage
    600: Color(0xFF6F8A69),
    700: Color(0xFF5E765D),
    800: Color(0xFF4D6B47),
    900: Color(0xFF3A5235),
  },
);
