// lib/features/products/widgets/import_progress_dialog.dart
import 'package:flutter/material.dart';
import 'dart:async';
import '../../../core/services/excel_upload_service.dart';

class ImportProgressDialog extends StatefulWidget {
  final int totalProducts;
  final Stream<ImportProgress> progressStream;
  final VoidCallback? onCancel;

  const ImportProgressDialog({
    super.key,
    required this.totalProducts,
    required this.progressStream,
    this.onCancel,
  });

  @override
  State<ImportProgressDialog> createState() => _ImportProgressDialogState();
}

class _ImportProgressDialogState extends State<ImportProgressDialog>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;

  ImportProgress? _currentProgress;
  StreamSubscription<ImportProgress>? _subscription;
  bool _isCompleted = false;
  bool _isCancelled = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _subscription = widget.progressStream.listen(
      (progress) {
        if (mounted && !_isCancelled) {
          setState(() {
            _currentProgress = progress;
          });

          // Update progress animation
          final percentage = widget.totalProducts > 0
              ? progress.processedCount / widget.totalProducts
              : 0.0;
          _animationController.animateTo(percentage);

          // Check if completed
          if (progress.isCompleted) {
            setState(() {
              _isCompleted = true;
            });
            // Auto-close after showing completion for 2 seconds
            Timer(const Duration(seconds: 2), () {
              if (mounted && !_isCancelled) {
                Navigator.of(context).pop(_currentProgress);
              }
            });
          }
        }
      },
      onError: (error) {
        if (mounted && !_isCancelled) {
          setState(() {
            _currentProgress = ImportProgress(
              processedCount: _currentProgress?.processedCount ?? 0,
              successCount: _currentProgress?.successCount ?? 0,
              errorCount: _currentProgress?.errorCount ?? 0,
              errors: [...(_currentProgress?.errors ?? []), error.toString()],
              currentItem: 'Error occurred',
              isCompleted: false,
              hasError: true,
            );
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _cancel() {
    setState(() {
      _isCancelled = true;
    });
    widget.onCancel?.call();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = _currentProgress;

    return WillPopScope(
      onWillPop: () async => _isCompleted || _isCancelled,
      child: AlertDialog(
        title: Row(
          children: [
            if (_isCompleted)
              const Icon(Icons.check_circle, color: Colors.green)
            else if (progress?.hasError == true)
              const Icon(Icons.error, color: Colors.red)
            else
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            const SizedBox(width: 12),
            Text(
              _isCompleted
                  ? 'Import Completed'
                  : progress?.hasError == true
                      ? 'Import Error'
                      : 'Importing Products',
              style: TextStyle(
                color: _isCompleted
                    ? Colors.green
                    : progress?.hasError == true
                        ? Colors.red
                        : null,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress bar
              AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, child) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${progress?.processedCount ?? 0} of ${widget.totalProducts}',
                            style: theme.textTheme.bodyMedium,
                          ),
                          Text(
                            '${(_progressAnimation.value * 100).toInt()}%',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _progressAnimation.value,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progress?.hasError == true
                              ? Colors.red
                              : _isCompleted
                                  ? Colors.green
                                  : theme.primaryColor,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              // Current status
              if (progress != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: theme.primaryColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              progress.currentItem,
                              style: theme.textTheme.bodySmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatusChip(
                            'Success',
                            progress.successCount,
                            Colors.green,
                          ),
                          if (progress.errorCount > 0)
                            _buildStatusChip(
                              'Errors',
                              progress.errorCount,
                              Colors.red,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              // Error details (if any)
              if (progress?.errors.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Text(
                  'Recent Errors:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 80,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.red.withOpacity(0.05),
                  ),
                  child: ListView.builder(
                    itemCount: progress!.errors.length,
                    itemBuilder: (context, index) {
                      return Text(
                        progress.errors[index],
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red[700],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (!_isCompleted && !_isCancelled)
            TextButton(
              onPressed: _cancel,
              child: const Text('Cancel'),
            ),
          if (_isCompleted)
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(_currentProgress),
              child: const Text('Close'),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

