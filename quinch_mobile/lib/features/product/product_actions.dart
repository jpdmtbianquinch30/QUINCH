import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_error.dart';
import '../../data/models/product.dart';
import 'product_providers.dart';

/// Boutons « j'aime » et « enregistrer » d'une annonce, alimentés par l'état
/// partagé (`productOverridesProvider`). Le serveur reste l'autorité : après
/// chaque action, l'affichage reprend les valeurs qu'il renvoie.
class ProductActionButtons extends ConsumerWidget {
  const ProductActionButtons({
    super.key,
    required this.card,
    this.compact = false,
  });

  final ProductCard card;
  final bool compact;

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } on ApiError catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.userMessage)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final override = ref.watch(
      productOverridesProvider.select((m) => m[card.id]),
    );
    final liked = override?.liked(card) ?? card.isLiked;
    final likes = override?.likes(card) ?? card.likeCount;
    final saved = override?.saved(card) ?? card.isSaved;
    final notifier = ref.read(productOverridesProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    final likeButton = TextButton.icon(
      onPressed: () => _run(context, () => notifier.toggleLike(card)),
      icon: Icon(
        liked ? Icons.favorite : Icons.favorite_border,
        color: liked ? scheme.error : null,
        semanticLabel: liked ? "Retirer le j'aime" : "J'aime",
      ),
      label: Text('$likes'),
    );
    final saveButton = IconButton(
      tooltip: saved ? 'Retirer des favoris' : 'Ajouter aux favoris',
      onPressed: () => _run(context, () => notifier.toggleSave(card)),
      icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
    );
    return Row(
      mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
      children: [likeButton, const Spacer(), saveButton],
    );
  }
}
