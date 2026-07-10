import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme/app_theme.dart';
import 'screens/auth_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final prefs = await SharedPreferences.getInstance();
  final themeIndex = prefs.getInt('theme_mode') ?? 2;
  appThemeNotifier.value = AppThemeMode.values[themeIndex];
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  ThemeData _getThemeData(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return ThemeData(
          brightness: Brightness.light,
          primaryColor: AppColors.lightPrimary,
          scaffoldBackgroundColor: AppColors.lightBackground,
          cardColor: AppColors.lightSurface,
          colorScheme: const ColorScheme.light(
              primary: AppColors.lightPrimary,
              secondary: Colors.tealAccent,
              surface: AppColors.lightSurface),
          appBarTheme: const AppBarTheme(
              backgroundColor: AppColors.lightPrimary,
              foregroundColor: Colors.white,
              elevation: 0),
          textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme)
              .apply(
                  bodyColor: AppColors.lightTextPrimary,
                  displayColor: AppColors.lightTextPrimary),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
              backgroundColor: AppColors.lightPrimary,
              foregroundColor: Colors.white),
        );
      case AppThemeMode.darkMaterial:
        return ThemeData(
          brightness: Brightness.dark,
          primaryColor: AppColors.darkPrimary,
          scaffoldBackgroundColor: AppColors.darkMaterialBackground,
          cardColor: AppColors.darkMaterialSurface,
          colorScheme: const ColorScheme.dark(
              primary: AppColors.darkPrimary,
              secondary: AppColors.darkAccent,
              surface: AppColors.darkMaterialSurface),
          appBarTheme: const AppBarTheme(
              backgroundColor: AppColors.darkMaterialBackground,
              foregroundColor: Colors.white,
              elevation: 0),
          textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme)
              .apply(
                  bodyColor: AppColors.darkTextPrimary,
                  displayColor: AppColors.darkTextPrimary),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
              backgroundColor: AppColors.darkPrimary,
              foregroundColor: Colors.white),
        );
      case AppThemeMode.darkAmoled:
        return ThemeData(
          brightness: Brightness.dark,
          primaryColor: AppColors.darkPrimary,
          scaffoldBackgroundColor: AppColors.amoledBackground,
          cardColor: AppColors.amoledSurface,
          colorScheme: const ColorScheme.dark(
              primary: AppColors.darkPrimary,
              secondary: AppColors.darkAccent,
              surface: AppColors.amoledSurface),
          appBarTheme: const AppBarTheme(
              backgroundColor: AppColors.amoledBackground,
              foregroundColor: Colors.white,
              elevation: 0),
          textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme)
              .apply(
                  bodyColor: AppColors.darkTextPrimary,
                  displayColor: AppColors.darkTextPrimary),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
              backgroundColor: AppColors.darkPrimary,
              foregroundColor: Colors.white),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
    return ValueListenableBuilder<AppThemeMode>(
      valueListenable: appThemeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'Password Manager',
          debugShowCheckedModeBanner: false,
          theme: _getThemeData(themeMode),
          home: const AuthScreen(),
        );
      },
    );
  }
}