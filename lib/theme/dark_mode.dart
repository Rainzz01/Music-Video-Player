import 'package:flutter/material.dart';

ThemeData darkMode = ThemeData(
  colorScheme: ColorScheme.dark(
    surface: Colors.grey.shade900,
    primary: Colors.blueAccent.withOpacity(0.8),
    secondary: Colors.purpleAccent.withOpacity(0.7),
    inversePrimary: Colors.grey.shade300,
  ),
  scaffoldBackgroundColor: Colors.grey.shade900,
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.grey.shade900,
    foregroundColor: Colors.white,
    elevation: 0,
  ),
  textTheme: const TextTheme(
    headlineSmall: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
    titleMedium: TextStyle(color: Colors.grey, fontSize: 16),
    bodyMedium: TextStyle(color: Colors.white),
  ),
  iconTheme: IconThemeData(color: Colors.blueAccent),
  sliderTheme: SliderThemeData(
    thumbColor: Colors.blueAccent,
    activeTrackColor: Colors.blueAccent,
    inactiveTrackColor: Colors.grey.shade700,
  ),
  useMaterial3: true,
);