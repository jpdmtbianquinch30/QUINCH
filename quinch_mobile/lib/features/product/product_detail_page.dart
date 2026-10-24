import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format/fcfa.dart';
import '../../app/router.dart';
import '../../core/network/api_error.dart';
import '../../core/session/session_controller.dart';
import '../../core/session/session_state.dart';
import '../../data/models/product.dart';
import '../../data/repositories/safety_repository.dart';
import '../../shared/widgets/product_widgets.dart';
import '../../shared/widgets/report_sheet.dart';
import '../profile/profile_providers.dart';
import 'product_actions.dart';
import 'product_providers.dart';

class ProductDetailPage extends ConsumerStatefulWidget {
  const ProductDetailPage({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends ConsumerState<ProductDetailPage> {
  bool _viewRecorded = false;

  void _recordViewOnce(String productId) {
    if (_viewRecorded) {
      return;
    }
    _viewRecorded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(productRepositoryProvider).recordView(productId);
      } on ApiError {
        // Compteur de vues : meilleur effort, sans importance pour l'utilisateur.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(productDetailProvider(widget.slug));
    final loaded = detail.valueOrNull;
    final session = ref.watch(sessionControllerProvider);
    final myId = session is SessionAuthenticated ? session.user.id : null;
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (loaded != null && loaded.seller.id != myId)
            PopupMenuButton<String>(
              tooltip: "Plus d'actions",
              onSelected: (_) => showReportSheet(
                context,
                title: "Signaler cette annonce",
                reasons: ProductReportReason.values
                    .map((r) => r.label)
                    .toList(),
                onSubmit: (index, description) => ref
                    .read(safetyRepositoryProvider)
                    .reportProduct(
                      loaded.product.id,
                      ProductReportReason.values[index],
                      description: description,
                    ),
              ),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'report',
                  child: Text("Signaler l'annonce"),
                ),
              ],
            ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(
          child: CircularProgressIndicator(semanticsLabel: 'Chargement'),
        ),
        error: (error, stackTrace) => ErrorRetry.fromError(
          error,
          onRetry: () => ref.invalidate(productDetailProvider(widget.slug)),
        ),
        data: (data) {
          _recordViewOnce(data.product.id);
          return _DetailBody(detail: data);
        },
      ),
    );
  }
}

String conditionLabel(String? condition) => switch (condition) {
  'new' => 'Neuf',
  'like_new' => 'Comme neuf',
  'good' => 'Bon état',
  'fair' => 'État correct',
  null => '',
  final other => other,
};

String statusLabel(String? status) => switch (status) {
  'reserved' => 'Réservé',
  'sold' => 'Vendu',
  _ => '',
};

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail});

  final ProductDetail detail;

  @override
  Widget build(BuildContext context) {
    final product = detail.product;
    final seller = detail.seller;
    final theme = Theme.of(context);
    final images = <String>[
      if (product.posterUrl != null) product.posterUrl!,
      ...product.imageUrls.where((u) => u != product.posterUrl),
    ];
    final condition = conditionLabel(product.condition);
    final status = statusLabel(product.status);

    return ListView(
      children: [
        _Gallery(
          images: images,
          hasVideo: product.video != null,
          title: product.title,
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TypeChip(product.type),
                  if (status.isNotEmpty) Chip(label: Text(status)),
                  if (condition.isNotEmpty) Chip(label: Text(condition)),
                  if (product.isNegotiable)
                    const Chip(label: Text('Prix négociable')),
                ],
              ),
              const SizedBox(height: 12),
              Text(product.title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                formatPrice(product.price, product.currency),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ProductActionButtons(card: product),
              const Divider(),
              if (product.categoryName != null)
                _InfoRow(
                  icon: Icons.category_outlined,
                  text: product.categoryName!,
                ),
              if (product.deliveryOption == 'fixed' &&
                  product.deliveryFee != null)
                _InfoRow(
                  icon: Icons.local_shipping_outlined,
                  text: 'Livraison : ${formatFcfa(product.deliveryFee!)}',
                ),
              if (product.deliveryOption == 'contact')
                const _InfoRow(
                  icon: Icons.local_shipping_outlined,
                  text: 'Livraison à convenir avec le vendeur',
                ),
              if (product.paymentMethods.isNotEmpty)
                _InfoRow(
                  icon: Icons.payments_outlined,
                  text:
                      'Paiement : ${product.paymentMethods.map((m) => m.replaceAll('_', ' ')).join(', ')}',
                ),
              if (product.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Description', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                SelectableText(product.description),
              ],
              const SizedBox(height: 16),
              _SellerCard(seller: seller),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _SellerCard extends StatelessWidget {
  const _SellerCard({required this.seller});

  final SellerBrief seller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = seller.fullName.isEmpty
        ? '?'
        : seller.fullName.characters.first.toUpperCase();
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: seller.username == null
            ? null
            : () => context.push(sellerPath(seller.username!)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                child: ClipOval(
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: seller.avatarUrl == null
                        ? Center(child: Text(initial))
                        : QuinchImage(
                            url: seller.avatarUrl,
                            semanticLabel: seller.fullName,
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(seller.fullName, style: theme.textTheme.titleMedium),
                    if (seller.username != null)
                      Text(
                        '@${seller.username}',
                        style: theme.textTheme.bodySmall,
                      ),
                    if (seller.city != null)
                      Text(seller.city!, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              if (seller.isPremium) const Chip(label: Text('Premium')),
            ],
          ),
        ),
      ),
    );
  }
}

class _Gallery extends StatefulWidget {
  const _Gallery({
    required this.images,
    required this.hasVideo,
    required this.title,
  });

  final List<String> images;
  final bool hasVideo;
  final String title;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (images.isEmpty)
            const QuinchImage(url: null)
          else
            PageView.builder(
              itemCount: images.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) =>
                  QuinchImage(url: images[i], semanticLabel: widget.title),
            ),
          if (images.length > 1)
            Positioned(
              right: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_index + 1}/${images.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          if (widget.hasVideo)
            Positioned(
              left: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Vidéo',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
