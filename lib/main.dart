import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/language_config.dart';
import 'pages/livros_page.dart';
import 'services/language_service.dart';
import 'settings/theme_selector_page.dart';
import 'themes/themes.dart';

void main() {
  runApp(const BibliaApp());
}

class BibliaApp extends StatefulWidget {
  const BibliaApp({super.key});

  @override
  State<BibliaApp> createState() => _BibliaAppState();
}

class _BibliaAppState extends State<BibliaApp> {
  String _currentThemeKey = 'Green';
  bool _isDarkMode = false;
  ThemeData _currentTheme = appThemes[0].light;
  double _fontSize = 16.0;
  LanguageConfig _languageConfig = LanguageConfig(
    primaryTranslation: LanguageService.defaultPrimary,
    secondaryTranslation: LanguageService.defaultSecondary,
  );

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final themeKey = prefs.getString('selectedTheme') ?? 'Green';
    final isDark = prefs.getBool('isDarkMode') ?? false;
    final savedFontSize = prefs.getDouble('fontSize') ?? 16.0;

    final theme = appThemes.firstWhere(
      (t) => t.name == themeKey,
      orElse: () => appThemes[0],
    );
    final selectedTheme = isDark ? theme.dark : theme.light;

    final langConfig = await LanguageService.getLanguageConfig();

    setState(() {
      _currentThemeKey = themeKey;
      _isDarkMode = isDark;
      _fontSize = savedFontSize;
      _currentTheme = selectedTheme;
      _languageConfig = langConfig;
    });
  }

  Future<void> _changeTheme(
    String themeName,
    bool isDark,
    double fontSize,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedTheme', themeName);
    await prefs.setBool('isDarkMode', isDark);
    await prefs.setDouble('fontSize', fontSize);

    final theme = appThemes.firstWhere(
      (t) => t.name == themeName,
      orElse: () => appThemes[0],
    );
    final selectedTheme = isDark ? theme.dark : theme.light;

    setState(() {
      _currentThemeKey = themeName;
      _isDarkMode = isDark;
      _fontSize = fontSize;
      _currentTheme = selectedTheme;
    });
  }

  ThemeData applyFontSize(ThemeData baseTheme, double fontSize) {
    final textTheme = baseTheme.textTheme;

    return baseTheme.copyWith(
      textTheme: textTheme.copyWith(
        bodySmall: textTheme.bodySmall?.copyWith(fontSize: fontSize),
        bodyMedium: textTheme.bodyMedium?.copyWith(fontSize: fontSize),
        bodyLarge: textTheme.bodyLarge?.copyWith(fontSize: fontSize),
        titleMedium: textTheme.titleMedium?.copyWith(fontSize: fontSize + 2),
        titleLarge: textTheme.titleLarge?.copyWith(fontSize: fontSize + 4),
        labelLarge: textTheme.labelLarge?.copyWith(fontSize: fontSize - 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bíblia App',
      theme: applyFontSize(_currentTheme, _fontSize),
      home: LivrosPage(
        languageConfig: _languageConfig,
        onChangeLanguageConfig: (config) {
          setState(() {
            _languageConfig = config;
          });
        },
        onToggleTheme: (context) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ThemeSettingsPage(
                selectedThemeName: _currentThemeKey,
                isDarkMode: _isDarkMode,
                initialFontSize: _fontSize,
                onApply: (themeName, isDark, fontSize) {
                  _changeTheme(themeName, isDark, fontSize);
                  Navigator.pop(context);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
