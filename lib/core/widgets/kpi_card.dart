// lib/core/widgets/kpi_card.dart
library;

/// Reusable KPI (Key Performance Indicator) card components for admin dashboards
///
/// This library provides standardized card widgets to eliminate code duplication
/// across admin screens. All cards follow Material Design 3 principles and support
/// responsive layouts.

import 'package:flutter/material.dart';
import '../utils/responsive_helper.dart';

/// A reusable KPI card widget that displays a metric with icon, title, and value.
///
/// Supports optional subtitle for trend indicators and onTap callback for interactivity.
/// Example usage:
/// ```dart
/// KPICard(
///   title: 'Total Revenue',
///   value: '\$45,234',
///   icon: Icons.attach_money,
///   color: Colors.green,
///   subtitle: '+12.5% vs last month',
/// )
/// ```
class KPICard extends StatelessWidget {
  /// The title displayed below the value (e.g., "Total Revenue")
  final String title;

  /// The main metric value (e.g., "\$45,234", "1,250")
  final String value;

  /// Icon displayed at the top of the card
  final IconData icon;

  /// Primary color for icon and value text
  final Color color;

  /// Optional subtitle for trend indicators or additional context
  final String? subtitle;

  /// Optional callback when card is tapped
  final VoidCallback? onTap;

  /// Shows loading state with shimmer effect
  final bool isLoading;

  const KPICard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget content = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),

          // Title (smaller, gray text)
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.disabledColor,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),

          // Value (large, bold, colored)
          if (!isLoading)
            Flexible(
              child: Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            )
          else
            // Loading shimmer
            Container(
              height: 28,
              width: 80,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),

          // Optional subtitle (trend indicator)
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.disabledColor,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );

    // Make card tappable if onTap provided
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: content,
      );
    }

    return content;
  }
}

/// A responsive grid layout for KPI cards that auto-adjusts columns based on screen size.
///
/// Default breakpoints:
/// - Mobile: 2 columns
/// - Tablet: 3 columns
/// - Desktop: 4 columns
///
/// Example usage:
/// ```dart
/// KPICardGrid(
///   children: [
///     KPICard(...),
///     KPICard(...),
///     KPICard(...),
///   ],
/// )
/// ```
class KPICardGrid extends StatelessWidget {
  /// List of KPICard widgets to display
  final List<Widget> children;

  /// Override default column count (null = auto-responsive)
  final int? crossAxisCount;

  /// Spacing between cards horizontally
  final double crossAxisSpacing;

  /// Spacing between cards vertically
  final double mainAxisSpacing;

  /// Card aspect ratio (width / height)
  final double childAspectRatio;

  const KPICardGrid({
    super.key,
    required this.children,
    this.crossAxisCount,
    this.crossAxisSpacing = 16,
    this.mainAxisSpacing = 16,
    this.childAspectRatio = 1.5,
  });

  @override
  Widget build(BuildContext context) {
    // Determine responsive column count
    int columns = crossAxisCount ?? _getResponsiveColumns(context);

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: columns,
      crossAxisSpacing: crossAxisSpacing,
      mainAxisSpacing: mainAxisSpacing,
      childAspectRatio: childAspectRatio,
      children: children,
    );
  }

  int _getResponsiveColumns(BuildContext context) {
    if (ResponsiveHelper.isDesktop(context)) {
      return 4;
    } else if (ResponsiveHelper.isTablet(context)) {
      return 3;
    } else {
      return 2; // Mobile
    }
  }
}

/// Widget that displays a trend indicator with percentage change and direction arrow.
///
/// Automatically colors:
/// - Green with up arrow for positive values
/// - Red with down arrow for negative values
/// - Gray with dash for zero
///
/// Example usage:
/// ```dart
/// KPICard(
///   ...
///   subtitle: TrendIndicator(value: 12.5, comparison: 'vs last month').toString(),
/// )
/// ```
class TrendIndicator extends StatelessWidget {
  /// The percentage change value (e.g., 12.5 for +12.5%)
  final double value;

  /// Comparison period text (e.g., "vs last month", "from previous quarter")
  final String comparison;

  /// Force positive color even for negative values (useful for metrics where decrease is good)
  final bool invertColors;

  const TrendIndicator({
    super.key,
    required this.value,
    required this.comparison,
    this.invertColors = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPositive = value > 0;
    final isNegative = value < 0;

    // Determine color
    Color trendColor;
    IconData trendIcon;

    if (value == 0) {
      trendColor = Colors.grey;
      trendIcon = Icons.remove;
    } else if ((isPositive && !invertColors) || (isNegative && invertColors)) {
      trendColor = Colors.green;
      trendIcon = Icons.arrow_upward;
    } else {
      trendColor = Colors.red;
      trendIcon = Icons.arrow_downward;
    }

    final String percentText = value.abs().toStringAsFixed(1);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          trendIcon,
          color: trendColor,
          size: 12,
        ),
        const SizedBox(width: 2),
        Text(
          '$percentText% $comparison',
          style: theme.textTheme.bodySmall?.copyWith(
            color: trendColor,
            fontWeight: FontWeight.w600,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  /// Helper to use TrendIndicator as a string for subtitle parameter
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    final prefix = value > 0 ? '+' : '';
    return '$prefix${value.toStringAsFixed(1)}% $comparison';
  }
}

/// Alternative KPI card style with horizontal layout (icon on left, data on right).
///
/// Useful for more compact displays or list views.
///
/// Example usage:
/// ```dart
/// KPICardHorizontal(
///   title: 'Active Users',
///   value: '1,234',
///   icon: Icons.people,
///   color: Colors.blue,
/// )
/// ```
class KPICardHorizontal extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool isLoading;

  const KPICardHorizontal({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget content = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon in circle
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),

          // Data column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.disabledColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (!isLoading)
                  Text(
                    value,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  Container(
                    height: 24,
                    width: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.disabledColor,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: content,
      );
    }

    return content;
  }
}
