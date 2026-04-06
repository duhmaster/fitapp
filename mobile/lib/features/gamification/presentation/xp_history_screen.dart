import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/core/widgets/error_state_widget.dart';
import 'package:fitflow/features/gamification/domain/xp_event.dart';
import 'package:fitflow/features/gamification/presentation/gamification_provider.dart';

class XpHistoryScreen extends ConsumerWidget {
  const XpHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final flags = ref.watch(gamificationFeatureFlagsProvider);
    final async = ref.watch(gamificationXpHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(tr('gam_xp_history_title'))),
      body: flags.when(
        data: (f) {
          if (!f.xpEnabled) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(tr('gam_feature_disabled_xp'), textAlign: TextAlign.center),
              ),
            );
          }
          return async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorStateWidget(message: e.toString(), onRetry: () => ref.invalidate(gamificationXpHistoryProvider)),
            data: (events) {
              if (events.isEmpty) {
                return Center(child: Text(tr('gam_xp_history_empty')));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: events.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) => _XpTile(event: events[i], tr: tr),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }
}

class _XpTile extends StatelessWidget {
  const _XpTile({required this.event, required this.tr});

  final XpEvent event;
  final String Function(String) tr;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final df = DateFormat.yMMMd(locale);
    final tf = DateFormat.Hm(locale);
    final when = event.createdAt;
    final dateStr = '${df.format(when)} ${tf.format(when)}';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        child: Text(
          event.deltaXp >= 0 ? '+${event.deltaXp}' : '${event.deltaXp}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: scheme.onPrimaryContainer,
          ),
        ),
      ),
      title: Text(event.label ?? event.reason, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(dateStr, style: Theme.of(context).textTheme.bodySmall),
      trailing: event.deltaXp >= 0
          ? Icon(Icons.trending_up_rounded, color: scheme.primary)
          : Icon(Icons.trending_flat_rounded, color: scheme.outline),
    );
  }
}
