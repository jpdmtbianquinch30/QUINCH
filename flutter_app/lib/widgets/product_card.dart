import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../models/product.dart';
import '../config/theme.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onLike;
  final VoidCallback? onSave;

  const ProductCard({
    super.key,
    required this.product,
    this.onLike,
    this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/product/${product.slug}'),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (product.mediaUrl.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: product.mediaUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF12141D), Color(0xFF1A1D2E)],
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: AppColors.bgCard,
                          child: Icon(
                            product.isService ? Icons.handyman : Icons.image,
                            size: 32, color: AppColors.textMuted,
                          ),
                        ),
                      )
                    else
                      Container(
                        color: AppColors.bgCard,
                        child: Icon(
                          product.isService ? Icons.handyman : Icons.image,
                          size: 32, color: AppColors.textMuted,
                        ),
                      ),

                    // Type badge
                    Positioned(
                      top: 8, left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: product.isService
                              ? const Color(0xCC10B981)
                              : const Color(0xCC6366F1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(product.isService ? Icons.handyman : Icons.shopping_bag,
                            color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                          Text(product.isService ? 'Service' : 'Produit',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),

                    // Like button
                    if (onLike != null)
                      Positioned(
                        top: 8, right: 8,
                        child: GestureDetector(
                          onTap: onLike,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              product.isLiked ? Icons.favorite : Icons.favorite_border,
                              color: product.isLiked ? AppColors.liked : Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),

                    // Video indicator
                    if (product.hasVideo)
                      Positioned(
                        bottom: 8, right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.play_arrow, color: Colors.white, size: 14),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(product.displayPrice,
                    style: TextStyle(
                      color: product.isService ? AppColors.secondary : AppColors.accentLight,
                      fontWeight: FontWeight.w700, fontSize: 15)),
                  if (product.seller != null) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(Icons.person, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(product.seller!.displayName,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
