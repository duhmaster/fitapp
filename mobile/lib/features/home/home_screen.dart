import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/features/auth/presentation/auth_state.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(trProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('app_name')),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/options'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(logoutProvider)();
              invalidateUserScopedProviders(ref as Ref);
              ref.read(authRedirectNotifierProvider).setLoggedIn(false);
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _NavTile(
            title: tr('profile'),
            subtitle: tr('home_profile_subtitle'),
            icon: Icons.person,
            onTap: () => context.push('/profile'),
          ),
          _NavTile(
            title: tr('gym'),
            subtitle: tr('home_gym_subtitle'),
            icon: Icons.fitness_center,
            onTap: () => context.push('/gym'),
          ),
          _NavTile(
            title: tr('workouts'),
            subtitle: tr('home_workout_subtitle'),
            icon: Icons.directions_run,
            onTap: () => context.push('/workouts'),
          ),
          _NavTile(
            title: tr('progress'),
            subtitle: tr('home_progress_subtitle'),
            icon: Icons.show_chart,
            onTap: () => context.push('/progress'),
          ),
          _NavTile(
            title: tr('feed'),
            subtitle: tr('home_feed_subtitle'),
            icon: Icons.dynamic_feed,
            onTap: () => context.push('/feed'),
          ),
          _NavTile(
            title: tr('trainer'),
            subtitle: tr('home_trainer_subtitle'),
            icon: Icons.sports_gymnastics,
            onTap: () => context.push('/trainer'),
          ),
          _NavTile(
            title: tr('options'),
            subtitle: tr('language'),
            icon: Icons.settings,
            onTap: () => context.push('/options'),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
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
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        onTap: onTap,
      ),
    );
  }
}
