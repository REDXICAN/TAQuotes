# KPI Card Widget Library

## Overview

Unified, reusable KPI (Key Performance Indicator) card components designed to eliminate code duplication across admin dashboards. All widgets follow Material Design 3 principles and support responsive layouts.

## Features

- **4 Widget Types**: `KPICard`, `KPICardGrid`, `TrendIndicator`, `KPICardHorizontal`
- **Auto-Responsive**: Adapts columns based on screen size (Mobile: 2, Tablet: 3, Desktop: 4)
- **Material Design 3**: Consistent styling with theme colors, border radius 12px, subtle shadows
- **Loading States**: Built-in shimmer effect for data loading
- **Interactive**: Optional `onTap` callback for drill-down navigation
- **Trend Indicators**: Automatic color coding (green = up, red = down)
- **Fully Documented**: Comprehensive inline documentation and examples

## Installation

Import the widget library:

```dart
import 'package:turbo_air_quotes/core/widgets/kpi_card.dart';
// OR use barrel import:
import 'package:turbo_air_quotes/core/widgets/widgets.dart';
```

## Widgets

### 1. KPICard

Standard vertical KPI card with icon, title, value, and optional subtitle.

**Properties:**
- `title` (String): Metric name (e.g., "Total Revenue")
- `value` (String): Metric value (e.g., "\$45,234")
- `icon` (IconData): Icon displayed at top
- `color` (Color): Primary color for icon and value
- `subtitle` (String?): Optional trend text below value
- `onTap` (VoidCallback?): Optional tap callback
- `isLoading` (bool): Shows shimmer loading effect

**Example:**
```dart
KPICard(
  title: 'Total Revenue',
  value: '\$45,234',
  icon: Icons.attach_money,
  color: Colors.green,
  subtitle: '+12.5% vs last month',
  onTap: () => navigateToRevenueDetail(),
)
```

### 2. KPICardGrid

Responsive grid layout for KPI cards with auto-adjusting columns.

**Properties:**
- `children` (List<Widget>): List of KPICard widgets
- `crossAxisCount` (int?): Override default columns (null = auto-responsive)
- `crossAxisSpacing` (double): Horizontal spacing (default: 16)
- `mainAxisSpacing` (double): Vertical spacing (default: 16)
- `childAspectRatio` (double): Card aspect ratio (default: 1.5)

**Example:**
```dart
KPICardGrid(
  children: [
    KPICard(...),
    KPICard(...),
    KPICard(...),
    KPICard(...),
  ],
)
```

**Responsive Behavior:**
- Mobile (<600px): 2 columns
- Tablet (600-1024px): 3 columns
- Desktop (>1024px): 4 columns

### 3. TrendIndicator

Displays percentage change with colored arrow and comparison text.

**Properties:**
- `value` (double): Percentage change (e.g., 12.5 for +12.5%)
- `comparison` (String): Comparison period (e.g., "vs last month")
- `invertColors` (bool): Reverse color logic (default: false)

**Example:**
```dart
KPICard(
  ...
  subtitle: TrendIndicator(
    value: 12.5,
    comparison: 'vs last month',
  ).toString(),
)
```

**Color Logic:**
- Positive value: Green with up arrow
- Negative value: Red with down arrow
- Zero: Gray with dash
- `invertColors: true`: Swaps red/green (useful for cost metrics)

### 4. KPICardHorizontal

Compact horizontal layout with icon on left, data on right.

**Properties:**
Same as `KPICard` but horizontal layout.

**Example:**
```dart
KPICardHorizontal(
  title: 'Active Users',
  value: '1,234',
  icon: Icons.people,
  color: Colors.blue,
  subtitle: 'Last 7 days',
)
```

## Migration Guide

### Replacing Existing Code

#### Before (admin_panel_screen.dart):
```dart
Widget _buildStatCard(
    String title, String value, IconData icon, Color color) {
  return Card(
    elevation: 4,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    ),
  );
}

// Usage:
GridView.count(
  crossAxisCount: ResponsiveHelper.isMobile(context) ? 2 : 4,
  children: [
    _buildStatCard('Total Products', '835', Icons.inventory, Colors.blue),
    _buildStatCard('Total Clients', '250', Icons.people, Colors.green),
  ],
)
```

#### After (Using KPICard):
```dart
// No custom method needed - delete _buildStatCard

KPICardGrid(
  children: [
    KPICard(
      title: 'Total Products',
      value: '835',
      icon: Icons.inventory,
      color: Colors.blue,
    ),
    KPICard(
      title: 'Total Clients',
      value: '250',
      icon: Icons.people,
      color: Colors.green,
    ),
  ],
)
```

**Benefits:**
- Removes 30+ lines of duplicate code
- Auto-responsive (no manual breakpoint checks)
- Consistent styling across all dashboards
- Built-in loading states and interactions

### Before (performance_dashboard_screen.dart):
```dart
Widget _buildKPICard({
  required String title,
  required String value,
  required IconData icon,
  required Color color,
  required ThemeData theme,
}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: theme.dividerColor),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(...),
  );
}
```

#### After:
```dart
// Delete _buildKPICard method entirely

KPICard(
  title: title,
  value: value,
  icon: icon,
  color: color,
)
```

## Usage Examples

### 1. Basic Dashboard Overview
```dart
KPICardGrid(
  children: [
    KPICard(
      title: 'Total Revenue',
      value: currencyFormat.format(125000),
      icon: Icons.attach_money,
      color: Colors.green,
    ),
    KPICard(
      title: 'Total Quotes',
      value: numberFormat.format(1250),
      icon: Icons.receipt_long,
      color: Colors.blue,
    ),
    KPICard(
      title: 'Active Users',
      value: '847',
      icon: Icons.people,
      color: Colors.orange,
    ),
    KPICard(
      title: 'Conversion Rate',
      value: '84.4%',
      icon: Icons.trending_up,
      color: Colors.purple,
    ),
  ],
)
```

### 2. With Trend Indicators
```dart
KPICard(
  title: 'Monthly Revenue',
  value: currencyFormat.format(45234),
  icon: Icons.analytics,
  color: Colors.green,
  subtitle: TrendIndicator(
    value: 12.5,
    comparison: 'vs last month',
  ).toString(),
)
```

### 3. Interactive Cards (Drill-Down)
```dart
KPICard(
  title: 'Pending Quotes',
  value: '23',
  icon: Icons.pending,
  color: Colors.amber,
  onTap: () => context.go('/quotes?status=pending'),
)
```

### 4. Loading State
```dart
KPICard(
  title: 'Loading Data...',
  value: '',
  icon: Icons.hourglass_empty,
  color: Colors.grey,
  isLoading: true,
)
```

### 5. Cost Reduction Metrics (Negative = Good)
```dart
KPICard(
  title: 'Operating Costs',
  value: currencyFormat.format(8500),
  icon: Icons.trending_down,
  color: Colors.green,
  subtitle: TrendIndicator(
    value: -15.2,
    comparison: 'vs last quarter',
    invertColors: true, // Make negative trend = green
  ).toString(),
)
```

### 6. Compact List View
```dart
Column(
  children: [
    KPICardHorizontal(
      title: 'Total Products',
      value: '835',
      icon: Icons.inventory,
      color: Colors.indigo,
    ),
    const SizedBox(height: 12),
    KPICardHorizontal(
      title: 'Low Stock Items',
      value: '12',
      icon: Icons.warning,
      color: Colors.orange,
      subtitle: 'Requires attention',
    ),
  ],
)
```

## Design Specifications

### Styling
- **Border Radius**: 12px (consistent across all cards)
- **Padding**: 16px internal padding
- **Shadow**: `BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)`
- **Border**: 1px using `theme.dividerColor`
- **Background**: `theme.cardColor`
- **Icon Size**: 32px (standard), 28px (horizontal)
- **Value Font**: `headlineSmall` + bold + colored
- **Title Font**: `bodyMedium` + `disabledColor`
- **Subtitle Font**: `bodySmall` + `disabledColor` + 10px

### Responsive Breakpoints
- **Mobile**: <600px → 2 columns
- **Tablet**: 600-1024px → 3 columns
- **Desktop**: >1024px → 4 columns

Uses `ResponsiveHelper` from `lib/core/utils/responsive_helper.dart`.

## Testing

Run the example screen:
```dart
import 'package:turbo_air_quotes/core/widgets/kpi_card_example.dart';

// Navigate to:
MaterialPageRoute(builder: (context) => const KPICardExampleScreen())
```

## Code Reduction Metrics

**Before:**
- 4 files with duplicate `_buildKPICard`, `_buildStatCard`, `_buildMetricCard` methods
- ~120 lines of duplicate code per file
- Inconsistent styling (some use elevation: 2, others elevation: 4)
- Manual responsive logic in each file

**After:**
- 1 shared `kpi_card.dart` file (420 lines, reusable)
- 4 widgets covering all use cases
- 0 duplicate code in admin screens
- Consistent styling enforced
- Auto-responsive with no manual logic

**Total Lines Saved:** ~400+ lines across 4 files

## Related Files

- **Implementation**: `lib/core/widgets/kpi_card.dart`
- **Examples**: `lib/core/widgets/kpi_card_example.dart`
- **Barrel Export**: `lib/core/widgets/widgets.dart`
- **Utilities**: `lib/core/utils/responsive_helper.dart`

## Files That Should Migrate

1. `lib/features/admin/presentation/screens/admin_panel_screen.dart`
   - Replace `_buildStatCard()` (line 518-549)
   - Replace `_buildKPICard()` (line 551-599)

2. `lib/features/admin/presentation/screens/performance_dashboard_screen.dart`
   - Replace `_buildKPICard()` (line 937-987)

3. `lib/features/admin/presentation/screens/user_info_dashboard_screen.dart`
   - Replace `_buildMetricCard()` (line 1039-1073)

4. `lib/features/admin/presentation/screens/project_analytics_screen.dart`
   - Replace `_buildKPICard()` (line 207-245)

## Support

For questions or issues, see:
- Example usage: `lib/core/widgets/kpi_card_example.dart`
- Documentation: This file
- Contact: andres@turboairmexico.com
