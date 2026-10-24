import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/format/fcfa.dart';
import '../../data/models/product.dart';
import '../../shared/widgets/product_widgets.dart';
import '../product/product_actions.dart';

/// Carte du feed. La lecture de la vidéo arrive à l'étape 6 : en attendant, la
/// carte montre l'image de couverture et indique la présence d'une vidéo.
class FeedCard extends StatelessWidget {
  const FeedCard({super.key, required this.card});

  final ProductCard card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final video = card.video;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => context.push(productPath(card.slug)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 4 / 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  QuinchImage(
                    url: card.coverImage ?? video?.thumbnailPath,
                    semanticLabel: card.title,
                  ),
                  Positioned(top: 8, right: 8, child: TypeChip(card.type)),
                  if (video != null)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 16,
                            ),
                            if (video.durationSeconds != null)
                              Text(
                                formatDuration(video.durationSeconds!),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatPrice(card.price, card.currency),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (card.seller != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      card.seller!.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ProductActionButtons(card: card),
            ),
          ],
        ),
      ),
    );
  }
}
