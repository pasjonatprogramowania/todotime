import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String prefKeyThemeMode = 'themeMode'; // Ten sam klucz co w SettingsScreen

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system; // Domyślny

  ThemeProvider() {
    _loadThemeMode();
  }

  ThemeMode get themeMode => _themeMode;

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    int themeModeIndex = prefs.getInt(prefKeyThemeMode) ?? ThemeMode.system.index;
    // Upewnij się, że index jest w zakresie ThemeMode.values
    if (themeModeIndex < 0 || themeModeIndex >= ThemeMode.values.length) {
        themeModeIndex = ThemeMode.system.index;
    }
    _themeMode = ThemeMode.values[themeModeIndex];
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return; // Bez zmian

    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(prefKeyThemeMode, mode.index);
    notifyListeners();
    print("ThemeProvider: Theme mode set to $mode and saved.");
  }
}
