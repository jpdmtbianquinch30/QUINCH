import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/format/fcfa.dart';
import '../../core/network/api_error.dart';
import '../../data/models/product.dart';
import '../../shared/paging/paged_scroll.dart';
import '../../shared/widgets/product_widgets.dart';
import 'profile_providers.dart';

String productStatusLabel(String? status) => switch (status) {
  'draft' => 'Brouillon',
  'active' => 'En ligne',
  'reserved' => 'Réservé',
  'sold' => 'Vendu',
  null => '',
  final other => other,
};

class MyProductsPage extends ConsumerStatefulWidget {
  const MyProductsPage({super.key});

  @override
  ConsumerState<MyProductsPage> createState() => _MyProductsPageState();
}

class _MyProductsPageState extends ConsumerState<MyProductsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(myProductsProvider.notifier).refresh();
      }
    });
  }

  Future<void> _delete(ProductCard card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer cette annonce ?'),
        content: Text('« ${card.title} » sera supprimée définitivement.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await ref.read(myProductsProvider.notifier).delete(card.id);
    } on ApiError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.userMessage)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myProductsProvider);
    final notifier = ref.read(myProductsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Mes annonces')),
      body: PagedScroll<ProductCard>(
        state: state,
        onRefresh: notifier.refresh,
        onLoadMore: notifier.loadMore,
        itemBuilder: (context, card) =>
            _Row(card: card, onDelete: () => _delete(card)),
        emptyIcon: Icons.storefront_outlined,
        emptyMessage: "Vous n'avez pas encore publié d'annonce.",
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.card, required this.onDelete});

  final ProductCard card;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = productStatusLabel(card.status);
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
                    Wrap(
                      spacing: 8,
                      children: [
                        TypeChip(card.type),
                        if (status.isNotEmpty)
                          Text(status, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: "Supprimer l'annonce",
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
