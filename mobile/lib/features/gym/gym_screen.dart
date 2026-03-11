import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/core/network/geo_repository.dart';
import 'package:fitflow/features/gym/data/gym_repository.dart';
import 'package:fitflow/features/profile/data/profile_repository.dart';

final myGymsProvider = FutureProvider<List<Gym>>((ref) {
  return ref.watch(gymRepositoryProvider).listMyGyms();
});

class GymScreen extends ConsumerStatefulWidget {
  const GymScreen({super.key});

  @override
  ConsumerState<GymScreen> createState() => _GymScreenState();
}

class _GymScreenState extends ConsumerState<GymScreen> {
  Future<void> _refresh() async {
    ref.invalidate(myGymsProvider);
  }

  Future<void> _removeGym(Gym gym) async {
    final tr = ref.read(trProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('delete')),
        content: Text('${tr('gym')}: ${gym.name}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('delete'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(gymRepositoryProvider).removeMyGym(gym.id);
      await _refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('saved'))));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _showGymDetail(Gym gym) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(gym.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (gym.city != null && gym.city!.isNotEmpty) Text('${ref.read(trProvider)('city')}: ${gym.city}'),
              if (gym.address != null && gym.address!.isNotEmpty) ...[const SizedBox(height: 8), Text(gym.address!)],
              if (gym.contactPhone != null && gym.contactPhone!.isNotEmpty) ...[const SizedBox(height: 8), Text('Tel: ${gym.contactPhone}')],
              if (gym.contactUrl != null && gym.contactUrl!.isNotEmpty) ...[const SizedBox(height: 8), Text('URL: ${gym.contactUrl}')],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(MaterialLocalizations.of(ctx).okButtonLabel)),
        ],
      ),
    );
  }

  Future<void> _openAddGym() async {
    final tr = ref.read(trProvider);
    String? initialCity;
    try {
      final profile = await ref.read(profileRepositoryProvider).getProfile();
      initialCity = profile.city;
    } catch (_) {}
    if (!mounted) return;
    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => _AddGymByNameDialog(
        tr: tr,
        gymRepo: ref.read(gymRepositoryProvider),
        geoRepo: ref.read(geoRepositoryProvider),
        initialCity: initialCity,
      ),
    );
    if (added == true) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    final async = ref.watch(myGymsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('my_gyms')),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _openAddGym),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${tr('error_label')}: $e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.fitness_center, size: 64, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(tr('gym_optional'), style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _openAddGym,
                    icon: const Icon(Icons.add),
                    label: Text(tr('add_gym')),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (_, i) {
                final g = list[i];
                return Card(
                  child: ListTile(
                    title: Text(g.name),
                    subtitle: Text([if (g.city != null && g.city!.isNotEmpty) g.city, g.address].where((e) => e != null && e.isNotEmpty).join(' • ') ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _removeGym(g),
                    ),
                    onTap: () => _showGymDetail(g),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddGym,
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Dialog: city picker + gym name. Suggestions from saved gyms filtered by city.
/// On select suggestion → add by gym_id. On new name → create gym (with city) and add.
class _AddGymByNameDialog extends StatefulWidget {
  const _AddGymByNameDialog({
    required this.tr,
    required this.gymRepo,
    required this.geoRepo,
    this.initialCity,
  });
  final String Function(String) tr;
  final GymRepository gymRepo;
  final GeoRepository geoRepo;
  final String? initialCity;

  @override
  State<_AddGymByNameDialog> createState() => _AddGymByNameDialogState();
}

class _AddGymByNameDialogState extends State<_AddGymByNameDialog> {
  final TextEditingController _nameController = TextEditingController();
  List<Gym> _suggestions = [];
  bool _loading = false;
  Gym? _selectedGym;
  String? _selectedCity;

  @override
  void initState() {
    super.initState();
    _selectedCity = widget.initialCity;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.length < 1) {
      setState(() => _suggestions = []);
      return;
    }
    setState(() => _loading = true);
    final list = await widget.gymRepo.searchGyms(
      query: q,
      city: _selectedCity,
      limit: 10,
    );
    if (mounted) setState(() { _suggestions = list; _loading = false; });
  }

  void _selectSuggestion(Gym gym) {
    setState(() {
      _selectedGym = gym;
      _nameController.text = gym.name;
    });
  }

  void _clearSelection() {
    setState(() => _selectedGym = null);
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    try {
      if (_selectedGym != null) {
        await widget.gymRepo.addMyGym(gymId: _selectedGym!.id);
      } else {
        await widget.gymRepo.addMyGym(name: name, city: _selectedCity);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = widget.tr;
    return AlertDialog(
      title: Text(tr('add_gym')),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(tr('city'), style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              InkWell(
                onTap: () async {
                  final c = await showDialog<CitySuggestion>(
                    context: context,
                    builder: (dctx) => _CitySearchDialog(
                      title: tr('city'),
                      initialQuery: _selectedCity ?? '',
                      onSearch: (q) => widget.geoRepo.suggestCities(query: q),
                    ),
                  );
                  if (c != null && mounted) {
                    setState(() {
                      _selectedCity = c.name;
                      _suggestions = [];
                      _selectedGym = null;
                    });
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.arrow_drop_down),
                  ),
                  child: Text(_selectedCity?.isNotEmpty == true ? _selectedCity! : tr('gym_optional')),
                ),
              ),
              const SizedBox(height: 16),
              Text(tr('gym'), style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: tr('gym_optional'),
                  border: const OutlineInputBorder(),
                  suffixIcon: _selectedGym != null
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _clearSelection,
                        )
                      : null,
                ),
                autofocus: true,
                onChanged: (v) {
                  setState(() {
                    if (_selectedGym != null && _selectedGym!.name != v) _selectedGym = null;
                  });
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (_nameController.text == v) _search(v.trim());
                  });
                },
              ),
              if (_loading) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
              if (_suggestions.isNotEmpty && _selectedGym == null) ...[
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _suggestions.length,
                    itemBuilder: (_, i) {
                      final g = _suggestions[i];
                      return ListTile(
                        dense: true,
                        title: Text(g.name),
                        subtitle: (g.city != null && g.city!.isNotEmpty) ? Text(g.city!) : null,
                        onTap: () => _selectSuggestion(g),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('cancel'))),
        FilledButton(
          onPressed: _nameController.text.trim().isEmpty
              ? null
              : _submit,
          child: Text(tr('add_gym')),
        ),
      ],
    );
  }
}

class _CitySearchDialog extends StatefulWidget {
  const _CitySearchDialog({
    required this.title,
    required this.initialQuery,
    required this.onSearch,
  });
  final String title;
  final String initialQuery;
  final Future<List<CitySuggestion>> Function(String query) onSearch;

  @override
  State<_CitySearchDialog> createState() => _CitySearchDialogState();
}

class _CitySearchDialogState extends State<_CitySearchDialog> {
  late TextEditingController _controller;
  List<CitySuggestion> _items = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    if (widget.initialQuery.length >= 2) _runSearch(widget.initialQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String q) async {
    if (q.length < 2) {
      setState(() => _items = []);
      return;
    }
    setState(() => _loading = true);
    final list = await widget.onSearch(q);
    if (mounted) setState(() { _items = list; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 320,
        height: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Введите город',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              onChanged: (v) {
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (_controller.text == v) _runSearch(v);
                });
              },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (_, i) {
                        final c = _items[i];
                        return ListTile(
                          title: Text(c.name),
                          onTap: () => Navigator.pop(context, c),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
