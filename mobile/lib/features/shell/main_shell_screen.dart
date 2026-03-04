import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/core/widgets/barbell_logo.dart';
import 'package:fitflow/features/auth/presentation/auth_state.dart';
import 'package:fitflow/features/feed/feed_screen.dart';
import 'package:fitflow/features/profile/presentation/profile_screen.dart';
import 'package:fitflow/features/progress/presentation/progress_screen.dart';
import 'package:fitflow/features/workouts/data/workout_repository.dart';
import 'package:fitflow/features/workouts/presentation/workouts_list_screen.dart';

class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({super.key, required this.child, required this.location});

  final Widget child;
  final String location;

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  int _selectedIndex(String location) {
    final path = location.split('?').first;
    if (path == '/profile' || path.startsWith('/profile/')) return 1;
    if (path == '/progress' || path.startsWith('/progress/')) return 3;
    if (path == '/feed' || path.startsWith('/feed/')) return 4;
    return 0; // home (/ or /home)
  }

  /// Navigate then close drawer so the correct page opens and drawer doesn't block.
  void _drawerNavigate(BuildContext context, VoidCallback navigate) {
    navigate();
    Navigator.of(context).pop();
  }

  void _onItemTapped(int index) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/profile');
        break;
      case 3:
        context.go('/progress');
        break;
      case 4:
        context.go('/feed');
        break;
    }
  }

  Future<void> _onStartWorkout() async {
    try {
      final w = await ref.read(workoutRepositoryProvider).createWorkout();
      if (mounted) context.push('/workout/${w.id}');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final index = _selectedIndex(widget.location);
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BarbellLogo(size: 28),
            const SizedBox(width: 8),
            Text(tr('app_name')),
          ],
        ),
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
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const BarbellLogo(size: 40),
                  const SizedBox(height: 8),
                  Text(tr('app_name'), style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
            ),
            ListTile(leading: const Icon(Icons.person), title: Text(tr('profile')), onTap: () => _drawerNavigate(context, () => context.go('/profile'))),
            ListTile(leading: const Icon(Icons.fitness_center), title: Text(tr('gym')), onTap: () => _drawerNavigate(context, () => context.push('/gym'))),
            ListTile(leading: const Icon(Icons.directions_run), title: Text(tr('workouts')), onTap: () => _drawerNavigate(context, () => context.go('/home'))),
            ListTile(leading: const Icon(Icons.show_chart), title: Text(tr('progress')), onTap: () => _drawerNavigate(context, () => context.go('/progress'))),
            ListTile(leading: const Icon(Icons.dynamic_feed), title: Text(tr('feed')), onTap: () => _drawerNavigate(context, () => context.go('/feed'))),
            ListTile(leading: const Icon(Icons.sports_gymnastics), title: Text(tr('trainer')), onTap: () => _drawerNavigate(context, () => context.push('/trainer'))),
            ListTile(leading: const Icon(Icons.settings), title: Text(tr('options')), onTap: () => _drawerNavigate(context, () => context.push('/options'))),
          ],
        ),
      ),
      body: widget.child,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(context, 0, Icons.home, tr('workouts'), index == 0),
            _navItem(context, 1, Icons.person, tr('profile'), index == 1),
            const SizedBox(width: 56),
            _navItem(context, 3, Icons.show_chart, tr('progress'), index == 3),
            _navItem(context, 4, Icons.article, tr('feed'), index == 4),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: _onStartWorkout,
        child: const Icon(Icons.play_arrow, size: 32),
      ),
    );
  }

  Widget _navItem(BuildContext context, int i, IconData icon, String label, bool selected) {
    return InkWell(
      onTap: () => _onItemTapped(i),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: selected ? Theme.of(context).colorScheme.primary : null),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: selected ? Theme.of(context).colorScheme.primary : null),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
