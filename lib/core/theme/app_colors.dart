import 'package:flutter/material.dart';

class AppColors {
  // Primary (Brand Blue)
  static const Color primary = Color(0xFF0056B3);
  static const Color primaryContainer = Color(0xFFD7E2FF);
  static const Color onPrimary = Colors.white;
  static const Color onPrimaryContainer = Color(0xFF001A40);

  // Secondary (Success/Paid)
  static const Color secondary = Color(0xFF006E25);
  static const Color secondaryContainer = Color(0xFF80F98B);
  static const Color onSecondary = Colors.white;
  static const Color onSecondaryContainer = Color(0xFF002106);

  // Error (Debt/Alert)
  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onError = Colors.white;
  static const Color onErrorContainer = Color(0xFF93000A);

  // Surface & Background (Tonal Layers)
  static const Color background = Color(0xFFF7F9FF);
  static const Color onBackground = Color(0xFF181C20);
  
  static const Color surface = Color(0xFFF7F9FF);
  static const Color surfaceContainerLow = Color(0xFFF1F4FA);
  static const Color surfaceContainerHigh = Color(0xFFE5E8EE);
  static const Color surfaceContainerHighest = Color(0xFFE5E8EE);
  static const Color surfaceContainerLowest = Colors.white;
  
  static const Color onSurface = Color(0xFF181C20);
  static const Color onSurfaceVariant = Color(0xFF424752); // Muted text

  // Border & Dividers
  static const Color outline = Color(0xFF727784);
  static const Color outlineVariant = Color(0xFFC2C6D4);
  
  // Tertiary Colors
  static const Color tertiary = Color(0xFF88001c);
  static const Color onTertiary = Color(0xFFffffff);
  static const Color tertiaryContainer = Color(0xFFb10f2b);
  static const Color onTertiaryContainer = Color(0xFFffc0bf);
  
  // Fixed Primary Colors
  static const Color primaryFixed = Color(0xFFd7e2ff);
  static const Color onPrimaryFixed = Color(0xFF001a40);
  static const Color onPrimaryFixedVariant = Color(0xFF004491);
  static const Color primaryFixedDim = Color(0xFFacc7ff);
  
  // Custom Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF003F87), // Darker Primary
      Color(0xFF0056B3), // Primary
    ],
  );
}
