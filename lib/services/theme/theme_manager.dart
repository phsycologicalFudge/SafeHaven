import 'package:flutter/material.dart';

enum SafeHavenThemeMode {
  light,
  black,
}

class SafeHavenThemeManager extends ChangeNotifier {
  SafeHavenThemeManager._();

  static final SafeHavenThemeManager instance = SafeHavenThemeManager._();

  SafeHavenThemeMode _mode = SafeHavenThemeMode.light;

  SafeHavenThemeMode get mode => _mode;

  bool get isDark => _mode == SafeHavenThemeMode.black;

  void setMode(SafeHavenThemeMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
  }

  void toggle() {
    setMode(isDark ? SafeHavenThemeMode.light : SafeHavenThemeMode.black);
  }
}

class SafeHavenColors {
  const SafeHavenColors({
    required this.background,
    required this.surface,
    required this.surfaceSoft,
    required this.border,
    required this.text,
    required this.textSoft,
    required this.textMuted,
    required this.navBackground,
    required this.navBorder,
    required this.accentStart,
    required this.accentEnd,
    required this.iconBackground,
    required this.buttonText,
  });

  final Color background;
  final Color surface;
  final Color surfaceSoft;
  final Color border;
  final Color text;
  final Color textSoft;
  final Color textMuted;
  final Color navBackground;
  final Color navBorder;
  final Color accentStart;
  final Color accentEnd;
  final Color iconBackground;
  final Color buttonText;

  LinearGradient get accentGradient {
    return LinearGradient(
      begin: Alignment.bottomLeft,
      end: Alignment.topRight,
      colors: [accentStart, accentEnd],
    );
  }

  BoxDecoration get gradientPill {
    return BoxDecoration(
      gradient: accentGradient,
      borderRadius: BorderRadius.circular(99),
    );
  }
}

class SafeHavenTheme {
  static const light = SafeHavenColors(
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceSoft: Color(0xFFF7F7FA),
    border: Color(0xFFE7E8EE),
    text: Color(0xFF18181C),
    textSoft: Color(0xFF4A4D57),
    textMuted: Color(0xFF7B7F8A),
    navBackground: Color(0xFFFFFFFF),
    navBorder: Color(0xFFE7E8EE),
    accentStart: Color(0xFF135DFF),
    accentEnd: Color(0xFF8A32F4),
    iconBackground: Color(0xFFF4F5F8),
    buttonText: Color(0xFFFFFFFF),
  );

  static const black = SafeHavenColors(
    background: Color(0xFF0B0B10),
    surface: Color(0xFF12131A),
    surfaceSoft: Color(0xFF191B24),
    border: Color(0xFF272A34),
    text: Color(0xFFF6F7FB),
    textSoft: Color(0xFFD8DBE3),
    textMuted: Color(0xFF9BA0AD),
    navBackground: Color(0xFF0F1016),
    navBorder: Color(0xFF232632),
    accentStart: Color(0xFF135DFF),
    accentEnd: Color(0xFF8A32F4),
    iconBackground: Color(0xFF1B1E27),
    buttonText: Color(0xFFFFFFFF),
  );

  static SafeHavenColors of(BuildContext context) {
    return SafeHavenThemeManager.instance.isDark ? black : light;
  }
}