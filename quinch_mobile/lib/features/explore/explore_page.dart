import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../data/models/product.dart';
import '../../shared/paging/paged_notifier.dart';
import '../../shared/paging/paged_scroll.dart';
import '../product/product_providers.dart';
import 'filters_sheet.dart';
import 'product_tile.dart';

class ExplorePage extends ConsumerStatefulWidget {
  const ExplorePage({super.key});

  @override
  ConsumerState<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends ConsumerState<ExplorePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(exploreProvider).status == PagedStatus.idle) {
        ref.read(exploreProvider.notifier).refresh();
      }
    });
  }

  void _setType(String? type) {
    final current = ref.read(exploreFiltersProvider);
    if (current.type == type) {
      return;
    }
    ref
        .read(exploreFiltersProvider.notifier)
        .set(
          ExploreFilters(
            categoryId: current.categoryId,
            type: type,
            priceMin: current.priceMin,
            priceMax: current.priceMax,
            sort: current.sort,
          ),
        );
    ref.read(exploreProvider.notifier).refresh();
  }

  void _openFilters() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => FiltersSheet(
        initial: ref.read(exploreFiltersProvider),
        onApply: (filters) {
          ref.read(exploreFiltersProvider.notifier).set(filters);
          ref.read(exploreProvider.notifier).refresh();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(exploreFiltersProvider);
    final state = ref.watch(exploreProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explorer'),
        actions: [
          IconButton(
            tooltip: 'Rechercher',
            icon: const Icon(Icons.search),
            onPressed: () => context.push(searchPath),
          ),
          IconButton(
            tooltip: 'Filtres',
            icon: Badge(
              isLabelVisible: filters.activeCount > 0,
              label: Text('${filters.activeCount}'),
              child: const Icon(Icons.tune),
            ),
            onPressed: _openFilters,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ChoiceChip(
                  label: const Text('Tous'),
                  selected: filters.type == null,
                  onSelected: (_) => _setType(null),
                ),
                ChoiceChip(
                  label: const Text('Produits'),
                  selected: filters.type == 'product',
                  onSelected: (_) => _setType('product'),
                ),
                ChoiceChip(
                  label: const Text('Services'),
                  selected: filters.type == 'service',
                  onSelected: (_) => _setType('service'),
                ),
              ],
            ),
          ),
          Expanded(
            child: PagedScroll<ProductCard>(
              state: state,
              crossAxisCount: 2,
              childAspectRatio: 0.72,
              onRefresh: () => ref.read(exploreProvider.notifier).refresh(),
              onLoadMore: () => ref.read(exploreProvider.notifier).loadMore(),
              itemBuilder: (context, card) => ProductTile(card: card),
              emptyIcon: Icons.search_off,
              emptyMessage: filters.isDefault
                  ? 'Aucune annonce pour le moment.'
                  : 'Aucune annonce ne correspond à ces filtres.',
            ),
          ),
        ],
      ),
    );
  }
}
