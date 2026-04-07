import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitflow/core/layout/responsive.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/core/router/app_router.dart';
import 'package:fitflow/features/workouts/presentation/widgets/template_picker_dialog.dart';
import 'package:fitflow/core/widgets/barbell_logo.dart';
import 'package:fitflow/features/auth/presentation/auth_state.dart';
import 'package:fitflow/features/gamification/presentation/gamification_provider.dart';
import 'package:fitflow/features/profile/presentation/profile_provider.dart';
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

  void _closeDrawerIfOpen(BuildContext context) {
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold?.isDrawerOpen ?? false) scaffold?.closeDrawer();
  }

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
    // Close drawer first so `pop()` doesn't accidentally pop the newly pushed route.
    Navigator.of(context).pop();
    Future.microtask(navigate);
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

  void _goHome(BuildContext context) {
    _closeDrawerIfOpen(context);
    _go(context, '/home');
  }

  /// High-contrast XP bar on [primaryContainer] (thin Material bars are hard to see on tinted headers).
  Widget _drawerHeaderXpProgressBar(ColorScheme scheme, {required bool loading, double? value}) {
    assert(loading || value != null);
    final onCont = scheme.onPrimaryContainer;
    final track = onCont.withValues(alpha: 0.22);
    final fill = onCont.withValues(alpha: 0.92);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        height: 10,
        decoration: BoxDecoration(
          color: track,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: onCont.withValues(alpha: 0.38), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.centerLeft,
        child: loading
            ? LinearProgressIndicator(
                minHeight: 10,
                backgroundColor: Colors.transparent,
                color: fill,
              )
            : LinearProgressIndicator(
                value: value,
                minHeight: 10,
                backgroundColor: Colors.transparent,
                color: fill,
              ),
      ),
    );
  }

  Widget _drawerUserHeader(BuildContext context, String Function(String) tr) {
    final scheme = Theme.of(context).colorScheme;
    final profileAsync = ref.watch(profileProvider);
    final flags = ref.watch(gamificationFeatureFlagsProvider);
    final gamAsync = ref.watch(gamificationProfileProvider);
    final xpOn = flags.valueOrNull?.xpEnabled ?? false;

    void openProfile() {
      _drawerNavigate(context, () {
        if (_trainerMode) {
          _push(context, '/trainer/profile');
        } else {
          _go(context, '/profile');
        }
      });
    }

    void openSettings() {
      _drawerNavigate(context, () => _push(context, '/options'));
    }

    return Material(
      color: scheme.primaryContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 0, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              InkWell(
                onTap: openProfile,
                borderRadius: BorderRadius.circular(40),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: profileAsync.when(
                    loading: () => CircleAvatar(
                      radius: 26,
                      backgroundColor: scheme.surfaceContainerHighest,
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: scheme.primary),
                      ),
                    ),
                    error: (_, __) => CircleAvatar(
                      radius: 26,
                      backgroundColor: scheme.surfaceContainerHighest,
                      child: Icon(Icons.person, color: scheme.onSurfaceVariant),
                    ),
                    data: (p) {
                      final url = p.avatarUrl?.trim();
                      final hasPhoto = url != null && url.isNotEmpty;
                      return CircleAvatar(
                        radius: 26,
                        backgroundColor: scheme.surfaceContainerHighest,
                        backgroundImage: hasPhoto ? NetworkImage(url) : null,
                        child: hasPhoto ? null : Icon(Icons.person, size: 30, color: scheme.onSurfaceVariant),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: profileAsync.when(
                  loading: () => Text(tr('loading'), style: Theme.of(context).textTheme.titleSmall),
                  error: (_, __) => Text(tr('profile'), style: Theme.of(context).textTheme.titleMedium),
                  data: (p) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        p.displayName.isNotEmpty ? p.displayName : tr('profile'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (xpOn) ...[
                        const SizedBox(height: 4),
                        gamAsync.when(
                          loading: () => Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '…',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                              const SizedBox(height: 6),
                              _drawerHeaderXpProgressBar(scheme, loading: true),
                            ],
                          ),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (g) {
                            final double barValue = g.xpForNextLevel <= 0 ? 1.0 : g.levelProgress;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${tr('level')} ${g.level}',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                _drawerHeaderXpProgressBar(scheme, loading: false, value: barValue),
                              ],
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: tr('options'),
                onPressed: openSettings,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _drawerSectionHeader(BuildContext context, String title, {bool first = false}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, first ? 12 : 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _homeTitleBar(BuildContext context, String Function(String) tr, {required bool narrow}) {
    final nameText = Text(tr('app_name'), overflow: narrow ? TextOverflow.ellipsis : null);
    return Tooltip(
      message: tr('nav_home'),
      child: InkWell(
        onTap: () => _goHome(context),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BarbellLogo(size: 28),
              const SizedBox(width: 8),
              if (narrow) Flexible(child: nameText) else nameText,
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final index = _selectedIndex(widget.location);
    final isWide = context.isWide;
    final countAsync = ref.watch(activeSystemMessagesCountProvider);

    final drawer = Drawer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _drawerUserHeader(context, tr),
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
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
          if (!_trainerMode) ...[
            _drawerSectionHeader(context, tr('nav_drawer_section_today'), first: true),
            ListTile(
              leading: const Icon(Icons.format_list_bulleted),
              title: Text(tr('all_workouts')),
              onTap: () => _drawerNavigate(context, () => _go(context, '/home')),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: Text(tr('calendar')),
              onTap: () => _drawerNavigate(context, () => _push(context, '/calendar')),
            ),
            _drawerSectionHeader(context, tr('nav_drawer_section_profile_people')),
            ListTile(
              leading: const Icon(Icons.dynamic_feed),
              title: Text(tr('feed')),
              onTap: () => _drawerNavigate(context, () => _go(context, '/feed')),
            ),
            ListTile(
              leading: const Icon(Icons.sports_martial_arts),
              title: Text(tr('my_trainers')),
              onTap: () => _drawerNavigate(context, () => _push(context, '/my-trainers')),
            ),
            _drawerSectionHeader(context, tr('nav_drawer_section_progress')),
            ListTile(
              leading: const Icon(Icons.emoji_events_outlined),
              title: Text(tr('nav_drawer_progress_title')),
              subtitle: Text(tr('nav_drawer_progress_subtitle')),
              onTap: () => _drawerNavigate(context, () => _go(context, '/progress')),
            ),
            _drawerSectionHeader(context, tr('nav_drawer_section_events')),
            ListTile(
              leading: const Icon(Icons.groups),
              title: Text(tr('group_trainings')),
              subtitle: Text(tr('nav_drawer_group_trainings_member_sub')),
              onTap: () => _drawerNavigate(context, () => _go(context, '/group-trainings')),
            ),
            ListTile(
              leading: const Icon(Icons.fitness_center),
              title: Text(tr('my_gyms')),
              onTap: () => _drawerNavigate(context, () => _push(context, '/gym')),
            ),
            _drawerSectionHeader(context, tr('nav_drawer_section_library')),
            ExpansionTile(
              leading: const Icon(Icons.tune),
              title: Text(tr('nav_drawer_library_expand_title')),
              children: [
                ListTile(
                  leading: const Icon(Icons.list_alt, size: 20),
                  title: Text(tr('workout_templates')),
                  onTap: () => _drawerNavigate(context, () => _push(context, '/templates')),
                ),
                ListTile(
                  leading: const Icon(Icons.menu_book_outlined, size: 20),
                  title: Text(tr('exercises_base')),
                  onTap: () => _drawerNavigate(context, () => _go(context, '/exercises')),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.people),
              title: Text(tr('trainees')),
              onTap: () => _drawerNavigate(context, () => _push(context, '/trainer/trainees')),
            ),
            ListTile(
              leading: const Icon(Icons.dynamic_feed),
              title: Text(tr('feed')),
              onTap: () => _drawerNavigate(context, () => _go(context, '/feed')),
            ),
            _drawerSectionHeader(context, tr('nav_drawer_section_trainer_groups')),
            ListTile(
              leading: const Icon(Icons.category),
              title: Text(tr('group_training_templates')),
              onTap: () => _drawerNavigate(context, () => _push(context, '/trainer/group-training-templates')),
            ),
            ListTile(
              leading: const Icon(Icons.groups),
              title: Text(tr('group_trainings')),
              subtitle: Text(tr('nav_drawer_group_trainings_trainer_sub')),
              onTap: () => _drawerNavigate(context, () => _push(context, '/trainer/group-trainings')),
            ),
            _drawerSectionHeader(context, tr('nav_drawer_section_trainer_gam')),
            ListTile(
              leading: const Icon(Icons.emoji_events_outlined),
              title: Text(tr('gam_trainer_menu_rankings')),
              onTap: () => _drawerNavigate(context, () => _push(context, '/trainer/rankings')),
            ),
            ListTile(
              leading: const Icon(Icons.workspace_premium_outlined),
              title: Text(tr('gam_trainer_menu_achievements')),
              onTap: () => _drawerNavigate(context, () => _push(context, '/trainer/achievements')),
            ),
            _drawerSectionHeader(context, tr('nav_drawer_section_schedule')),
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
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: Text(tr('help')),
            onTap: () => _drawerNavigate(context, () => _push(context, '/help')),
          ),
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
          title: _homeTitleBar(context, tr, narrow: false),
          actions: [
            IconButton(
              tooltip: tr('system_messages'),
              icon: _BellWithBadge(countAsync: countAsync),
            onPressed: () {
              _closeDrawerIfOpen(context);
              _push(context, '/system-messages');
            },
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
              _closeDrawerIfOpen(context);
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
        title: _homeTitleBar(context, tr, narrow: true),
        actions: [
          IconButton(
            tooltip: tr('system_messages'),
            icon: _BellWithBadge(countAsync: countAsync),
            onPressed: () {
              _closeDrawerIfOpen(context);
              _push(context, '/system-messages');
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              _closeDrawerIfOpen(context);
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
