import 'package:flutter/material.dart';

/// Full-page or inline error state with optional retry.
class ErrorStateWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
            label: const Text('Retry'),
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
