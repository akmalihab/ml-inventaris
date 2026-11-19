import 'package:flutter/material.dart';

class ThemeService {
  ThemeService._();
  static final ThemeService instance = ThemeService._();

  final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

  bool get isDarkMode => themeModeNotifier.value == ThemeMode.dark;

  void toggleTheme() {
    themeModeNotifier.value = isDarkMode ? ThemeMode.light : ThemeMode.dark;
  }

  void setThemeMode(ThemeMode mode) {
    themeModeNotifier.value = mode;
  }
}
