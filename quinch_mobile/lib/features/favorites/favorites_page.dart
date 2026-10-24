import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/format/fcfa.dart';
import '../../core/network/api_error.dart';
import '../../data/models/product.dart';
import '../../shared/paging/paged_notifier.dart';
import '../../shared/paging/paged_scroll.dart';
import '../../shared/widgets/product_widgets.dart';
import '../product/product_providers.dart';

class FavoritesPage extends ConsumerStatefulWidget {
  const FavoritesPage({super.key});

  @override
  ConsumerState<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends ConsumerState<FavoritesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(favoritesProvider).status == PagedStatus.idle) {
        ref.read(favoritesProvider.notifier).refresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(favoritesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Favoris')),
      body: PagedScroll<FavoriteEntry>(
        state: state,
        onRefresh: () => ref.read(favoritesProvider.notifier).refresh(),
        onLoadMore: () => ref.read(favoritesProvider.notifier).loadMore(),
        itemBuilder: (context, entry) => _FavoriteRow(entry: entry),
        emptyIcon: Icons.bookmark_border,
        emptyMessage: "Vous n'avez encore aucun favori.",
      ),
    );
  }
}

class _FavoriteRow extends ConsumerWidget {
  const _FavoriteRow({required this.entry});

  final FavoriteEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = entry.product;
    if (card == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => context.push(productPath(card.slug)),
        child: Row(
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: QuinchImage(
                url: card.coverImage ?? card.video?.thumbnailPath,
                semanticLabel: card.title,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatPrice(card.price, card.currency),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TypeChip(card.type),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'Retirer des favoris',
              icon: const Icon(Icons.bookmark),
              onPressed: () async {
                try {
                  await ref
                      .read(productOverridesProvider.notifier)
                      .toggleSave(card);
                } on ApiError catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(content: Text(e.userMessage)));
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
