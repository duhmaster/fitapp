import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitflow/core/locale/locale_provider.dart';
import 'package:fitflow/core/network/geo_repository.dart';

/// A field that opens a search dialog to select a city from DaData suggestions.
class CityPickerField extends ConsumerStatefulWidget {
  const CityPickerField({
    super.key,
    this.initialCity = '',
    this.label = '',
    required this.onSearch,
    required this.onChanged,
  });
  final String initialCity;
  final String label;
  final Future<List<CitySuggestion>> Function(String query) onSearch;
  final void Function(String? city) onChanged;

  @override
  ConsumerState<CityPickerField> createState() => _CityPickerFieldState();
}

class _CityPickerFieldState extends ConsumerState<CityPickerField> {
  late TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialCity);
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _openPicker() async {
    String query = _controller.text;
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => _CitySearchDialog(
        initialQuery: query,
        onSearch: widget.onSearch,
      ),
    );
    if (selected != null && mounted) {
      _controller.text = selected;
      widget.onChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    return InkWell(
      onTap: _openPicker,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: widget.label.isNotEmpty ? widget.label : tr('city'),
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          _controller.text.isEmpty ? '' : _controller.text,
          style: _controller.text.isEmpty
              ? TextStyle(color: Theme.of(context).hintColor)
              : null,
        ),
      ),
    );
  }
}

class _CitySearchDialog extends ConsumerStatefulWidget {
  const _CitySearchDialog({
    required this.initialQuery,
    required this.onSearch,
  });
  final String initialQuery;
  final Future<List<CitySuggestion>> Function(String query) onSearch;

  @override
  ConsumerState<_CitySearchDialog> createState() => _CitySearchDialogState();
}

class _CitySearchDialogState extends ConsumerState<_CitySearchDialog> {
  late TextEditingController _queryController;
  List<CitySuggestion> _items = [];
  bool _loading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.initialQuery);
    if (widget.initialQuery.isNotEmpty) {
      _runSearch(widget.initialQuery);
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _runSearch(String q) async {
    if (q.length < 2) {
      setState(() => _items = []);
      return;
    }
    setState(() => _loading = true);
    try {
      final list = await widget.onSearch(q);
      if (mounted) setState(() { _items = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _items = []; _loading = false; });
    }
  }

  void _onQueryChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _runSearch(v));
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(trProvider);
    return AlertDialog(
      title: Text(tr('city')),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 320, maxHeight: MediaQuery.sizeOf(context).height * 0.6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _queryController,
              decoration: InputDecoration(
                hintText: tr('city_search_hint'),
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
              onChanged: _onQueryChanged,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? Center(
                          child: Text(
                            _queryController.text.length < 2
                                ? tr('city_min_chars')
                                : tr('city_no_results'),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      : ListView.builder(
                          itemCount: _items.length,
                          itemBuilder: (_, i) {
                            final c = _items[i];
                            return ListTile(
                              title: Text(c.name),
                              onTap: () => Navigator.of(context).pop(c.name),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
      ],
    );
  }
}
