// ============================================
// FILE: lib/config/theme.dart
// PURPOSE: App-wide colors, theme, helper methods
// ============================================

import 'package:flutter/material.dart';

class AppTheme {
  // ==========================================
  // CORE COLORS
  // ==========================================
  static const Color primaryColor = Color(0xFF2196F3); // Blue
  static const Color primaryDark = Color(0xFF1565C0); // Dark Blue
  static const Color primaryLight = Color(0xFFBBDEFB); // Light Blue

  static const Color successColor = Color(0xFF4CAF50); // Green
  static const Color errorColor = Color(0xFFF44336); // Red
  static const Color warningColor = Color(0xFFFFC107); // Amber
  static const Color infoColor = Color(0xFF2196F3); // Blue

  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color backgroundLight = backgroundColor; // alias
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color dividerColor = Color(0xFFE0E0E0);

  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFF9E9E9E);

  // ==========================================
  // JOB STATUS COLORS
  // ==========================================
  static const Color pendingColor = Color.fromARGB(255, 141, 139, 139); // Grey
  static const Color assignedColor = Color(0xFF2196F3); // Blue
  static const Color inProgressColor = Color(0xFFFF9800); // Orange
  static const Color completedColor = Color(0xFF4CAF50); // Green
  static const Color cancelledColor = Color(0xFFF44336); // Red

  // ==========================================
  // STATUS COLOR HELPER
  // ==========================================
  static Color getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color.fromARGB(255, 255, 0, 0);
      case 'assigned':
        return assignedColor;
      case 'in_progress':
        return inProgressColor;
      case 'completed':
        return completedColor;
      case 'cancelled':
        return const Color.fromARGB(255, 178, 178, 178);
      default:
        return const Color.fromARGB(255, 255, 0, 0);
    }
  }

  // ==========================================
  // PRIORITY COLOR HELPER
  // ==========================================
  static Color getPriorityColor(String priority) {
    switch (priority) {
      case 'urgent':
        return const Color(0xFFF44336); // Red
      case 'high':
        return const Color(0xFFFF9800); // Orange
      case 'normal':
        return const Color(0xFF2196F3); // Blue
      case 'low':
        return const Color(0xFF9E9E9E); // Grey
      default:
        return const Color(0xFF2196F3);
    }
  }

  // ==========================================
  // JOB TYPE ICON HELPER
  // ==========================================
  static IconData getJobTypeIcon(String jobType) {
    switch (jobType) {
      case 'installation':
        return Icons.build_outlined;
      case 'delivery':
        return Icons.local_shipping_outlined;
      case 'maintenance':
        return Icons.construction_outlined;
      default:
        return Icons.work_outline;
    }
  }

  // ==========================================
  // LIGHT THEME
  // ==========================================
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: backgroundColor,

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),

      // Card
      cardTheme: CardThemeData(
        elevation: 2,
        color: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.zero,
      ),

      // ElevatedButton
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),

      // OutlinedButton
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),

      // TextButton
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primaryColor),
      ),

      // Input fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: errorColor),
        ),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textHint),
      ),

      // BottomNavigationBar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: textSecondary,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),

      // FAB
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),

      // Divider
      dividerTheme: const DividerThemeData(color: dividerColor, thickness: 1),
    );
  }
}
