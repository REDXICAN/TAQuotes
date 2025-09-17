// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import '../utils/responsive_helper.dart';

class AppTheme {
  // Apple Dark Mode Colors
  static const Color bgPrimary = Color(0xFF000000);
  static const Color bgElevated = Color(0xFF1C1C1E);
  static const Color bgSecondary = Color(0xFF2C2C2E);
  static const Color bgTertiary = Color(0xFF3A3A3C);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFEBEBF5);
  static const Color textTertiary = Color(0xFF8E8E93);
  static const Color accentPrimary = Color(0xFF007AFF);
  static const Color accentSecondary = Color(0xFF5AC8FA);
  static const Color errorColor = Color(0xFFFF3B30);
  static const Color successColor = Color(0xFF34C759);
  static const Color warningColor = Color(0xFFFF9500);
  
  static ThemeData getTheme(Brightness brightness, [BuildContext? context]) {
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      brightness: brightness,
      useMaterial3: true,

      // Primary colors - Apple style
      primaryColor: isDark ? accentPrimary : const Color(0xFF007AFF),
      primaryColorDark: const Color(0xFF0051D2),
      primaryColorLight: const Color(0xFF5AC8FA),

      // Color scheme - Apple style
      colorScheme: isDark 
        ? ColorScheme.dark(
            brightness: Brightness.dark,
            primary: accentPrimary,
            onPrimary: textPrimary,
            secondary: accentSecondary,
            onSecondary: textPrimary,
            tertiary: const Color(0xFFAF52DE),
            onTertiary: textPrimary,
            error: errorColor,
            onError: textPrimary,
            background: bgPrimary,
            onBackground: textPrimary,
            surface: bgElevated,
            onSurface: textPrimary,
            surfaceVariant: bgSecondary,
            onSurfaceVariant: textSecondary,
            outline: const Color(0xFF38383A),
            outlineVariant: const Color(0xFF48484A),
          )
        : ColorScheme.light(
            brightness: Brightness.light,
            primary: const Color(0xFF007AFF),
            onPrimary: Colors.white,
            secondary: const Color(0xFF5AC8FA),
            onSecondary: Colors.white,
            tertiary: const Color(0xFFAF52DE),
            onTertiary: Colors.white,
            error: const Color(0xFFFF3B30),
            onError: Colors.white,
            background: Colors.white,
            onBackground: Colors.black,
            surface: Colors.white,
            onSurface: Colors.black,
            surfaceVariant: Colors.grey[100]!,
            onSurfaceVariant: Colors.grey[700]!,
            outline: Colors.grey[300]!,
            outlineVariant: Colors.grey[200]!,
          ),

      // Scaffold background - Pure black for Apple dark mode
      scaffoldBackgroundColor: isDark ? bgPrimary : Colors.grey[50],

      // AppBar theme - Apple style
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? bgElevated : accentPrimary,
        foregroundColor: textPrimary,
        elevation: context != null ? ResponsiveHelper.getElevation(context, baseElevation: 0) : 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: context != null ? ResponsiveHelper.getResponsiveFontSize(context, baseFontSize: 20, minFontSize: 18, maxFontSize: 24) : 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        iconTheme: IconThemeData(color: textPrimary),
        actionsIconTheme: IconThemeData(color: textPrimary),
      ),

      // Card theme - Apple elevated surfaces
      cardTheme: CardThemeData(
        color: isDark ? bgElevated : Colors.white,
        elevation: context != null ? ResponsiveHelper.getElevation(context, baseElevation: 0) : 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            context != null ? ResponsiveHelper.getBorderRadius(context, baseRadius: 12) : 12,
          ),
        ),
      ),

      // Input decoration theme - Apple style forms
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? bgSecondary : Colors.grey[100],
        labelStyle: TextStyle(color: isDark ? textTertiary : Colors.grey[600]),
        hintStyle: TextStyle(color: isDark ? textTertiary : Colors.grey[500]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            context != null ? ResponsiveHelper.getBorderRadius(context) : 8,
          ),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF38383A) : Colors.grey[300]!,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            context != null ? ResponsiveHelper.getBorderRadius(context) : 8,
          ),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF38383A) : Colors.grey[300]!,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            context != null ? ResponsiveHelper.getBorderRadius(context) : 8,
          ),
          borderSide: BorderSide(
            color: isDark ? accentPrimary : accentPrimary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            context != null ? ResponsiveHelper.getBorderRadius(context) : 8,
          ),
          borderSide: BorderSide(
            color: errorColor,
          ),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: context != null ? ResponsiveHelper.getSpacing(context, large: 16) : 16,
          vertical: context != null ? ResponsiveHelper.getSpacing(context, medium: 14) : 14,
        ),
      ),

      // Elevated button theme - Apple style
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? accentPrimary : accentPrimary,
          foregroundColor: textPrimary,
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

      // Outlined button theme - Apple style
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? accentPrimary : accentPrimary,
          side: BorderSide(
            color: isDark ? accentPrimary : accentPrimary,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      // Text button theme - Apple style
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? accentPrimary : accentPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),

      // Icon theme - Apple style
      iconTheme: IconThemeData(
        color: isDark ? textPrimary : Colors.grey[700],
      ),

      // Text theme with responsive sizing
      textTheme: _getResponsiveTextTheme(isDark, context),

      // Bottom Navigation Bar Theme - Apple style
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? bgElevated : Colors.white,
        selectedItemColor: isDark ? accentPrimary : accentPrimary,
        unselectedItemColor: isDark ? textTertiary : Colors.grey[600],
        elevation: 0,
      ),

      // Navigation Bar Theme (Material 3) - Apple style
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? bgElevated : Colors.white,
        indicatorColor: isDark
            ? accentPrimary.withOpacity(0.2)
            : accentPrimary.withOpacity(0.1),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: context != null ? ResponsiveHelper.getResponsiveFontSize(context, baseFontSize: 12, minFontSize: 10, maxFontSize: 14) : 12,
              fontWeight: FontWeight.w600,
              color: isDark ? accentPrimary : accentPrimary,
            );
          }
          return TextStyle(
            fontSize: context != null ? ResponsiveHelper.getResponsiveFontSize(context, baseFontSize: 12, minFontSize: 10, maxFontSize: 14) : 12,
            fontWeight: FontWeight.w500,
            color: isDark ? textTertiary : Colors.grey[600],
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final iconSize = context != null ? ResponsiveHelper.getIconSize(context, baseSize: 24) : 24.0;
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(
              color: isDark ? accentPrimary : accentPrimary,
              size: iconSize,
            );
          }
          return IconThemeData(
            color: isDark ? textTertiary : Colors.grey[600],
            size: iconSize,
          );
        }),
      ),

      // Dialog Theme - Apple style
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? bgSecondary : Colors.white,
        titleTextStyle: TextStyle(
          color: isDark ? textPrimary : Colors.black,
          fontSize: context != null ? ResponsiveHelper.getResponsiveFontSize(context, baseFontSize: 20, minFontSize: 18, maxFontSize: 24) : 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(
          color: isDark ? textSecondary : Colors.grey[700],
          fontSize: context != null ? ResponsiveHelper.getResponsiveFontSize(context, baseFontSize: 14, minFontSize: 12, maxFontSize: 16) : 14,
        ),
      ),

      // Floating Action Button Theme - Apple style
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: isDark ? accentPrimary : accentPrimary,
        foregroundColor: textPrimary,
        elevation: 0,
      ),

      // Chip Theme - Apple style
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? bgSecondary : Colors.grey[100]!,
        labelStyle: TextStyle(
          color: isDark ? textSecondary : Colors.grey[700],
        ),
        side: BorderSide(
          color: isDark ? const Color(0xFF38383A) : Colors.grey[300]!,
        ),
      ),

      // Badge Theme - Apple style
      badgeTheme: BadgeThemeData(
        backgroundColor: errorColor,
        textColor: textPrimary,
      ),

      // Divider Theme - Apple style
      dividerTheme: DividerThemeData(
        color: isDark ? const Color(0xFF38383A) : Colors.grey[300],
        thickness: 0.5,
      ),

      // List Tile Theme - Apple style
      listTileTheme: ListTileThemeData(
        tileColor: isDark ? bgElevated : Colors.white,
        textColor: isDark ? textPrimary : Colors.black,
        iconColor: isDark ? textSecondary : Colors.grey[600],
      ),

      // Snackbar Theme - Apple style
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? bgSecondary : const Color(0xFF323232),
        contentTextStyle: TextStyle(color: textPrimary),
        actionTextColor: isDark ? accentPrimary : accentSecondary,
      ),
      
      // DataTable Theme - Apple style for better text visibility
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(isDark ? bgSecondary : Colors.grey[100]),
        dataRowColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return isDark ? accentPrimary.withOpacity(0.2) : accentPrimary.withOpacity(0.1);
          }
          if (states.contains(WidgetState.hovered)) {
            return isDark ? bgTertiary : Colors.grey[50];
          }
          return isDark ? bgElevated : Colors.white;
        }),
        headingTextStyle: TextStyle(
          color: isDark ? textPrimary : Colors.black,
          fontWeight: FontWeight.w600,
        ),
        dataTextStyle: TextStyle(
          color: isDark ? textSecondary : Colors.black87,
        ),
      ),
    );
  }
  
  // Helper method to create responsive text theme with Apple colors
  static TextTheme _getResponsiveTextTheme(bool isDark, BuildContext? context) {
    return TextTheme(
      // Display styles - largest text
      displayLarge: TextStyle(
        color: isDark ? textPrimary : Colors.black,
        fontSize: context != null ? ResponsiveHelper.getResponsiveFontSize(context, baseFontSize: 57, minFontSize: 48, maxFontSize: 64) : 57,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.25,
      ),
      displayMedium: TextStyle(
        color: isDark ? textPrimary : Colors.black,
        fontSize: context != null ? ResponsiveHelper.getResponsiveFontSize(context, baseFontSize: 45, minFontSize: 40, maxFontSize: 52) : 45,
        fontWeight: FontWeight.w400,
      ),
      displaySmall: TextStyle(
        color: isDark ? textPrimary : Colors.black,
        fontSize: context != null ? ResponsiveHelper.getResponsiveFontSize(context, baseFontSize: 36, minFontSize: 32, maxFontSize: 42) : 36,
        fontWeight: FontWeight.w400,
      ),
      
      // Headlines
      headlineLarge: TextStyle(
        color: isDark ? textPrimary : Colors.black,
        fontSize: context != null ? ResponsiveHelper.getResponsiveFontSize(context, baseFontSize: 32, minFontSize: 28, maxFontSize: 40) : 32,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.25,
      ),
      headlineMedium: TextStyle(
        color: isDark ? textPrimary : Colors.black,
        fontSize: context != null ? ResponsiveHelper.getResponsiveFontSize(context, baseFontSize: 28, minFontSize: 24, maxFontSize: 34) : 28,
        fontWeight: FontWeight.w400,
      ),
      headlineSmall: TextStyle(
        color: isDark ? textPrimary : Colors.black,
        fontSize: context != null ? ResponsiveHelper.getResponsiveFontSize(context, baseFontSize: 24, minFontSize: 20, maxFontSize: 28) : 24,
        fontWeight: FontWeight.w400,
      ),
      
      // Titles
      titleLarge: TextStyle(
        color: isDark ? textPrimary : Colors.black,
        fontSize: context != null ? ResponsiveHelper.getResponsiveFontSize(context, baseFontSize: 22, minFontSize: 18, maxFontSize: 26) : 22,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
      titleMedium: TextStyle(
        color: isDark ? textPrimary : Colors.black,
        fontSize: context != null ? ResponsiveHelper.getResponsiveFontSize(context, baseFontSize: 16, minFontSize: 14, maxFontSize: 20) : 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.15,
      ),
      titleSmall: TextStyle(
        color: isDark ? textPrimary : Colors.black,
        fontSize: context != null ? ResponsiveHelper.getResponsiveFontSize(context, baseFontSize: 14, minFontSize: 12, maxFontSize: 16) : 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
      
      // Body text - highly visible
      bodyLarge: TextStyle(
        color: isDark ? textSecondary : Colors.grey[800],
        fontSize: context != null ? ResponsiveHelper.getResponsiveFontSize(context, baseFontSize: 16, minFontSize: 14, maxFontSize: 18) : 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
      ),
      bodyMedium: TextStyle(
        color: isDark ? textSecondary : Colors.grey[700],
        fontSize: context != null ? ResponsiveHelper.getResponsiveFontSize(context, baseFontSize: 14, minFontSize: 12, maxFontSize: 16) : 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
      ),
      bodySmall: TextStyle(
        color: isDark ? textTertiary : Colors.grey[600],
        fontSize: context != null ? ResponsiveHelper.getResponsiveFontSize(context, baseFontSize: 12, minFontSize: 10, maxFontSize: 14) : 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
      ),
      
      // Labels
      labelLarge: TextStyle(
        color: isDark ? textPrimary : Colors.grey[800],
        fontSize: context != null ? ResponsiveHelper.getResponsiveFontSize(context, baseFontSize: 14, minFontSize: 12, maxFontSize: 16) : 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
      labelMedium: TextStyle(
        color: isDark ? textSecondary : Colors.grey[700],
        fontSize: context != null ? ResponsiveHelper.getResponsiveFontSize(context, baseFontSize: 12, minFontSize: 10, maxFontSize: 14) : 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
      labelSmall: TextStyle(
        color: isDark ? textTertiary : Colors.grey[600],
        fontSize: context != null ? ResponsiveHelper.getResponsiveFontSize(context, baseFontSize: 11, minFontSize: 9, maxFontSize: 13) : 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
    );
  }
}
