import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class ThemeOption extends StatelessWidget {
  final String title;
  final AppThemeMode mode;

  const ThemeOption({super.key, required this.title, required this.mode});

  @override
  Widget build(BuildContext context) {
    return RadioListTile<AppThemeMode>(
      title: Text(title),
      value: mode,
      groupValue: appThemeNotifier.value,
      activeColor: Theme.of(context).primaryColor,
      onChanged: (val) async {
        if (val != null) {
          final navigator = Navigator.of(context);
          appThemeNotifier.value = val;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('theme_mode', AppThemeMode.values.indexOf(val));
          navigator.pop();
        }
      },
    );
  }
}
