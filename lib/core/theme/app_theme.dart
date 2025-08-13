// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData getTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      brightness: brightness,
      useMaterial3: true,

      // Primary colors
      primaryColor: isDark ? const Color(0xFF4A6EC5) : const Color(0xFF20429C),
      primaryColorDark: const Color(0xFF1A3478),
      primaryColorLight: const Color(0xFF6B8ADB),

      // Color scheme
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF20429C),
        brightness: brightness,
      ),

      // Scaffold background
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF121212) : Colors.grey[50],

      // AppBar theme
      appBarTheme: AppBarTheme(
        backgroundColor:
            isDark ? const Color(0xFF1E1E1E) : const Color(0xFF20429C),
        foregroundColor: Colors.white,
        elevation: isDark ? 0 : 2,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),

      // Card theme  
      cardTheme: CardTheme(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: isDark ? 2 : 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF4A6EC5) : const Color(0xFF20429C),
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: Colors.red,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isDark ? const Color(0xFF4A6EC5) : const Color(0xFF20429C),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      // Outlined button theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor:
              isDark ? const Color(0xFF4A6EC5) : const Color(0xFF20429C),
          side: BorderSide(
            color: isDark ? const Color(0xFF4A6EC5) : const Color(0xFF20429C),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      // Text button theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor:
              isDark ? const Color(0xFF4A6EC5) : const Color(0xFF20429C),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),

      // Icon theme
      iconTheme: IconThemeData(
        color: isDark ? Colors.grey[300] : Colors.grey[700],
      ),

      // Text theme
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          color: isDark ? Colors.white : Colors.black,
        ),
        headlineMedium: TextStyle(
          color: isDark ? Colors.white : Colors.black,
        ),
        headlineSmall: TextStyle(
          color: isDark ? Colors.white : Colors.black,
        ),
        titleLarge: TextStyle(
          color: isDark ? Colors.white : Colors.black,
        ),
        titleMedium: TextStyle(
          color: isDark ? Colors.white : Colors.black,
        ),
        titleSmall: TextStyle(
          color: isDark ? Colors.white : Colors.black,
        ),
        bodyLarge: TextStyle(
          color: isDark ? Colors.grey[200] : Colors.grey[800],
        ),
        bodyMedium: TextStyle(
          color: isDark ? Colors.grey[300] : Colors.grey[700],
        ),
        bodySmall: TextStyle(
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        selectedItemColor:
            isDark ? const Color(0xFF4A6EC5) : const Color(0xFF20429C),
        unselectedItemColor: isDark ? Colors.grey[600] : Colors.grey[700],
      ),

      // Navigation Bar Theme (Material 3)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        indicatorColor: isDark
            ? const Color(0xFF4A6EC5).withOpacity(0.2)
            : const Color(0xFF20429C).withOpacity(0.1),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF4A6EC5) : const Color(0xFF20429C),
            );
          }
          return TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.grey[600] : Colors.grey[700],
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(
              color: isDark ? const Color(0xFF4A6EC5) : const Color(0xFF20429C),
            );
          }
          return IconThemeData(
            color: isDark ? Colors.grey[600] : Colors.grey[700],
          );
        }),
      ),

      // Dialog Theme
      dialogTheme: DialogTheme(
        backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(
          color: isDark ? Colors.grey[300] : Colors.grey[700],
          fontSize: 14,
        ),
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor:
            isDark ? const Color(0xFF4A6EC5) : const Color(0xFF20429C),
        foregroundColor: Colors.white,
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey[100]!,
        labelStyle: TextStyle(
          color: isDark ? Colors.grey[300] : Colors.grey[700],
        ),
        side: BorderSide(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
        ),
      ),

      // Badge Theme
      badgeTheme: const BadgeThemeData(
        backgroundColor: Colors.red,
        textColor: Colors.white,
      ),

      // Divider Theme
      dividerTheme: DividerThemeData(
        color: isDark ? Colors.grey[800] : Colors.grey[300],
        thickness: 1,
      ),

      // List Tile Theme
      listTileTheme: ListTileThemeData(
        tileColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        iconColor: isDark ? Colors.grey[400] : Colors.grey[600],
      ),

      // Snackbar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor:
            isDark ? const Color(0xFF2C2C2C) : const Color(0xFF323232),
        contentTextStyle: const TextStyle(color: Colors.white),
        actionTextColor:
            isDark ? const Color(0xFF4A6EC5) : const Color(0xFF7BA7E7),
      ),
    );
  }
}
