import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/core/widgets/empty_state_widget.dart';
import 'package:fitflow/core/widgets/error_state_widget.dart';
import 'package:fitflow/features/system_messages/data/system_messages_repository.dart';
import 'package:fitflow/features/system_messages/domain/system_message.dart';

final activeSystemMessagesProvider = StreamProvider<List<SystemMessage>>((ref) async* {
  final repo = ref.watch(systemMessagesRepositoryProvider);
  yield await repo.listActive(limit: 200, offset: 0);
  yield* Stream.periodic(const Duration(minutes: 5)).asyncMap((_) => repo.listActive(limit: 200, offset: 0));
});

final activeSystemMessagesCountProvider = StreamProvider<int>((ref) async* {
  final repo = ref.watch(systemMessagesRepositoryProvider);
  yield await repo.countActive();
  yield* Stream.periodic(const Duration(minutes: 5)).asyncMap((_) => repo.countActive());
});

class SystemMessagesScreen extends ConsumerWidget {
  const SystemMessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final async = ref.watch(activeSystemMessagesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('system_messages')),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(activeSystemMessagesProvider);
          ref.invalidate(activeSystemMessagesCountProvider);
        },
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorStateWidget(
            message: e.toString(),
            onRetry: () => ref.invalidate(activeSystemMessagesProvider),
          ),
          data: (list) {
            if (list.isEmpty) {
              return EmptyStateWidget(
                message: '${tr('no_system_messages')}\n${tr('no_system_messages_subtitle')}',
                icon: Icons.notifications_none,
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _MessageCard(m: list[i]),
            );
          },
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.m});
  final SystemMessage m;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              m.title,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              _formatDate(m.createdAt),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Text(m.body, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final d = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
  }
}

