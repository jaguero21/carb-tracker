import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// CarbWise Custom Icon Pack
/// Provides easy access to custom SVG icons with consistent sizing
class AppIcons {
  AppIcons._(); // Private constructor to prevent instantiation

  // Icon asset paths
  static const String _basePath = 'assets/icons/';

  static const String dashboard = '${_basePath}dashboard.svg';
  static const String addMeal = '${_basePath}add_meal.svg';
  static const String search = '${_basePath}search.svg';
  static const String history = '${_basePath}history.svg';
  static const String profile = '${_basePath}profile.svg';
  static const String settings = '${_basePath}settings.svg';
  static const String bookmark = '${_basePath}bookmark.svg';
  static const String trends = '${_basePath}trends.svg';
  static const String scan = '${_basePath}scan.svg';
  static const String nutrition = '${_basePath}nutrition.svg';
  static const String delete = '${_basePath}delete.svg';

  /// Helper method to load an SVG icon with consistent sizing
  ///
  /// Usage:
  /// ```dart
  /// AppIcons.icon(AppIcons.dashboard, size: 24, color: Colors.green)
  /// ```
  static Widget icon(
    String assetPath, {
    double size = 24.0,
    Color? color,
    BoxFit fit = BoxFit.contain,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.asset(
        assetPath,
        width: size,
        height: size,
        fit: fit,
        colorFilter: color != null
            ? ColorFilter.mode(color, BlendMode.srcIn)
            : null,
      ),
    );
  }

  /// Convenience widgets for commonly used icons
  static Widget dashboardIcon({double size = 24.0, Color? color}) =>
      icon(dashboard, size: size, color: color);

  static Widget addMealIcon({double size = 24.0, Color? color}) =>
      icon(addMeal, size: size, color: color);

  static Widget searchIcon({double size = 24.0, Color? color}) =>
      icon(search, size: size, color: color);

  static Widget historyIcon({double size = 24.0, Color? color}) =>
      icon(history, size: size, color: color);

  static Widget profileIcon({double size = 24.0, Color? color}) =>
      icon(profile, size: size, color: color);

  static Widget settingsIcon({double size = 24.0, Color? color}) =>
      icon(settings, size: size, color: color);

  static Widget bookmarkIcon({double size = 24.0, Color? color}) =>
      icon(bookmark, size: size, color: color);

  static Widget trendsIcon({double size = 24.0, Color? color}) =>
      icon(trends, size: size, color: color);

  static Widget scanIcon({double size = 24.0, Color? color}) =>
      icon(scan, size: size, color: color);

  static Widget nutritionIcon({double size = 24.0, Color? color}) =>
      icon(nutrition, size: size, color: color);

  static Widget deleteIcon({double size = 24.0, Color? color}) =>
      icon(delete, size: size, color: color);
}
