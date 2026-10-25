import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/format/fcfa.dart';
import '../../core/network/api_error.dart';
import '../../data/models/new_product.dart';
import '../../data/models/product.dart';
import '../../shared/paging/paged_scroll.dart';
import '../../shared/widgets/product_widgets.dart';
import '../product/product_providers.dart';
import '../sell/listing_fee.dart';
import 'profile_providers.dart';

String productStatusLabel(String? status) => switch (status) {
  'draft' => 'Brouillon',
  'active' => 'En ligne',
  'reserved' => 'Réservé',
  'sold' => 'Vendu',
  'paused' => 'En pause',
  'expired' => 'Expirée',
  'disabled' => 'Désactivée',
  null => '',
  final other => other,
};

/// Actions proposées sur une annonce, selon son statut. Le serveur reste juge :
/// un brouillon ne se publie que par « Publier » (frais compris), et une annonce
/// désactivée par la modération ne peut pas être remise en ligne par son auteur.
enum _ProductAction {
  edit('Modifier'),
  publish('Publier cette annonce'),
  pause('Mettre en pause'),
  reserve('Marquer comme réservé'),
  markSold('Marquer comme vendu'),
  putOnline('Remettre en ligne');

  const _ProductAction(this.label);

  final String label;
}

List<_ProductAction> _actionsFor(String? status) => switch (status) {
  'draft' => [_ProductAction.edit, _ProductAction.publish],
  'active' => [
    _ProductAction.edit,
    _ProductAction.pause,
    _ProductAction.reserve,
    _ProductAction.markSold,
  ],
  'reserved' => [
    _ProductAction.edit,
    _ProductAction.putOnline,
    _ProductAction.markSold,
  ],
  'paused' ||
  'sold' ||
  'expired' => [_ProductAction.edit, _ProductAction.putOnline],
  'disabled' => const <_ProductAction>[],
  _ => [_ProductAction.edit],
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

  bool _busy = false;

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _onAction(ProductCard card, _ProductAction action) async {
    if (_busy) {
      return;
    }
    switch (action) {
      case _ProductAction.edit:
        await context.push(editProductPath, extra: card);
        return;
      case _ProductAction.publish:
        await _run(() => _publish(card));
      case _ProductAction.pause:
        await _run(() => _changeStatus(card, 'paused'));
      case _ProductAction.reserve:
        await _run(() => _changeStatus(card, 'reserved'));
      case _ProductAction.markSold:
        await _run(() => _changeStatus(card, 'sold'));
      case _ProductAction.putOnline:
        await _run(() => _changeStatus(card, 'active'));
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on ApiError catch (e) {
      if (mounted) {
        _toast(e.userMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _publish(ProductCard card) async {
    final result = await ref
        .read(productRepositoryProvider)
        .publishProduct(card.id);
    if (!mounted) {
      return;
    }
    if (result.paymentUrl != null) {
      // Frais dus : l'annonce reste en brouillon tant que le serveur n'a pas
      // confirmé le paiement.
      final message = await runListingFeeFlow(context, ref, result);
      if (mounted && message != null) {
        _toast(message);
      }
    } else {
      _toast(result.message ?? 'Annonce publiée.');
    }
    if (mounted) {
      await ref.read(myProductsProvider.notifier).refresh();
    }
  }

  Future<void> _changeStatus(ProductCard card, String status) async {
    final result = await ref
        .read(productRepositoryProvider)
        .updateProduct(card.id, ProductUpdate(status: status));
    if (!mounted) {
      return;
    }
    _toast(result.message ?? 'Annonce mise à jour.');
    await ref.read(myProductsProvider.notifier).refresh();
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(sellPath),
        icon: const Icon(Icons.add),
        label: const Text('Publier'),
      ),
      body: PagedScroll<ProductCard>(
        state: state,
        onRefresh: notifier.refresh,
        onLoadMore: notifier.loadMore,
        itemBuilder: (context, card) => _Row(
          card: card,
          busy: _busy,
          onDelete: () => _delete(card),
          onAction: (action) => _onAction(card, action),
        ),
        emptyIcon: Icons.storefront_outlined,
        emptyMessage: "Vous n'avez pas encore publié d'annonce.",
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.card,
    required this.busy,
    required this.onDelete,
    required this.onAction,
  });

  final ProductCard card;
  final bool busy;
  final VoidCallback onDelete;
  final ValueChanged<_ProductAction> onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = productStatusLabel(card.status);
    final actions = _actionsFor(card.status);
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
            if (actions.isNotEmpty)
              PopupMenuButton<_ProductAction>(
                tooltip: "Actions sur l'annonce",
                enabled: !busy,
                onSelected: onAction,
                itemBuilder: (context) => [
                  for (final action in actions)
                    PopupMenuItem<_ProductAction>(
                      value: action,
                      child: Text(action.label),
                    ),
                ],
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
