import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/format/fcfa.dart';
import '../../data/models/product.dart';
import '../../shared/widgets/product_widgets.dart';

/// Vignette d'annonce de l'Explorer. Pas d'indicateur « aimé / enregistré » :
/// cette liste ne le renseigne pas de façon fiable (voir rapport étape 3, §1.6).
class ProductTile extends StatelessWidget {
  const ProductTile({super.key, required this.card});

  final ProductCard card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => context.push(productPath(card.slug)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  QuinchImage(url: card.coverImage, semanticLabel: card.title),
                  Positioned(top: 8, left: 8, child: TypeChip(card.type)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatPrice(card.price, card.currency),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
