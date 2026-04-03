import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/core/locale/locale_provider.dart';

class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final topics = [
      _Topic('workouts', tr('help_workouts_title'), Icons.directions_run),
      _Topic('templates', tr('help_templates_title'), Icons.list_alt),
      _Topic('current_workout', tr('help_current_workout_title'), Icons.play_circle),
      _Topic('progress', tr('help_progress_title'), Icons.show_chart),
      _Topic('profile', tr('help_profile_title'), Icons.person),
      _Topic('gyms_trainers_groups', tr('help_gyms_trainers_groups_title'), Icons.store_mall_directory_outlined),
      _Topic('exercises', tr('help_exercises_title'), Icons.fitness_center),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(tr('help'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final t in topics)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: ListTile(
                  leading: Icon(t.icon, color: Theme.of(context).colorScheme.primary),
                  title: Text(t.title),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/help/${t.id}'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Topic {
  _Topic(this.id, this.title, this.icon);
  final String id;
  final String title;
  final IconData icon;
}
