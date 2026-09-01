import 'package:flutter/material.dart';

class AppTheme {
  // Teal-green seed — feels financial without being boring bank-blue.
  static const _seed = Color(0xFF00897B);

  static final light = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: _seed),
  );

  static final dark = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    ),
  );
}
