import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/core/locale/locale_provider.dart';

class ProfileStatsCard extends ConsumerWidget {
  const ProfileStatsCard({
    super.key,
    this.heightCm,
    this.weightKg,
    this.bodyFatPct,
    this.embedInCard = true,
  });

  final double? heightCm;
  final double? weightKg;
  final double? bodyFatPct;
  final bool embedInCard;

  static String _format(double? v, [String suffix = '']) {
    if (v == null) return '—';
    return '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1)}$suffix';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final items = [
      _StatItem(
        label: tr('height_cm'),
        value: _format(heightCm, ' cm'),
        icon: Icons.height,
      ),
      _StatItem(
        label: tr('weight_kg'),
        value: _format(weightKg, ' kg'),
        icon: Icons.monitor_weight_outlined,
      ),
      _StatItem(
        label: tr('body_fat_pct_label'),
        value: _format(bodyFatPct, '%'),
        icon: Icons.pie_chart_outline,
      ),
    ];
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            Expanded(child: items[i]),
            if (i < items.length - 1)
              Container(
                width: 1,
                height: 72,
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.5),
              ),
          ],
        ],
      ),
    );
    if (!embedInCard) return content;
    return Card(child: content);
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      child: Row(
        children: [
          Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
