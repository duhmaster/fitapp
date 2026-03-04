import 'package:flutter/material.dart';

class ProfileStatsCard extends StatelessWidget {
  const ProfileStatsCard({
    super.key,
    this.heightCm,
    this.weightKg,
    this.bodyFatPct,
  });

  final double? heightCm;
  final double? weightKg;
  final double? bodyFatPct;

  static String _format(double? v, [String suffix = '']) {
    if (v == null) return '—';
    return '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1)}$suffix';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _StatItem(
              label: 'Height',
              value: _format(heightCm, ' cm'),
              icon: Icons.height,
            ),
            _StatItem(
              label: 'Weight',
              value: _format(weightKg, ' kg'),
              icon: Icons.monitor_weight_outlined,
            ),
            _StatItem(
              label: 'Body fat',
              value: _format(bodyFatPct, '%'),
              icon: Icons.pie_chart_outline,
            ),
          ],
        ),
      ),
    );
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 8),
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
    );
  }
}
