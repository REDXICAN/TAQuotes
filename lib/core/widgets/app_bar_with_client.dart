// lib/core/widgets/app_bar_with_client.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/client_providers.dart';

class AppBarWithClient extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double elevation;
  
  const AppBarWithClient({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle = false,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeClient = ref.watch(cartClientProvider);
    final theme = Theme.of(context);
    
    return AppBar(
      leading: leading,
      title: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: foregroundColor ?? theme.appBarTheme.foregroundColor,
              ),
            ),
          ),
          if (activeClient != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.business,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Text(
                      activeClient.company,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: actions,
      centerTitle: centerTitle,
      backgroundColor: backgroundColor ?? theme.primaryColor,
      foregroundColor: foregroundColor ?? theme.appBarTheme.foregroundColor,
      elevation: elevation,
    );
  }
  
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}