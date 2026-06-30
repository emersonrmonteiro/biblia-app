import 'package:flutter/material.dart';

class AppTheme {
  final String name;
  final Color color;
  final ThemeData light;
  final ThemeData dark;

  AppTheme({
    required this.name,
    required this.color,
    required this.light,
    required this.dark,
  });
}

final List<AppTheme> appThemes = [
  AppTheme(
    name: 'Green',
    color: Colors.green,
    light: ThemeData(
      brightness: Brightness.light,
      primarySwatch: Colors.green,
      scaffoldBackgroundColor: Colors.green[50],
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
    ),
    dark: ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.green,
        brightness: Brightness.dark,
      ),
    ),
  ),
  AppTheme(
    name: 'Purple',
    color: Colors.deepPurple,
    light: ThemeData(
      brightness: Brightness.light,
      primarySwatch: Colors.deepPurple,
      scaffoldBackgroundColor: Colors.deepPurple[50],
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
    ),
    dark: ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: Brightness.dark,
      ),
    ),
  ),
];
