import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/product.dart';
import '../../data/repositories/product_repository.dart';
import '../product/product_providers.dart';

/// Feuille de filtres de l'Explorer : catégorie, prix (FCFA), tri.
/// Les noms de paramètres envoyés sont ceux que lit le backend (`price_min`,
/// `price_max`, `sort_by`). Il n'existe pas de filtre « état » côté Explorer.
class FiltersSheet extends ConsumerStatefulWidget {
  const FiltersSheet({super.key, required this.initial, required this.onApply});

  final ExploreFilters initial;
  final void Function(ExploreFilters filters) onApply;

  @override
  ConsumerState<FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends ConsumerState<FiltersSheet> {
  late final TextEditingController _min;
  late final TextEditingController _max;
  String? _categoryId;
  ExploreSort? _sort;
  String? _priceError;

  @override
  void initState() {
    super.initState();
    _min = TextEditingController(
      text: widget.initial.priceMin?.toString() ?? '',
    );
    _max = TextEditingController(
      text: widget.initial.priceMax?.toString() ?? '',
    );
    _categoryId = widget.initial.categoryId;
    _sort = widget.initial.sort;
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  static String _sortLabel(ExploreSort? sort) => switch (sort) {
    null => 'Par défaut (récentes)',
    ExploreSort.recent => 'Plus récentes',
    ExploreSort.popular => 'Populaires',
    ExploreSort.priceAsc => 'Prix croissant',
    ExploreSort.priceDesc => 'Prix décroissant',
  };

  List<DropdownMenuItem<String?>> _categoryItems(List<Category> categories) {
    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(
        value: null,
        child: Text('Toutes les catégories'),
      ),
    ];
    for (final root in categories) {
      items.add(
        DropdownMenuItem<String?>(value: root.id, child: Text(root.name)),
      );
      for (final child in root.children) {
        items.add(
          DropdownMenuItem<String?>(
            value: child.id,
            child: Text('${root.name} › ${child.name}'),
          ),
        );
      }
    }
    return items;
  }

  void _apply() {
    final min = int.tryParse(_min.text.trim());
    final max = int.tryParse(_max.text.trim());
    if (min != null && max != null && min > max) {
      setState(() => _priceError = 'Le prix minimum dépasse le prix maximum.');
      return;
    }
    widget.onApply(
      ExploreFilters(
        categoryId: _categoryId,
        type: widget.initial.type,
        priceMin: min,
        priceMax: max,
        sort: _sort,
      ),
    );
    Navigator.of(context).pop();
  }

  void _reset() {
    setState(() {
      _min.clear();
      _max.clear();
      _categoryId = null;
      _sort = null;
      _priceError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Filtres', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            categories.when(
              data: (list) => InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Catégorie',
                  border: OutlineInputBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _categoryId,
                    isExpanded: true,
                    items: _categoryItems(list),
                    onChanged: (value) => setState(() => _categoryId = value),
                  ),
                ),
              ),
              loading: () => const LinearProgressIndicator(
                semanticsLabel: 'Chargement des catégories',
              ),
              error: (error, stackTrace) => const Text(
                'Les catégories ne sont pas disponibles pour le moment.',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _min,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Prix min (FCFA)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _max,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Prix max (FCFA)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            if (_priceError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _priceError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Trier par',
                border: OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<ExploreSort?>(
                  value: _sort,
                  isExpanded: true,
                  items: <ExploreSort?>[null, ...ExploreSort.values]
                      .map(
                        (s) => DropdownMenuItem<ExploreSort?>(
                          value: s,
                          child: Text(_sortLabel(s)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _sort = value),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _reset,
                    child: const Text('Réinitialiser'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _apply,
                    child: const Text('Appliquer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
