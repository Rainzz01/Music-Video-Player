import 'package:flutter/material.dart';

ThemeData lightMode = ThemeData(
  brightness: Brightness.light,
  colorScheme: ColorScheme.light(
    surface: Colors.grey.shade200,
    primary: Colors.blueGrey.shade700,
    secondary: Colors.blueGrey.shade500,
    inversePrimary: Colors.black87, // Darker text/icons
  ),
  scaffoldBackgroundColor: Colors.grey.shade300,
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.grey.shade300,
    foregroundColor: Colors.grey.shade900,
    elevation: 0,
  ),
  textTheme: const TextTheme(
    headlineSmall: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
    titleMedium: TextStyle(color: Colors.grey, fontSize: 16),
    bodyMedium: TextStyle(color: Colors.black),
  ),
  iconTheme: IconThemeData(color: Colors.grey.shade500),
  sliderTheme: SliderThemeData(
    thumbColor: Colors.grey.shade500,
    activeTrackColor: Colors.grey.shade500,
    inactiveTrackColor: Colors.grey.shade200,
  ),
  useMaterial3: true,
);