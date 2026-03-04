import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/features/auth/presentation/auth_state.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FITFLOW'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(logoutProvider)();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _NavTile(
            title: 'Profile',
            subtitle: 'View and edit your profile',
            icon: Icons.person,
            onTap: () => context.push('/profile'),
          ),
          _NavTile(
            title: 'Gym',
            subtitle: 'Search gyms, check-in',
            icon: Icons.fitness_center,
            onTap: () => context.push('/gym'),
          ),
          _NavTile(
            title: 'Workout',
            subtitle: 'Builder and active workout',
            icon: Icons.directions_run,
            onTap: () => context.push('/workout'),
          ),
          _NavTile(
            title: 'Progress',
            subtitle: 'Charts and metrics',
            icon: Icons.show_chart,
            onTap: () => context.push('/progress'),
          ),
          _NavTile(
            title: 'Feed',
            subtitle: 'Social feed',
            icon: Icons.dynamic_feed,
            onTap: () => context.push('/feed'),
          ),
          _NavTile(
            title: 'Trainer',
            subtitle: 'Trainer dashboard',
            icon: Icons.sports_gymnastics,
            onTap: () => context.push('/trainer'),
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
