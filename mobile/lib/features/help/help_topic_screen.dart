import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/core/locale/locale_provider.dart';

class HelpTopicScreen extends ConsumerWidget {
  const HelpTopicScreen({super.key, required this.topicId});
  final String topicId;

  static String _titleKey(String id) {
    switch (id) {
      case 'workouts': return 'help_workouts_title';
      case 'templates': return 'help_templates_title';
      case 'current_workout': return 'help_current_workout_title';
      case 'progress': return 'help_progress_title';
      case 'profile': return 'help_profile_title';
      case 'exercises': return 'help_exercises_title';
      default: return 'help';
    }
  }

  static String _bodyKey(String id) {
    switch (id) {
      case 'workouts': return 'help_workouts_body';
      case 'templates': return 'help_templates_body';
      case 'current_workout': return 'help_current_workout_body';
      case 'progress': return 'help_progress_body';
      case 'profile': return 'help_profile_body';
      case 'exercises': return 'help_exercises_body';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final title = tr(_titleKey(topicId));
    final bodyKey = _bodyKey(topicId);
    final body = bodyKey.isEmpty ? '' : tr(bodyKey);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: body.isEmpty
          ? Center(child: Text(tr('help')))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Text(
                body,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
    );
  }
}
