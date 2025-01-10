import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadThemePreference();
  }

  /// Load the saved theme preference from SharedPreferences
  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('isDarkMode')) {
      
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    } else {
      // Check the system theme if no preference is saved
      final brightness = PlatformDispatcher.instance.platformBrightness;
      _isDarkMode = brightness == Brightness.dark;
    }
    notifyListeners();
  }

  /// Toggle theme and persist the choice
  Future<void> toggleTheme(bool isOn) async {
    _isDarkMode = isOn;
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('isDarkMode', _isDarkMode);
    notifyListeners();
  }
}
