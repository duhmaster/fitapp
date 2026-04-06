import 'package:flutter/material.dart';

/// Square network image with a remove control. Caller should confirm and perform API calls.
class RemovableImageTile extends StatelessWidget {
  const RemovableImageTile({
    super.key,
    required this.imageUrl,
    required this.onRemove,
    this.size = 80,
    this.borderRadius = 8,
  });

  final String imageUrl;
  final VoidCallback onRemove;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Image.network(
            imageUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: size,
              height: size,
              color: theme.colorScheme.surfaceContainerHighest,
              child: Icon(Icons.broken_image_outlined, color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: IconButton.filledTonal(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            iconSize: 16,
            onPressed: onRemove,
            icon: const Icon(Icons.close),
            tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
          ),
        ),
      ],
    );
  }
}
