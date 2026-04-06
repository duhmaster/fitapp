import 'package:flutter/material.dart';

/// Horizontal strip of unlocked badge codes (chips).
class BadgeUnlockStrip extends StatelessWidget {
  const BadgeUnlockStrip({
    super.key,
    required this.codes,
    required this.sectionTitle,
  });

  final List<String> codes;
  final String sectionTitle;

  @override
  Widget build(BuildContext context) {
    if (codes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(sectionTitle, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: codes
              .map(
                (c) => Chip(
                  avatar: const Icon(Icons.military_tech_rounded, size: 18),
                  label: Text(c),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
