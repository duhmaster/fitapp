import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/core/locale/locale_provider.dart';

class ProgressMenuScreen extends ConsumerWidget {
  const ProgressMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final width = MediaQuery.sizeOf(context).width;
    final twoColumns = width >= 1100;
    return Scaffold(
      appBar: AppBar(title: Text(tr('progress'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(tr('gam_progress_section'),
                style: Theme.of(context).textTheme.titleSmall),
          ),
          _MenuGrid(
            twoColumns: twoColumns,
            items: [
              _MenuTile(
                title: tr('gam_menu_achievements'),
                subtitle: tr('gam_menu_achievements_sub'),
                icon: Icons.emoji_events_outlined,
                onTap: () => context.push('/progress/achievements'),
              ),
              _MenuTile(
                title: tr('gam_menu_missions'),
                subtitle: tr('gam_menu_missions_sub'),
                icon: Icons.flag_outlined,
                onTap: () => context.push('/progress/missions'),
              ),
              _MenuTile(
                title: tr('gam_menu_leaderboard'),
                subtitle: tr('gam_menu_leaderboard_sub'),
                icon: Icons.leaderboard_outlined,
                onTap: () => context.push('/progress/leaderboard'),
              ),
              _MenuTile(
                title: tr('gam_menu_xp_history'),
                subtitle: tr('gam_menu_xp_history_sub'),
                icon: Icons.history_rounded,
                onTap: () => context.push('/progress/xp-history'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(tr('gam_analytics_section'),
                style: Theme.of(context).textTheme.titleSmall),
          ),
          _MenuGrid(
            twoColumns: twoColumns,
            items: [
              _MenuTile(
                title: tr('progress_measurements'),
                subtitle: tr('progress_measurements_subtitle'),
                icon: Icons.monitor_weight,
                onTap: () => context.push('/progress/measurements'),
              ),
              _MenuTile(
                title: tr('progress_workouts'),
                subtitle: tr('progress_workouts_subtitle'),
                icon: Icons.directions_run,
                onTap: () => context.push('/progress/workouts'),
              ),
              _MenuTile(
                title: tr('statistics_exercises'),
                subtitle: tr('progress_exercises_subtitle'),
                icon: Icons.fitness_center,
                onTap: () => context.push('/progress/exercises'),
              ),
              _MenuTile(
                title: tr('progress_muscles'),
                subtitle: tr('progress_muscles_subtitle'),
                icon: Icons.scatter_plot_rounded,
                onTap: () => context.push('/progress/muscles'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenuGrid extends StatelessWidget {
  const _MenuGrid({required this.twoColumns, required this.items});

  final bool twoColumns;
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    if (!twoColumns) {
      return Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            items[i],
            if (i != items.length - 1) const SizedBox(height: 12),
          ],
        ],
      );
    }
    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 3.8,
      ),
      itemBuilder: (_, i) => items[i],
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
