// lib/core/utils/responsive_helper.dart
import 'package:flutter/material.dart';

class ResponsiveHelper {
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600 &&
      MediaQuery.of(context).size.width < 900;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 900;

  static bool isLargeDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1400;
  
  // Check if device is in portrait mode
  static bool isPortrait(BuildContext context) =>
      MediaQuery.of(context).orientation == Orientation.portrait;
      
  // Get safe screen width considering keyboard and system UI
  static double getScreenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;
      
  static double getScreenHeight(BuildContext context) =>
      MediaQuery.of(context).size.height;

  // Get responsive value based on screen size
  static T getValue<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
    T? largeDesktop,
  }) {
    if (isLargeDesktop(context) && largeDesktop != null) {
      return largeDesktop;
    }
    if (isDesktop(context) && desktop != null) {
      return desktop;
    }
    if (isTablet(context) && tablet != null) {
      return tablet;
    }
    return mobile;
  }

  // Get responsive padding
  static EdgeInsets getScreenPadding(BuildContext context) {
    return EdgeInsets.symmetric(
      horizontal: getValue(
        context,
        mobile: 12,
        tablet: 16,
        desktop: 20,      // Reduced padding for desktop
        largeDesktop: 24, // Reduced padding for large desktop
      ),
      vertical: getValue(
        context,
        mobile: 12,
        tablet: 14,
        desktop: 16,
      ),
    );
  }
  
  // Get card padding for list items
  static EdgeInsets getCardPadding(BuildContext context) {
    return EdgeInsets.all(getValue(
      context,
      mobile: 8,
      tablet: 12,
      desktop: 16,
    ));
  }

  // Get number of columns for grid layouts
  static int getGridColumns(BuildContext context) {
    final width = getScreenWidth(context);
    
    // For products grid - optimized for requested layout
    if (width < 600) return 1;   // Phones - 1 card per line
    return 6;                     // Tablets & Desktop - 6 cards per line
  }
  
  // Get columns for simpler grids (like categories)
  static int getSimpleGridColumns(BuildContext context) {
    return getValue(
      context,
      mobile: 2,
      tablet: 3,
      desktop: 4,
      largeDesktop: 5,
    );
  }

  // Get max width for content containers
  static double getMaxContentWidth(BuildContext context) {
    return getValue(
      context,
      mobile: double.infinity,
      tablet: double.infinity,  // Full width for tablets
      desktop: double.infinity,  // Full width for desktop
      largeDesktop: double.infinity,  // Full width for large desktop
    );
  }
  
  // Get font scale factor for responsive text
  static double getFontScale(BuildContext context) {
    final width = getScreenWidth(context);
    if (width < 360) return 0.85;  // Very small phones
    if (width < 400) return 0.9;   // Small phones
    if (width < 600) return 1.0;   // Normal phones
    if (width < 900) return 1.1;   // Tablets
    if (width < 1400) return 1.15; // Desktop
    return 1.25;                   // Large desktop/4K
  }
  
  // Get responsive font size with minimum readable size
  static double getResponsiveFontSize(BuildContext context, {
    required double baseFontSize,
    double? minFontSize,
    double? maxFontSize,
  }) {
    final scaleFactor = getFontScale(context);
    final scaledSize = baseFontSize * scaleFactor;
    
    if (minFontSize != null && scaledSize < minFontSize) {
      return minFontSize;
    }
    if (maxFontSize != null && scaledSize > maxFontSize) {
      return maxFontSize;
    }
    
    return scaledSize;
  }
  
  // Get responsive dimension (width, height, padding, margin)
  static double getResponsiveSize(BuildContext context, {
    required double mobile,
    double? tablet,
    double? desktop,
    double? largeDesktop,
  }) {
    return getValue<double>(
      context,
      mobile: mobile,
      tablet: tablet ?? mobile * 1.2,
      desktop: desktop ?? mobile * 1.4,
      largeDesktop: largeDesktop ?? mobile * 1.6,
    );
  }
  
  // Get minimum touch target size (44px recommended)
  static double getTouchTargetSize(BuildContext context) {
    return getResponsiveSize(
      context,
      mobile: 44.0,
      tablet: 48.0,
      desktop: 40.0,
      largeDesktop: 44.0,
    );
  }
  
  // Get responsive border radius
  static double getBorderRadius(BuildContext context, {double baseRadius = 8.0}) {
    return getResponsiveSize(
      context,
      mobile: baseRadius,
      tablet: baseRadius * 1.1,
      desktop: baseRadius * 1.2,
      largeDesktop: baseRadius * 1.3,
    );
  }
  
  // Get adaptive icon size
  static double getIconSize(BuildContext context, {double baseSize = 24}) {
    return getResponsiveSize(
      context,
      mobile: baseSize,
      tablet: baseSize * 1.1,
      desktop: baseSize * 1.15,
      largeDesktop: baseSize * 1.25,
    );
  }
  
  // Get responsive spacing/padding values
  static double getSpacing(BuildContext context, {
    double small = 4.0,
    double medium = 8.0, 
    double large = 16.0,
    double extraLarge = 24.0,
  }) {
    if (isMobile(context)) return small;
    if (isTablet(context)) return medium;
    if (isDesktop(context)) return large;
    return extraLarge; // Large desktop
  }
  
  // Get responsive container constraints
  static BoxConstraints getContainerConstraints(BuildContext context, {
    double? minWidth,
    double? maxWidth,
    double? minHeight,
    double? maxHeight,
  }) {
    final screenWidth = getScreenWidth(context);
    
    return BoxConstraints(
      minWidth: minWidth ?? 0,
      maxWidth: maxWidth ?? screenWidth,
      minHeight: minHeight ?? 0,
      maxHeight: maxHeight ?? double.infinity,
    );
  }
  
  // Get responsive elevation
  static double getElevation(BuildContext context, {double baseElevation = 1.0}) {
    if (isMobile(context)) return baseElevation;
    if (isTablet(context)) return baseElevation * 1.5;
    return baseElevation * 2.0;
  }
  
  // Check if we should use compact layout
  static bool useCompactLayout(BuildContext context) {
    return getScreenWidth(context) < 400 || getScreenHeight(context) < 600;
  }
}

// Responsive wrapper widget
class ResponsiveWrapper extends StatelessWidget {
  final Widget child;
  final double? maxWidth;

  const ResponsiveWrapper({
    super.key,
    required this.child,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final width = maxWidth ?? ResponsiveHelper.getMaxContentWidth(context);
    
    if (width == double.infinity) {
      return child;
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: child,
      ),
    );
  }
}