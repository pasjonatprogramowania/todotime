import 'package:flutter/material.dart';
import 'package:myapp/utils/permissions_manager.dart';
import 'package:myapp/services/background_service_handler.dart';
import 'package:myapp/screens/dashboard_screen.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  PermissionsManager permissionsManager = PermissionsManager();
  await permissionsManager.ensurePermissions();

  await initializeBackgroundService();

  // Uruchomienie aplikacji z ChangeNotifierProvider dla ThemeProvider
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Definicje motywów (tak jak były wcześniej)
    const Color darkPrimaryBg = Color(0xFF121212);
    const Color darkCardBg = Color(0xFF1E1E1E);
    const Color darkAccentColor = Color(0xFF4CAF50);
    const Color darkMainText = Color(0xFFE0E0E0);
    const Color darkSecondaryText = Color(0xFFA0A0A0);

    const Color lightPrimaryBg = Color(0xFFFFFFFF);
    const Color lightCardBg = Color(0xFFF0F0F0);
    const Color lightAccentColor = Color(0xFF00C853);
    const Color lightMainText = Color(0xFF000000);
    const Color lightSecondaryText = Color(0xFF505050);

    ThemeData darkTheme = ThemeData(
      brightness: Brightness.dark,
      primaryColor: darkAccentColor,
      scaffoldBackgroundColor: darkPrimaryBg,
      cardColor: darkCardBg,
      hintColor: darkAccentColor,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: darkMainText),
        bodyMedium: TextStyle(color: darkMainText),
        titleMedium: TextStyle(color: darkSecondaryText),
        headlineLarge: TextStyle(color: darkMainText, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: darkMainText, fontWeight: FontWeight.bold),
        headlineSmall: TextStyle(color: darkMainText, fontWeight: FontWeight.bold),
      ),
      colorScheme: ColorScheme.dark(
        primary: darkAccentColor,
        secondary: darkAccentColor,
        surface: darkCardBg,
        background: darkPrimaryBg,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: darkMainText,
        onBackground: darkMainText,
        error: Colors.redAccent,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkPrimaryBg,
        elevation: 0,
        iconTheme: IconThemeData(color: darkAccentColor),
        titleTextStyle: TextStyle(color: darkMainText, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: darkAccentColor,
        foregroundColor: Colors.black,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return darkAccentColor;
          return darkSecondaryText;
        }),
        checkColor: WidgetStateProperty.all(Colors.black),
        side: BorderSide(color: darkAccentColor, width: 2),
      ),
    );

    ThemeData lightTheme = ThemeData(
      brightness: Brightness.light,
      primaryColor: lightAccentColor,
      scaffoldBackgroundColor: lightPrimaryBg,
      cardColor: lightCardBg,
      hintColor: lightAccentColor,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: lightMainText),
        bodyMedium: TextStyle(color: lightMainText),
        titleMedium: TextStyle(color: lightSecondaryText),
        headlineLarge: TextStyle(color: lightMainText, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: lightMainText, fontWeight: FontWeight.bold),
        headlineSmall: TextStyle(color: lightMainText, fontWeight: FontWeight.bold),
      ),
       colorScheme: ColorScheme.light(
        primary: lightAccentColor,
        secondary: lightAccentColor,
        surface: lightCardBg,
        background: lightPrimaryBg,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: lightMainText,
        onBackground: lightMainText,
        error: Colors.red,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightPrimaryBg,
        elevation: 0,
        iconTheme: IconThemeData(color: lightAccentColor),
        titleTextStyle: TextStyle(color: lightMainText, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: lightAccentColor,
        foregroundColor: Colors.white,
      ),
       checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return lightAccentColor;
          return lightSecondaryText;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: BorderSide(color: lightAccentColor, width: 2),
      ),
    );

    // Pobierz aktualny ThemeMode od ThemeProvider
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'TaskTime',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeProvider.themeMode, // Użyj themeMode z providera
      home: const DashboardScreen(),
    );
  }
}
