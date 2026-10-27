import 'package:flutter/material.dart';

class AppThemeModeController {
  static final ValueNotifier<ThemeMode> mode = ValueNotifier<ThemeMode>(
    ThemeMode.light,
  );

  static void setMode(ThemeMode _) {
    mode.value = ThemeMode.light;
  }

  static String modeLabel(ThemeMode _) => 'লাইট';
}
