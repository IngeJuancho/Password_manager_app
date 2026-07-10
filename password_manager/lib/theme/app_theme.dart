import 'package:flutter/material.dart';

enum AppThemeMode { light, darkMaterial, darkAmoled }

final ValueNotifier<AppThemeMode> appThemeNotifier = ValueNotifier(AppThemeMode.darkAmoled);

class AppColors {
  static const Color lightBackground  = Color(0xFFF2F4F8);
  static const Color lightSurface     = Colors.white;
  static const Color lightPrimary     = Color(0xFF4F46E5);
  static const Color lightTextPrimary = Color(0xFF1E293B);
  static const Color darkMaterialBackground = Color(0xFF121212);
  static const Color darkMaterialSurface    = Color(0xFF1E1E1E);
  static const Color darkPrimary  = Color(0xFF6366F1);
  static const Color darkAccent   = Color(0xFF00E5FF);
  static const Color amoledBackground = Color(0xFF000000);
  static const Color amoledSurface    = Color(0xFF0A0A0A);
  static const Color darkTextPrimary  = Color(0xFFF1F5F9);
}
