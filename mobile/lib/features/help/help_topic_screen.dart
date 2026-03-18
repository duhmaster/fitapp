import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/core/locale/locale_provider.dart';

class HelpTopicScreen extends ConsumerWidget {
  const HelpTopicScreen({super.key, required this.topicId});
  final String topicId;

  /// Body markup:
  /// - `[[img:KEY]]` renders an image placeholder with KEY label.
  /// - Bullets: lines starting with `- ` or `• ` are rendered as a bullet list.
  /// - Everything else is a paragraph.
  static List<Widget> _parseBody(String body, BuildContext context) {
    final out = <Widget>[];
    final lines = body.split('\n');
    final textStyle = Theme.of(context).textTheme.bodyLarge;
    final bulletStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(color: textStyle?.color);

    void addParagraph(String s) {
      final t = s.trim();
      if (t.isEmpty) return;
      out.add(Text(t, style: textStyle));
    }

    final bulletBuffer = <String>[];
    void flushBullets() {
      if (bulletBuffer.isEmpty) return;
      for (final b in bulletBuffer) {
        out.add(Text('• $b', style: bulletStyle));
      }
      bulletBuffer.clear();
    }

    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        flushBullets();
        out.add(const SizedBox(height: 12));
        continue;
      }

      if (line.startsWith('[[img:') && line.endsWith(']]')) {
        flushBullets();
        final key = line.substring('[[img:'.length, line.length - 2).trim();
        out.add(_HelpImagePlaceholder(imageKey: key));
        out.add(const SizedBox(height: 12));
        continue;
      }

      if (line.startsWith('- ')) {
        bulletBuffer.add(line.substring(2).trim());
        continue;
      }
      if (line.startsWith('• ')) {
        bulletBuffer.add(line.substring(2).trim());
        continue;
      }

      flushBullets();
      addParagraph(line);
      out.add(const SizedBox(height: 12));
    }

    flushBullets();
    return out;
  }

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _parseBody(body, context),
              ),
            ),
    );
  }
}

class _HelpImagePlaceholder extends StatelessWidget {
  const _HelpImagePlaceholder({required this.imageKey});
  final String imageKey;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.image_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Скриншот: $imageKey',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
