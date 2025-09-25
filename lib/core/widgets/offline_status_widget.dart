// lib/core/widgets/offline_status_widget.dart
import 'package:flutter/material.dart';
import '../services/offline_service.dart';

class OfflineStatusWidget extends StatefulWidget {
  final Widget child;

  const OfflineStatusWidget({
    super.key,
    required this.child,
  });

  @override
  State<OfflineStatusWidget> createState() => _OfflineStatusWidgetState();
}

class _OfflineStatusWidgetState extends State<OfflineStatusWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<double>(
      begin: -1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        StreamBuilder<bool>(
          stream: OfflineService.staticConnectionStream,
          initialData: OfflineService.staticIsOnline,
          builder: (context, snapshot) {
            // Handle service unavailability gracefully
            if (snapshot.hasError || !OfflineService.isInitialized) {
              return const SizedBox.shrink(); // Hide banner if service unavailable
            }

            final isOnline = snapshot.data ?? true;
            final pendingCount = OfflineService.staticPendingOperations.length;

            // Show banner if offline or has pending operations
            final shouldShow = !isOnline || (isOnline && pendingCount > 0);

            if (shouldShow != _isVisible) {
              _isVisible = shouldShow;
              if (_isVisible) {
                _animationController.forward();
              } else {
                _animationController.reverse();
              }
            }

            return AnimatedBuilder(
              animation: _slideAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _slideAnimation.value * 48),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Material(
                      elevation: 4,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isOnline ? Colors.green : Colors.orange[800],
                        ),
                        child: SafeArea(
                          bottom: false,
                          child: Row(
                            children: [
                              Icon(
                                isOnline ? Icons.cloud_done : Icons.cloud_off,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  isOnline
                                      ? pendingCount > 0
                                          ? 'Syncing $pendingCount pending changes...'
                                          : 'Back online'
                                      : 'You are offline. Changes will sync when reconnected.',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (pendingCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$pendingCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
