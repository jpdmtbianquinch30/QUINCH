import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart' as share_plus;
import '../../models/product.dart';
import '../../services/product_service.dart';
import '../../services/review_service.dart';
import '../../services/negotiation_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/chat_provider.dart';
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../widgets/cached_avatar.dart';

class ProductDetailScreen extends StatefulWidget {
  final String slug;
  const ProductDetailScreen({super.key, required this.slug});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Product? _product;
  bool _loading = true;
  VideoPlayerController? _videoController;

  // Reviews
  List<dynamic> _reviews = [];
  Map<String, dynamic>? _reviewStats;
  bool _loadingReviews = false;
  int _newRating = 0;
  final _reviewCtrl = TextEditingController();
  bool _submittingReview = false;
  bool _reviewSubmitted = false;

  // Negotiation
  final _negotiationCtrl = TextEditingController();

  // Payment
  String? _selectedPayment;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _reviewCtrl.dispose();
    _negotiationCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProduct() async {
    try {
      final product = await context.read<ProductService>().getProduct(widget.slug);
      if (!mounted) return;
      setState(() { _product = product; _loading = false; });
      if (product.hasVideo) {
        final videoUrl = product.video!.effectiveUrl;
        _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
          ..initialize().then((_) {
            if (mounted) {
              _videoController!.setLooping(true);
              _videoController!.play();
              setState(() {});
            }
          }).catchError((_) {});
      }
      // Track view only if authenticated
      final auth = context.read<AuthProvider>();
      if (auth.isAuthenticated) {
        context.read<ProductService>().trackView(product.id).catchError((_) {});
      }
      _loadReviews(product);
    } catch (e) {
      debugPrint('[ProductDetail] Error loading product: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── CONTACT SELLER ───
  Future<void> _contactSeller() async {
    final p = _product;
    if (p == null || p.seller == null) return;
    if (!context.read<AuthProvider>().isAuthenticated) {
      context.push('/auth/login');
      return;
    }

    _showMsg('Ouverture de la conversation...');

    try {
      final chatProvider = context.read<ChatProvider>();
      final convId = await chatProvider.startConversation(
        sellerId: p.seller!.id,
        productId: p.id,
        message: 'Bonjour, je suis intéressé(e) par "${p.title}" (${p.displayPrice}).',
      );
      if (!mounted) return;
      if (convId != null) {
        context.push('/messages/$convId');
      } else {
        _showMsg('Erreur: impossible de créer la conversation.', error: true);
      }
    } catch (e) {
      debugPrint('[ProductDetail] Error starting conversation: $e');
      _showMsg('Erreur lors du contact.', error: true);
    }
  }

  // ─── TOGGLE LIKE (optimistic) ───
  void _toggleLike() {
    final p = _product;
    if (p == null) return;
    if (!context.read<AuthProvider>().isAuthenticated) {
      context.push('/auth/login');
      return;
    }
    // Optimistic update
    setState(() { p.isLiked = !p.isLiked; });
    context.read<ProductService>().toggleLike(p.id).then((result) {
      if (mounted) setState(() { p.isLiked = result['is_liked'] ?? p.isLiked; });
    }).catchError((_) {
      if (mounted) setState(() { p.isLiked = !p.isLiked; });
    });
  }

  // ─── TOGGLE SAVE (optimistic) ───
  void _toggleSave() {
    final p = _product;
    if (p == null) return;
    if (!context.read<AuthProvider>().isAuthenticated) {
      context.push('/auth/login');
      return;
    }
    setState(() { p.isSaved = !p.isSaved; });
    context.read<ProductService>().toggleSave(p.id).then((result) {
      if (mounted) setState(() { p.isSaved = result['saved'] ?? p.isSaved; });
    }).catchError((_) {
      if (mounted) setState(() { p.isSaved = !p.isSaved; });
    });
  }

  Future<void> _loadReviews(Product p) async {
    final sellerId = p.seller?.id;
    if (sellerId == null) return;
    setState(() => _loadingReviews = true);
    try {
      final res = await context.read<ReviewService>().getSellerReviews(sellerId.toString());
      if (mounted) {
        setState(() {
          _reviews = res['reviews']?['data'] ?? res['reviews'] ?? [];
          _reviewStats = res['stats'];
          _loadingReviews = false;
          // Check if already reviewed
          final myId = context.read<AuthProvider>().user?.id;
          if (myId != null) {
            _reviewSubmitted = _reviews.any((r) => r['reviewer_id']?.toString() == myId.toString());
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingReviews = false);
    }
  }

  Future<void> _submitReview() async {
    final p = _product;
    if (p == null || _newRating == 0) return;
    final sellerId = p.seller?.id;
    if (sellerId == null) return;
    setState(() => _submittingReview = true);
    try {
      await context.read<ReviewService>().createReview(
        sellerId: sellerId.toString(),
        rating: _newRating,
        comment: _reviewCtrl.text.trim().isNotEmpty ? _reviewCtrl.text.trim() : null,
      );
      _showMsg('Avis publié ! Merci pour votre retour.');
      _reviewCtrl.clear();
      setState(() { _newRating = 0; _submittingReview = false; _reviewSubmitted = true; });
      _loadReviews(p);
    } catch (e) {
      setState(() => _submittingReview = false);
      _showMsg('Erreur lors de la publication.', error: true);
    }
  }

  void _showFullImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: InteractiveViewer(
              child: CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.contain),
            ),
          ),
          Positioned(top: 8, right: 8,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(18)),
                child: const Icon(Icons.close, color: Colors.white, size: 20)),
            )),
        ]),
      ),
    );
  }

  void _showNegotiationSheet() {
    final p = _product;
    if (p == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Proposer un prix', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Prix actuel : ${p.displayPrice}', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 16),
          TextField(
            controller: _negotiationCtrl,
            keyboardType: TextInputType.number,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Votre prix proposé (F CFA)',
              hintStyle: TextStyle(color: AppColors.textMuted),
              filled: true, fillColor: AppColors.bgInput,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              suffixText: 'F CFA',
              suffixStyle: TextStyle(color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity, height: 48,
            child: ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(_negotiationCtrl.text);
                if (amount == null || amount <= 0) { _showMsg('Montant invalide', error: true); return; }
                try {
                  await context.read<NegotiationService>().propose(productId: p.id.toString(), proposedPrice: amount);
                  _showMsg('Proposition envoyée au vendeur !');
                  Navigator.pop(context);
                  _negotiationCtrl.clear();
                } catch (_) {
                  _showMsg('Erreur lors de l\'envoi.', error: true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Envoyer la proposition', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }

  void _showPaymentSheet() {
    final p = _product;
    if (p == null) return;
    final methods = (p.paymentMethods != null && p.paymentMethods!.isNotEmpty) ? p.paymentMethods! : ['orange_money', 'wave', 'free_money', 'cash_delivery'];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Choisir le paiement', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Total : ${p.displayPrice}', style: const TextStyle(color: AppColors.accent, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            ...methods.map((m) {
              final labels = {'orange_money': '🟠 Orange Money', 'wave': '🔵 Wave', 'free_money': '🟢 Free Money', 'cash_delivery': '📦 Paiement à la livraison'};
              return RadioListTile<String>(
                value: m, groupValue: _selectedPayment,
                onChanged: (v) => setSt(() => _selectedPayment = v),
                title: Text(labels[m] ?? m, style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                activeColor: AppColors.accent,
                dense: true,
                contentPadding: EdgeInsets.zero,
              );
            }),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity, height: 48,
              child: ElevatedButton(
                onPressed: _selectedPayment == null ? null : () async {
                  try {
                    await context.read<ProductService>().initiateTransaction(
                      productId: p.id, amount: p.price, paymentMethod: _selectedPayment!, deliveryType: 'delivery',
                    );
                    Navigator.pop(ctx);
                    _showMsg('Commande confirmée ! Le vendeur a été notifié.');
                  } catch (_) {
                    _showMsg('Erreur lors du paiement.', error: true);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Confirmer le paiement', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _showMsg(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 13)),
      backgroundColor: error ? AppColors.danger : const Color(0xFF1E293B),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    if (_product == null) {
      return Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(backgroundColor: AppColors.bgSecondary),
        body: Center(child: Text('Produit introuvable', style: TextStyle(color: AppColors.textPrimary))),
      );
    }

    final p = _product!;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: CustomScrollView(
        slivers: [
          // ═══ MEDIA HEADER ═══
          SliverAppBar(
            expandedHeight: 420,
            pinned: true,
            backgroundColor: AppColors.bgSecondary,
            leading: _BackBtn(),
            actions: [
              _ActionBtn(
                icon: p.isLiked ? Icons.favorite : Icons.favorite_border,
                color: p.isLiked ? AppColors.liked : Colors.white,
                onTap: _toggleLike,
              ),
              _ActionBtn(
                icon: p.isSaved ? Icons.bookmark : Icons.bookmark_border,
                color: p.isSaved ? AppColors.saved : Colors.white,
                onTap: _toggleSave,
              ),
              _ActionBtn(icon: Icons.share, onTap: () => share_plus.Share.share('Découvrez ${p.title} sur QUINCH !')),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(fit: StackFit.expand, children: [
                // Video or Image
                if (_videoController != null && _videoController!.value.isInitialized)
                  GestureDetector(
                    onTap: () {
                      if (_videoController!.value.isPlaying) _videoController!.pause();
                      else _videoController!.play();
                    },
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _videoController!.value.size.width,
                        height: _videoController!.value.size.height,
                        child: VideoPlayer(_videoController!),
                      ),
                    ),
                  )
                else if (p.mediaUrl.isNotEmpty)
                  CachedNetworkImage(imageUrl: p.mediaUrl, fit: BoxFit.cover)
                else
                  Container(color: AppColors.bgCard, child: Icon(p.isService ? Icons.handyman : Icons.shopping_bag, size: 64, color: AppColors.textMuted)),

                // Gradient
                const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Color(0x40000000), Colors.transparent, Color(0xCC000000)], stops: [0, 0.3, 1])))),

                // Type badge
                Positioned(top: 100, left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: p.isService ? const Color(0xCC10B981) : const Color(0xCC6366F1),
                      borderRadius: BorderRadius.circular(50)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(p.isService ? Icons.handyman : Icons.shopping_bag, color: Colors.white, size: 13),
                      const SizedBox(width: 4),
                      Text(p.isService ? 'Service' : 'Produit', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    ]),
                  )),

                // Play button overlay
                if (_videoController != null && !_videoController!.value.isPlaying)
                  Center(child: Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
                  )),
              ]),
            ),
          ),

          // ═══ PRODUCT INFO ═══
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Title + Price
                Text(p.title, style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: p.isService
                          ? const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF34D399)])
                          : const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF818CF8)]),
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [BoxShadow(color: (p.isService ? AppColors.secondary : AppColors.accent).withValues(alpha: 0.3), blurRadius: 12)],
                    ),
                    child: Text(p.displayPrice, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 10),
                  if (p.isNegotiable)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: AppColors.warningSubtle, borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3))),
                      child: const Text('Négociable', style: TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                ]),

                // ═══ STOCK INFO (products only) ═══
                if (p.isProduct) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: p.isInStock
                          ? AppColors.success.withValues(alpha: 0.1)
                          : AppColors.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: p.isInStock
                          ? AppColors.success.withValues(alpha: 0.3)
                          : AppColors.danger.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      Icon(
                        p.isInStock ? Icons.check_circle : Icons.cancel,
                        color: p.isInStock ? AppColors.success : AppColors.danger,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        p.isInStock
                            ? 'En stock (${p.stockQuantity})'
                            : 'Rupture de stock',
                        style: TextStyle(
                          color: p.isInStock ? AppColors.success : AppColors.danger,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ]),
                  ),
                ],

                const SizedBox(height: 16),

                // ═══ IMAGE GALLERY ═══
                if (p.images != null && p.images!.isNotEmpty) ...[
                  Text('Photos', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: p.images!.length,
                      itemBuilder: (_, i) {
                        final imgUrl = ApiConfig.resolveUrl(p.images![i]);
                        return Padding(
                          padding: EdgeInsets.only(right: i < p.images!.length - 1 ? 8 : 0),
                          child: GestureDetector(
                            onTap: () => _showFullImage(context, imgUrl),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: imgUrl,
                                width: 100, height: 100, fit: BoxFit.cover,
                                placeholder: (_, __) => Container(width: 100, height: 100, color: AppColors.bgCard,
                                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))),
                                errorWidget: (_, __, ___) => Container(width: 100, height: 100, color: AppColors.bgCard,
                                  child: Icon(Icons.broken_image, color: AppColors.textMuted, size: 24)),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Stats row
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    _StatItem(icon: Icons.visibility, label: '${p.viewCount} vues'),
                    _StatItem(icon: Icons.favorite, label: '${p.likeCount} likes'),
                    _StatItem(icon: Icons.share, label: '${p.shareCount} partages'),
                  ]),
                ),

                const SizedBox(height: 20),

                // Description
                if (p.description != null && p.description!.isNotEmpty) ...[
                  Text('Description', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(p.description!, style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5)),
                  const SizedBox(height: 20),
                ],

                // Details
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border)),
                  child: Column(children: [
                    if (p.condition.isNotEmpty) _InfoRow(Icons.fiber_new, 'État', _conditionLabel(p.condition)),
                    if (p.category != null) _InfoRow(Icons.category, 'Catégorie', p.category!.name),
                    if (p.isProduct && p.stockQuantity != null)
                      _InfoRow(Icons.inventory_2, 'Stock', '${p.stockQuantity} disponible${(p.stockQuantity ?? 0) > 1 ? 's' : ''}'),
                    _InfoRow(Icons.local_shipping, 'Livraison',
                      p.deliveryOption == 'fixed' && p.deliveryFee != null && p.deliveryFee! > 0
                          ? '${p.deliveryFee!.toStringAsFixed(0)} F CFA'
                          : p.deliveryAvailable ? 'Disponible' : 'À convenir'),
                    _InfoRow(Icons.location_on, 'Localisation', p.location ?? 'Sénégal'),
                  ]),
                ),

                // ═══ DELIVERY BANNER ═══
                if (p.isProduct) ...[
                  const SizedBox(height: 12),
                  if (p.deliveryOption == 'fixed' && p.deliveryFee != null && p.deliveryFee! > 0)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A2A4A),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                      ),
                      child: Row(children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: AppColors.accentSubtle, borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.local_shipping, color: AppColors.accent, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Livraison : ${p.deliveryFee!.toStringAsFixed(0)} F CFA',
                            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                          Text('Frais de livraison en plus du prix du produit',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                        ])),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(8)),
                          child: Text('+${p.deliveryFee!.toStringAsFixed(0)} F',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                      ]),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: AppColors.warningSubtle, borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.chat, color: AppColors.warning, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Livraison à convenir',
                            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                          Text('Contactez le vendeur pour les frais et modalités',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                        ])),
                      ]),
                    ),
                ],

                const SizedBox(height: 20),

                // Seller card
                if (p.seller != null)
                  GestureDetector(
                    onTap: () => context.push('/seller/${p.seller!.username}'),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border)),
                      child: Row(children: [
                        CachedAvatar(url: p.seller!.avatarUrl, size: 48, name: p.seller!.displayName),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Text(p.seller!.displayName, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
                            if (p.seller!.trustScore >= 0.7) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified, color: AppColors.accent, size: 15),
                            ],
                          ]),
                          Text('@${p.seller!.username}', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        ])),
                        Icon(Icons.chevron_right, color: AppColors.textMuted),
                      ]),
                    ),
                  ),

                const SizedBox(height: 24),

                // ═══ REVIEWS SECTION ═══
                _buildReviewsSection(p),

                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),

      // ═══ BOTTOM BAR ═══
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bgSecondary,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Row(children: [
            // Contact seller
            SizedBox(width: 48, height: 48,
              child: OutlinedButton(
                onPressed: _contactSeller,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  side: BorderSide(color: p.isService ? const Color(0xFF10B981) : AppColors.accent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Icon(Icons.chat_bubble_outline, size: 20, color: p.isService ? const Color(0xFF10B981) : AppColors.accent),
              ),
            ),
            const SizedBox(width: 8),
            // Negotiate (if negotiable)
            if (p.isNegotiable) ...[
              SizedBox(width: 48, height: 48,
                child: OutlinedButton(
                  onPressed: () {
                    if (!auth.isAuthenticated) { context.push('/auth/login'); return; }
                    _showNegotiationSheet();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    side: const BorderSide(color: AppColors.warning),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Icon(Icons.handshake, size: 20, color: AppColors.warning),
                ),
              ),
              const SizedBox(width: 8),
            ],
            // Add to cart (products only)
            if (!p.isService)
              Expanded(
                child: SizedBox(height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      if (!auth.isAuthenticated) { context.push('/auth/login'); return; }
                      context.read<CartProvider>().addToCart(p.id, quantity: 1);
                      _showMsg('Ajouté au panier !');
                    },
                    icon: const Icon(Icons.shopping_cart, size: 16),
                    label: const Text('Panier', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.accent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 8),
            // Buy now / Request quote
            Expanded(
              child: SizedBox(height: 48,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: p.isService
                        ? const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF34D399)])
                        : AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (!auth.isAuthenticated) { context.push('/auth/login'); return; }
                      _showPaymentSheet();
                    },
                    icon: Icon(p.isService ? Icons.request_quote : Icons.flash_on, size: 18, color: Colors.white),
                    label: Text(p.isService ? 'Devis' : 'Acheter',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildReviewsSection(Product p) {
    final total = _reviewStats?['total'] ?? 0;
    final avg = (_reviewStats?['average'] ?? 0).toDouble();
    final dist = _reviewStats?['distribution'] ?? {};
    final auth = context.watch<AuthProvider>();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Avis vendeur', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),

      if (_loadingReviews)
        const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)))
      else ...[
        // Stats summary
        if (total > 0) Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
          child: Row(children: [
            Column(children: [
              Text(avg.toStringAsFixed(1), style: TextStyle(color: AppColors.textPrimary, fontSize: 32, fontWeight: FontWeight.w800)),
              Row(children: List.generate(5, (i) => Icon(i < avg.round() ? Icons.star : Icons.star_border, color: const Color(0xFFFBBF24), size: 16))),
              Text('$total avis', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ]),
            const SizedBox(width: 20),
            Expanded(child: Column(children: [
              for (int s = 5; s >= 1; s--)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Row(children: [
                    Text('$s', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    const SizedBox(width: 4),
                    const Icon(Icons.star, color: Color(0xFFFBBF24), size: 10),
                    const SizedBox(width: 6),
                    Expanded(child: LinearProgressIndicator(
                      value: total > 0 ? ((dist[s.toString()] ?? dist[s] ?? 0) / total) : 0,
                      backgroundColor: AppColors.bgInput,
                      color: const Color(0xFFFBBF24),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    )),
                    const SizedBox(width: 6),
                    SizedBox(width: 20, child: Text('${dist[s.toString()] ?? dist[s] ?? 0}', style: TextStyle(color: AppColors.textMuted, fontSize: 10), textAlign: TextAlign.right)),
                  ]),
                ),
            ])),
          ]),
        ),

        const SizedBox(height: 16),

        // Write review
        if (auth.isAuthenticated && !_reviewSubmitted) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Donnez votre avis', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              Row(children: List.generate(5, (i) => GestureDetector(
                onTap: () => setState(() => _newRating = i + 1),
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(i < _newRating ? Icons.star : Icons.star_border, color: const Color(0xFFFBBF24), size: 28),
                ),
              ))),
              const SizedBox(height: 8),
              TextField(
                controller: _reviewCtrl,
                maxLines: 2,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Commentaire (optionnel)...',
                  hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  filled: true, fillColor: AppColors.bgInput,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submittingReview || _newRating == 0 ? null : _submitReview,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(_submittingReview ? 'Publication...' : 'Publier l\'avis',
                      style: const TextStyle(color: Colors.white)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
        ],

        // Review list
        ..._reviews.take(5).map((r) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(radius: 16, backgroundColor: AppColors.accentSubtle,
                child: Text((r['reviewer']?['full_name'] ?? '?')[0].toUpperCase(),
                    style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 12))),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r['reviewer']?['full_name'] ?? 'Utilisateur',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 12)),
                Row(children: List.generate(5, (i) => Icon(i < (r['rating'] ?? 0) ? Icons.star : Icons.star_border, color: const Color(0xFFFBBF24), size: 12))),
              ])),
              Text(_timeAgo(r['created_at']), style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
            ]),
            if (r['comment'] != null && r['comment'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(r['comment'], style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
            ],
          ]),
        )),

        if (_reviews.isEmpty && total == 0)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
            child: Center(child: Column(children: [
              Icon(Icons.rate_review, color: AppColors.textMuted, size: 32),
              SizedBox(height: 8),
              Text('Aucun avis pour le moment', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            ])),
          ),
      ],
    ]);
  }

  String _conditionLabel(String condition) {
    const labels = {
      'new': 'Neuf',
      'like_new': 'Comme neuf',
      'good': 'Bon état',
      'fair': 'Usé',
    };
    return labels[condition] ?? condition;
  }

  String _timeAgo(dynamic dateStr) {
    if (dateStr == null) return '';
    final d = DateTime.tryParse(dateStr.toString());
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inDays == 0) return "Aujourd'hui";
    if (diff.inDays == 1) return 'Hier';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays}j';
    if (diff.inDays < 30) return 'Il y a ${(diff.inDays / 7).floor()} sem.';
    return 'Il y a ${(diff.inDays / 30).floor()} mois';
  }
}

class _BackBtn extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10)),
          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, this.color = Colors.white, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10)),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: AppColors.textMuted, size: 16),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
    ]);
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, color: AppColors.textMuted, size: 18),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const Spacer(),
        Text(value, style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}
