import 'package:flutter/material.dart';

class AppColors {
  // Primary colors
  static const Color primary = Color(0xFF6A8CAF); // Soft blue
  static const Color primaryLight = Color(0xFF9FB7D0);
  static const Color primaryDark = Color(0xFF436590);

  // Accent colors
  static const Color accent = Color(0xFFECC30B); // Warm yellow
  static const Color accentLight = Color(0xFFF5D657);
  static const Color accentDark = Color(0xFFD6AE0B);

  // Functional colors
  static const Color success = Color(0xFF66BB6A);
  static const Color error = Color(0xFFEF5350);
  static const Color warning = Color(0xFFFFCA28);
  static const Color info = Color(0xFF29B6F6);

  // Neutral colors
  static const Color background = Color(0xFFF9F9FB);
  static const Color surface = Colors.white;
  static const Color cardBackground = Colors.white;

  // Text colors
  static const Color textPrimary = Color(0xFF263238);
  static const Color textSecondary = Color(0xFF607D8B);
  static const Color textLight = Color(0xFF90A4AE);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryLight, primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accentLight, accent, accentDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Medal colors for points
  static const Color goldMedal = Color(0xFFFFC107);
  static const Color silverMedal = Color(0xFFB0BEC5);
  static const Color bronzeMedal = Color(0xFFBF8970);
}
