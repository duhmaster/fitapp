import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/core/locale/locale_provider.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    final inShell = GoRouterState.of(context).matchedLocation == '/feed';
    return Scaffold(
      appBar: inShell ? null : AppBar(title: Text(tr('feed'))),
      body: Center(
        child: Text(tr('home_feed_subtitle')),
      ),
    );
  }
}
