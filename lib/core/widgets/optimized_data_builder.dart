// lib/core/widgets/optimized_data_builder.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/app_logger.dart';

/// Universal widget for handling AsyncValue with optimized loading states
///
/// Features:
/// - Consistent loading indicators
/// - Error fallbacks with retry
/// - Empty state handling
/// - Smooth transitions
/// - Memory-efficient rendering
class OptimizedDataBuilder<T> extends StatelessWidget {
  final AsyncValue<T> data;
  final Widget Function(BuildContext context, T data) builder;
  final Widget Function(BuildContext context)? loadingBuilder;
  final Widget Function(BuildContext context, Object error, StackTrace? stack)? errorBuilder;
  final Widget Function(BuildContext context)? emptyBuilder;
  final VoidCallback? onRetry;
  final bool Function(T data)? isEmpty;
  final String? loadingMessage;
  final String? emptyMessage;

  const OptimizedDataBuilder({
    super.key,
    required this.data,
    required this.builder,
    this.loadingBuilder,
    this.errorBuilder,
    this.emptyBuilder,
    this.onRetry,
    this.isEmpty,
    this.loadingMessage,
    this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    return data.when(
      data: (value) {
        // Check if data is empty
        final checkEmpty = isEmpty ?? _defaultIsEmpty;
        if (checkEmpty(value)) {
          return emptyBuilder?.call(context) ?? _buildEmptyState(context);
        }
        return builder(context, value);
      },
      loading: () {
        return loadingBuilder?.call(context) ?? _buildLoadingState(context);
      },
      error: (error, stack) {
        AppLogger.error('Data loading error', error: error, stackTrace: stack);
        return errorBuilder?.call(context, error, stack) ?? _buildErrorState(context, error, stack);
      },
    );
  }

  /// Default loading state with shimmer effect
  Widget _buildLoadingState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          if (loadingMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              loadingMessage!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ],
      ),
    );
  }

  /// Default error state with retry button
  Widget _buildErrorState(BuildContext context, Object error, StackTrace? stack) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Oops! Something went wrong',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _getErrorMessage(error),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Default empty state
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage ?? 'No data available',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Check if data is empty (default implementation)
  bool _defaultIsEmpty(T data) {
    if (data is List) return data.isEmpty;
    if (data is Map) return data.isEmpty;
    if (data is String) return data.isEmpty;
    return false;
  }

  /// Get user-friendly error message
  String _getErrorMessage(Object error) {
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('network') || errorStr.contains('connection')) {
      return 'Please check your internet connection and try again.';
    }

    if (errorStr.contains('permission') || errorStr.contains('denied')) {
      return 'You don\'t have permission to access this data.';
    }

    if (errorStr.contains('timeout')) {
      return 'The request took too long. Please try again.';
    }

    if (errorStr.contains('not found') || errorStr.contains('404')) {
      return 'The requested data was not found.';
    }

    return 'Unable to load data. Please try again later.';
  }
}

/// Optimized list builder with pagination support
///
/// Automatically loads more items when scrolling near the end
class OptimizedListBuilder<T> extends StatefulWidget {
  final AsyncValue<List<T>> data;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Widget Function(BuildContext context)? loadingBuilder;
  final Widget Function(BuildContext context)? emptyBuilder;
  final VoidCallback? onLoadMore;
  final bool hasMore;
  final ScrollController? scrollController;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const OptimizedListBuilder({
    super.key,
    required this.data,
    required this.itemBuilder,
    this.loadingBuilder,
    this.emptyBuilder,
    this.onLoadMore,
    this.hasMore = false,
    this.scrollController,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
  });

  @override
  State<OptimizedListBuilder<T>> createState() => _OptimizedListBuilderState<T>();
}

class _OptimizedListBuilderState<T> extends State<OptimizedListBuilder<T>> {
  late ScrollController _scrollController;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    if (widget.scrollController == null) {
      _scrollController.dispose();
    } else {
      _scrollController.removeListener(_onScroll);
    }
    super.dispose();
  }

  void _onScroll() {
    if (!widget.hasMore || _isLoadingMore) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final threshold = maxScroll * 0.8; // Load more at 80% scroll

    if (currentScroll >= threshold && widget.onLoadMore != null) {
      setState(() => _isLoadingMore = true);
      widget.onLoadMore!();

      // Reset loading flag after a delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _isLoadingMore = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return OptimizedDataBuilder<List<T>>(
      data: widget.data,
      isEmpty: (items) => items.isEmpty,
      emptyBuilder: widget.emptyBuilder,
      builder: (context, items) {
        return ListView.builder(
          controller: _scrollController,
          padding: widget.padding,
          shrinkWrap: widget.shrinkWrap,
          physics: widget.physics,
          itemCount: items.length + (widget.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            // Show loading indicator at the end if there's more data
            if (index >= items.length) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            return widget.itemBuilder(context, items[index], index);
          },
        );
      },
    );
  }
}

/// Shimmer loading placeholder for list items
class ShimmerListItem extends StatelessWidget {
  final double height;
  final EdgeInsetsGeometry margin;

  const ShimmerListItem({
    super.key,
    this.height = 80,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

/// Grid shimmer loading placeholder
class ShimmerGrid extends StatelessWidget {
  final int itemCount;
  final int crossAxisCount;

  const ShimmerGrid({
    super.key,
    this.itemCount = 6,
    this.crossAxisCount = 2,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}
