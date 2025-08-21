// lib/core/widgets/active_client_banner.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/cart/presentation/screens/cart_screen.dart';

class ActiveClientBanner extends ConsumerWidget {
  final Widget child;
  
  const ActiveClientBanner({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeClient = ref.watch(cartClientProvider);
    final theme = Theme.of(context);
    
    return Column(
      children: [
        if (activeClient != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.1),
              border: Border(
                bottom: BorderSide(
                  color: theme.primaryColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.business,
                  size: 16,
                  color: theme.primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Active Client: ${activeClient.company}',
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ref.read(cartClientProvider.notifier).state = null;
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Clear',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(child: child),
      ],
    );
  }
}