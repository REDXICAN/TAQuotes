// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import '../utils/responsive_helper.dart';

class AppTheme {
  static ThemeData getTheme(Brightness brightness, [BuildContext? context]) {
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
        elevation: context != null ? ResponsiveHelper.getElevation(context, baseElevation: isDark ? 0 : 2) : (isDark ? 0 : 2),
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: context != null ? ResponsiveHelper.getResponsiveFontSize(context, baseFontSize: 20, minFontSize: 18, maxFontSize: 24) : 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),

      // Card theme  
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: context != null ? ResponsiveHelper.getElevation(context, baseElevation: isDark ? 2 : 1) : (isDark ? 2 : 1),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            context != null ? ResponsiveHelper.getBorderRadius(context, baseRadius: 12) : 12,
          ),
        ),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            context != null ? ResponsiveHelper.getBorderRadius(context) : 8,
          ),
          borderSide: BorderSide(
            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            context != null ? ResponsiveHelper.getBorderRadius(context) : 8,
          ),
          borderSide: BorderSide(
            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            context != null ? ResponsiveHelper.getBorderRadius(context) : 8,
          ),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF4A6EC5) : const Color(0xFF20429C),
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            context != null ? ResponsiveHelper.getBorderRadius(context) : 8,
          ),
          borderSide: const BorderSide(
            color: Colors.red,
          ),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: context != null ? ResponsiveHelper.getSpacing(context, large: 16) : 16,
          vertical: context != null ? ResponsiveHelper.getSpacing(context, medium: 14) : 14,
        ),
      ),

      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isDark ? const Color(0xFF4A6EC5) : const Color(0xFF20429C),
          foregroundColor: Colors.white,
          elevation: context != null ? ResponsiveHelper.getElevation(context, baseElevation: 0) : 0,
          padding: EdgeInsets.symmetric(
            horizontal: context != null ? ResponsiveHelper.getSpacing(context, large: 24) : 24,
            vertical: context != null ? ResponsiveHelper.getSpacing(context, medium: 12) : 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              context != null ? ResponsiveHelper.getBorderRadius(context) : 8,
            ),
          ),
          minimumSize: context != null ? Size(
            ResponsiveHelper.getTouchTargetSize(context),
            ResponsiveHelper.getTouchTargetSize(context),
          ) : null,
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

      // Text theme with responsive sizing
      textTheme: _getResponsiveTextTheme(isDark, context),

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
              fontSize: context != null ? ResponsiveHelper.getResponsiveFontSize(context, baseFontSize: 12, minFontSize: 10, maxFontSize: 14) : 12,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF4A6EC5) : const Color(0xFF20429C),
            );
          }
          return TextStyle(
            fontSize: context != null ? ResponsiveHelper.getResponsiveFontSize(context, baseFontSize: 12, minFontSize: 10, maxFontSize: 14) : 12,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.grey[600] : Colors.grey[700],
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final iconSize = context != null ? ResponsiveHelper.getIconSize(context, baseSize: 24) : 24.0;
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(
              color: isDark ? const Color(0xFF4A6EC5) : const Color(0xFF20429C),
              size: iconSize,
            );
          }
          return IconThemeData(
            color: isDark ? Colors.grey[600] : Colors.grey[700],
            size: iconSize,
          );
        }),
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontSize: context != null ? ResponsiveHelper.getResponsiveFontSize(context, baseFontSize: 20, minFontSize: 18, maxFontSize: 24) : 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(
          color: isDark ? Colors.grey[300] : Colors.grey[700],
          fontSize: context != null ? ResponsiveHelper.getResponsiveFontSize(context, baseFontSize: 14, minFontSize: 12, maxFontSize: 16) : 14,
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
  
  // Helper method to create responsive text theme
  static TextTheme _getResponsiveTextTheme(bool isDark, BuildContext? context) {
    return TextTheme(
      headlineLarge: TextStyle(
        color: isDark ? Colors.white : Colors.black,
        fontSize: context != null ? ResponsiveHelper.getResponsiveFontSize(context, baseFontSize: 32, minFontSize: 28, maxFontSize: 40) : 32,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.25,
      ),
      headlineMedium: TextStyle(
        color: isDark ? Colors.white : Colors.black,
        fontSize: context != null ? ResponsiveHelper.getResponsiveFontSize(context, baseFontSize: 28, minFontSize: 24, maxFontSize: 34) : 28,
        fontWeight: FontWeight.w400,
      ),
      headlineSmall: TextStyle(
        color: isDark ? Colors.white : Colors.black,
        fontSize: context != null ? ResponsiveHelper.getResponsiveFontSize(context, baseFontSize: 24, minFontSize: 20, maxFontSize: 28) : 24,
        fontWeight: FontWeight.w400,
      ),
      titleLarge: TextStyle(
        color: isDark ? Colors.white : Colors.black,
        fontSize: context != null ? ResponsiveHelper.getResponsiveFontSize(context, baseFontSize: 22, minFontSize: 18, maxFontSize: 26) : 22,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
      titleMedium: TextStyle(
        color: isDark ? Colors.white : Colors.black,
        fontSize: context != null ? ResponsiveHelper.getResponsiveFontSize(context, baseFontSize: 16, minFontSize: 14, maxFontSize: 20) : 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.15,
      ),
      titleSmall: TextStyle(
        color: isDark ? Colors.white : Colors.black,
        fontSize: context != null ? ResponsiveHelper.getResponsiveFontSize(context, baseFontSize: 14, minFontSize: 12, maxFontSize: 16) : 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
      bodyLarge: TextStyle(
        color: isDark ? Colors.grey[200] : Colors.grey[800],
        fontSize: context != null ? ResponsiveHelper.getResponsiveFontSize(context, baseFontSize: 16, minFontSize: 14, maxFontSize: 18) : 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
      ),
      bodyMedium: TextStyle(
        color: isDark ? Colors.grey[300] : Colors.grey[700],
        fontSize: context != null ? ResponsiveHelper.getResponsiveFontSize(context, baseFontSize: 14, minFontSize: 12, maxFontSize: 16) : 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
      ),
      bodySmall: TextStyle(
        color: isDark ? Colors.grey[400] : Colors.grey[600],
        fontSize: context != null ? ResponsiveHelper.getResponsiveFontSize(context, baseFontSize: 12, minFontSize: 10, maxFontSize: 14) : 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
      ),
      labelLarge: TextStyle(
        color: isDark ? Colors.grey[200] : Colors.grey[800],
        fontSize: context != null ? ResponsiveHelper.getResponsiveFontSize(context, baseFontSize: 14, minFontSize: 12, maxFontSize: 16) : 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
      labelMedium: TextStyle(
        color: isDark ? Colors.grey[300] : Colors.grey[700],
        fontSize: context != null ? ResponsiveHelper.getResponsiveFontSize(context, baseFontSize: 12, minFontSize: 10, maxFontSize: 14) : 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
      labelSmall: TextStyle(
        color: isDark ? Colors.grey[400] : Colors.grey[600],
        fontSize: context != null ? ResponsiveHelper.getResponsiveFontSize(context, baseFontSize: 11, minFontSize: 9, maxFontSize: 13) : 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
    );
  }
}
