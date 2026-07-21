import 'package:flutter/material.dart';

abstract final class AppColors {
  static const canvas = Color(0xff101722);
  static const navigation = Color(0xff172230);
  static const surface = Color(0xff1d2a3a);
  static const surfaceRaised = Color(0xff243448);
  static const outline = Color(0xff38516b);
  static const primary = Color(0xff71c7f4);
  static const primaryMuted = Color(0xff25587b);
  static const text = Color(0xfff4f8fb);
  static const textMuted = Color(0xff9eb0c2);
  static const success = Color(0xff58d6a7);
  static const warning = Color(0xffffc66d);
  static const danger = Color(0xffff7e8a);
}

abstract final class AppSpacing {
  static const xs = 6.0;
  static const sm = 10.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

abstract final class BAPlannerTheme {
  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
      surface: AppColors.surface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.canvas,
      fontFamily: 'GyeonggiTitle',
      dividerColor: AppColors.outline,
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          side: BorderSide(color: AppColors.outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: AppColors.outline),
        ),
      ),
    );
  }
}
