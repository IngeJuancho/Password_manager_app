import 'package:flutter/material.dart';

enum PasswordStrength { muyDebil, debil, media, fuerte, muyFuerte }

class PasswordStrengthAnalyzer {
  static PasswordStrength analyzePassword(String password) {
    if (password.isEmpty) return PasswordStrength.muyDebil;
    int score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (password.contains(RegExp(r'[A-Z]'))) score++;
    if (password.contains(RegExp(r'[a-z]'))) score++;
    if (password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[!@#$%^&*()_+\-=\[\]{}|;:,.<>?]'))) score++;
    
    if (score <= 1) return PasswordStrength.muyDebil;
    if (score <= 2) return PasswordStrength.debil;
    if (score <= 4) return PasswordStrength.media;
    if (score <= 5) return PasswordStrength.fuerte;
    return PasswordStrength.muyFuerte;
  }

  static Color getStrengthColor(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.muyDebil:
        return Colors.redAccent;
      case PasswordStrength.debil:
        return Colors.orangeAccent;
      case PasswordStrength.media:
        return Colors.yellowAccent;
      case PasswordStrength.fuerte:
        return Colors.lightGreenAccent;
      case PasswordStrength.muyFuerte:
        return Colors.greenAccent;
    }
  }
}
