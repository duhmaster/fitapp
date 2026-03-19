import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/core/locale/locale_provider.dart';

class ProgressMenuScreen extends ConsumerWidget {
  const ProgressMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr('progress'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _MenuTile(
            title: tr('progress_measurements'),
            subtitle: tr('progress_measurements_subtitle'),
            icon: Icons.monitor_weight,
            onTap: () => context.push('/progress/measurements'),
          ),
          const SizedBox(height: 12),
          _MenuTile(
            title: tr('progress_workouts'),
            subtitle: tr('progress_workouts_subtitle'),
            icon: Icons.directions_run,
            onTap: () => context.push('/progress/workouts'),
          ),
          const SizedBox(height: 12),
          _MenuTile(
            title: tr('statistics_exercises'),
            subtitle: tr('progress_exercises_subtitle'),
            icon: Icons.fitness_center,
            onTap: () => context.push('/progress/exercises'),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
