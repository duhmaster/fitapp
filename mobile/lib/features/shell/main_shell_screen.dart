import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/core/layout/responsive.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/core/router/app_router.dart';
import 'package:fitflow/features/workouts/presentation/widgets/template_picker_dialog.dart';
import 'package:fitflow/core/widgets/barbell_logo.dart';
import 'package:fitflow/features/auth/presentation/auth_state.dart';
import 'package:fitflow/features/system_messages/presentation/system_messages_screen.dart';

class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({super.key, required this.child, required this.location});

  final Widget child;
  final String location;

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  bool _trainerMode = false;

  int _selectedIndex(String location) {
    final path = location.split('?').first;
    if (path == '/calendar' || path.startsWith('/calendar/')) return 6;
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
    final countAsync = ref.watch(activeSystemMessagesCountProvider);

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
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment<bool>(
                  value: false,
                  icon: const Icon(Icons.directions_run),
                  label: Text(tr('mode_my_workouts')),
                ),
                ButtonSegment<bool>(
                  value: true,
                  icon: const Icon(Icons.sports_gymnastics),
                  label: Text(tr('mode_i_am_trainer')),
                ),
              ],
              selected: {_trainerMode},
              onSelectionChanged: (s) => setState(() => _trainerMode = s.first),
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.resolveWith<Color?>((states) {
                  final scheme = Theme.of(context).colorScheme;
                  if (states.contains(MaterialState.selected)) return scheme.primaryContainer;
                  return scheme.surfaceContainerHighest;
                }),
                foregroundColor: MaterialStateProperty.resolveWith<Color?>((states) {
                  final scheme = Theme.of(context).colorScheme;
                  if (states.contains(MaterialState.selected)) return scheme.onPrimaryContainer;
                  return scheme.onSurfaceVariant;
                }),
                overlayColor: MaterialStateProperty.resolveWith<Color?>((states) {
                  final scheme = Theme.of(context).colorScheme;
                  if (states.contains(MaterialState.selected)) return scheme.primary.withOpacity(0.12);
                  return scheme.onSurface.withOpacity(0.08);
                }),
              ),
            ),
          ),
          if (!_trainerMode) ...[
            ListTile(
              leading: const Icon(Icons.person),
              title: Text(tr('profile')),
              onTap: () => _drawerNavigate(context, () => _go(context, '/profile')),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: Text(tr('calendar')),
              onTap: () => _drawerNavigate(context, () => _push(context, '/calendar')),
            ),
            ListTile(
              leading: const Icon(Icons.format_list_bulleted),
              title: Text(tr('all_workouts')),
              onTap: () => _drawerNavigate(context, () => _go(context, '/home')),
            ),
            ExpansionTile(
              leading: const Icon(Icons.tune),
              title: Text(tr('workout_settings')),
              children: [
                ListTile(
                  leading: const Icon(Icons.fitness_center, size: 20),
                  title: Text(tr('my_gyms')),
                  onTap: () => _drawerNavigate(context, () => _push(context, '/gym')),
                ),
                ListTile(
                  leading: const Icon(Icons.sports_martial_arts, size: 20),
                  title: Text(tr('my_trainers')),
                  onTap: () => _drawerNavigate(context, () => _push(context, '/my-trainers')),
                ),
                ListTile(
                  leading: const Icon(Icons.list_alt, size: 20),
                  title: Text(tr('workout_templates')),
                  onTap: () => _drawerNavigate(context, () => _push(context, '/templates')),
                ),
                ListTile(
                  leading: const Icon(Icons.fitness_center, size: 20),
                  title: Text(tr('exercises_base')),
                  onTap: () => _drawerNavigate(context, () => _go(context, '/exercises')),
                ),
              ],
            ),
            ListTile(
              leading: const Icon(Icons.show_chart),
              title: Text(tr('statistics')),
              onTap: () => _drawerNavigate(context, () => _go(context, '/progress')),
            ),
          ] else ...[
            ListTile(
              leading: const Icon(Icons.person),
              title: Text(tr('trainer_profile')),
              onTap: () => _drawerNavigate(context, () => _push(context, '/trainer/profile')),
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: Text(tr('trainees')),
              onTap: () => _drawerNavigate(context, () => _push(context, '/trainer/trainees')),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: Text(tr('calendar')),
              onTap: () => _drawerNavigate(context, () => _push(context, '/calendar')),
            ),
            ListTile(
              leading: const Icon(Icons.fitness_center),
              title: Text(tr('my_gyms')),
              onTap: () => _drawerNavigate(context, () => _push(context, '/gym')),
            ),
          ],
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
              tooltip: tr('system_messages'),
              icon: _BellWithBadge(countAsync: countAsync),
              onPressed: () => _push(context, '/system-messages'),
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                ref.read(authRedirectNotifierProvider).setLoggedIn(false);
                if (context.mounted) context.go('/login');
                try {
                  await ref.read(logoutProvider)();
                } finally {
                  invalidateUserScopedProviders(ref as Ref);
                }
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
            tooltip: tr('system_messages'),
            icon: _BellWithBadge(countAsync: countAsync),
            onPressed: () => _push(context, '/system-messages'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              ref.read(authRedirectNotifierProvider).setLoggedIn(false);
              if (context.mounted) context.go('/login');
              try {
                await ref.read(logoutProvider)();
              } finally {
                invalidateUserScopedProviders(ref as Ref);
              }
            },
          ),
        ],
      ),
      drawer: drawer,
      body: body,
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

class _BellWithBadge extends StatelessWidget {
  const _BellWithBadge({required this.countAsync});

  final AsyncValue<int> countAsync;

  @override
  Widget build(BuildContext context) {
    final count = countAsync.valueOrNull ?? 0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.notifications_none),
        if (count > 0)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onError,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ),
      ],
    );
  }
}
