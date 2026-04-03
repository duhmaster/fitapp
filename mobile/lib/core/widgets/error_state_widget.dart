import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/core/locale/locale_provider.dart';

/// Full-page or inline error state with optional retry.
class ErrorStateWidget extends ConsumerWidget {
  const ErrorStateWidget({
    super.key,
    required this.message,
    this.onRetry,
    this.compact = false,
  });

  final String message;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.error_outline,
          size: compact ? 40 : 64,
          color: Theme.of(context).colorScheme.error,
        ),
        SizedBox(height: compact ? 8 : 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        if (onRetry != null) ...[
          SizedBox(height: compact ? 12 : 24),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 20),
            label: Text(tr('retry')),
          ),
        ],
      ],
    );
    if (compact) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: content,
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: content,
      ),
    );
  }
}
