import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/core/layout/responsive.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/core/router/app_router.dart';
import 'package:fitflow/features/workouts/presentation/widgets/template_picker_dialog.dart';
import 'package:fitflow/core/widgets/barbell_logo.dart';
import 'package:fitflow/features/auth/presentation/auth_state.dart';

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
    if (path == '/exercises' || path.startsWith('/exercises')) return 2;
    if (path == '/progress' || path.startsWith('/progress/')) return 4;
    if (path == '/feed' || path.startsWith('/feed/')) return 5;
    return 0; // home (/ or /home)
  }

  GoRouter get _router => ref.read(appRouterProvider);

  void _go(BuildContext context, String path) => _router.go(path);
  void _push(BuildContext context, String path) => _router.push(path);

  void _drawerNavigate(BuildContext context, VoidCallback navigate) {
    navigate();
    Navigator.of(context).pop();
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        _go(context, '/home');
        break;
      case 1:
        _go(context, '/profile');
        break;
      case 2:
        _go(context, '/exercises');
        break;
      case 4:
        _go(context, '/progress');
        break;
      case 5:
        _go(context, '/feed');
        break;
    }
  }

  Future<void> _onStartWorkout() async {
    if (!mounted) return;
    await showTemplatePickerDialog(context, ref);
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final index = _selectedIndex(widget.location);
    final isWide = context.isWide;

    final drawer = Drawer(
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
          ListTile(leading: const Icon(Icons.person), title: Text(tr('profile')), onTap: () => _drawerNavigate(context, () => _go(context, '/profile'))),
          ListTile(leading: const Icon(Icons.fitness_center), title: Text(tr('gym')), onTap: () => _drawerNavigate(context, () => _push(context, '/gym'))),
          ListTile(leading: const Icon(Icons.directions_run), title: Text(tr('workouts')), onTap: () => _drawerNavigate(context, () => _go(context, '/home'))),
          ListTile(leading: const Icon(Icons.fitness_center), title: Text(tr('exercises_base')), onTap: () => _drawerNavigate(context, () => _go(context, '/exercises'))),
          ListTile(leading: const Icon(Icons.list_alt), title: Text(tr('templates')), onTap: () => _drawerNavigate(context, () => _push(context, '/templates'))),
          ListTile(leading: const Icon(Icons.play_circle), title: Text(tr('current_workout')), onTap: () => _drawerNavigate(context, () => _push(context, '/current-workout'))),
          ListTile(leading: const Icon(Icons.timer), title: Text(tr('timers')), onTap: () => _drawerNavigate(context, () => _push(context, '/timers'))),
          ListTile(leading: const Icon(Icons.show_chart), title: Text(tr('progress')), onTap: () => _drawerNavigate(context, () => _go(context, '/progress'))),
          ListTile(leading: const Icon(Icons.dynamic_feed), title: Text(tr('feed')), onTap: () => _drawerNavigate(context, () => _go(context, '/feed'))),
          ListTile(leading: const Icon(Icons.sports_gymnastics), title: Text(tr('trainer')), onTap: () => _drawerNavigate(context, () => _push(context, '/trainer'))),
          ListTile(leading: const Icon(Icons.help_outline), title: Text(tr('help')), onTap: () => _drawerNavigate(context, () => _push(context, '/help'))),
          ListTile(leading: const Icon(Icons.settings), title: Text(tr('options')), onTap: () => _drawerNavigate(context, () => _push(context, '/options'))),
        ],
      ),
    );

    final body = SafeArea(
      child: isWide ? ResponsiveCenter(child: widget.child) : widget.child,
    );

    if (isWide) {
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
                ref.read(authRedirectNotifierProvider).setLoggedIn(false);
                if (context.mounted) _router.go('/login');
              },
            ),
          ],
        ),
        drawer: drawer,
        body: body,
      );
    }

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
            Flexible(child: Text(tr('app_name'), overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(logoutProvider)();
              ref.read(authRedirectNotifierProvider).setLoggedIn(false);
              if (context.mounted) _router.go('/login');
            },
          ),
        ],
      ),
      drawer: drawer,
      body: body,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(context, 0, Icons.home, tr('workouts'), index == 0),
            _navItem(context, 1, Icons.person, tr('profile'), index == 1),
            _navItem(context, 2, Icons.fitness_center, tr('exercises'), index == 2),
            const SizedBox(width: 56),
            _navItem(context, 4, Icons.show_chart, tr('progress'), index == 4),
            _navItem(context, 5, Icons.article, tr('feed'), index == 5),
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
      onTap: () => _onItemTapped(context, i),
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
