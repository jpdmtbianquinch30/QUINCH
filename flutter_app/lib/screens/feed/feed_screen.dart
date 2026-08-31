import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/product.dart';
import '../../models/category.dart';
import '../../services/product_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../config/theme.dart';
import '../../widgets/quinch_logo.dart';
import 'video_feed_screen.dart';
import '../search/search_screen.dart';

/// ═══════════════════════════════════════════════════════════════
/// REFONTE DU FEED
/// ───────────────────────────────────────────────────────────────
/// Direction : sombre, épuré, "fintech premium". Ne copie pas TikTok
/// sauf pour la lecture vidéo elle-même (déplacée dans un écran dédié,
/// ouvert uniquement sur demande explicite via la bannière "Vidéos").
///
/// Changements par rapport à l'ancienne version :
///  - Suppression de la ligne "Vendeurs actifs" (stories) : retirait
///    de la place utile et n'apportait rien de fonctionnel.
///  - Suppression du carrousel vidéo autoplay en petites cartes :
///    c'était la source du bug de pause et un pur clone TikTok en
///    miniature. Remplacé par une bannière discrète -> écran plein
///    écran dédié (VideoFeedScreen), défilement vertical uniquement
///    là-bas.
///  - Barre de recherche réellement fonctionnelle (ouvre SearchScreen
///    avec clavier actif), fini la redirection vers Marketplace.
///  - Cartes produits réduites au strict minimum : image, prix en
///    overlay, badge vidéo si applicable, titre. Plus de compteur de
///    likes qui traîne, plus de bouton "Contacter" sur la carte (les
///    actions détaillées vivent sur la page produit).
/// ═══════════════════════════════════════════════════════════════

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});
  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final ScrollController _scrollController = ScrollController();

  // Data
  List<Product> _products = [];
  List<Product> _videoProducts = [];
  List<Category> _categories = [];
  int _currentPage = 1;
  int _lastPage = 1;
  bool _loading = false;
  bool _loadingMore = false;
  String? _selectedCategory;
  String _selectedType = 'all'; // all, product, service

  static const _categoriesIcons = {
    'Téléphones & Tech': Icons.smartphone,
    'Mode & Accessoires': Icons.checkroom,
    'Alimentation': Icons.restaurant,
    'Électroménager': Icons.electrical_services,
    'Immobilier': Icons.home,
    'Automobile': Icons.directions_car,
    'Services': Icons.build,
    'Emploi': Icons.work,
    'Beauté': Icons.face,
    'Sport & Loisirs': Icons.sports,
  };

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final ps = context.read<ProductService>();
      final feedData = await ps.getFeed(page: 1, perPage: 20);
      final categories = await ps.getCategories();
      final products = feedData.data;

      if (mounted) {
        setState(() {
          _products = products;
          _lastPage = feedData.lastPage;
          _categories = categories;
          // Mélange pour ne pas toujours montrer les mêmes vidéos en tête —
          // note : un vrai tri par "plus achetés" demanderait un champ
          // d'achats/popularité côté backend, absent du modèle Product
          // actuel. En attendant, on varie l'ordre à chaque reload.
          _videoProducts = (products.where((p) => p.hasVideo).toList()..shuffle());
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _currentPage >= _lastPage) return;
    setState(() => _loadingMore = true);
    try {
      final feedData = await context.read<ProductService>().getProducts(
        page: _currentPage + 1,
        categoryId: _selectedCategory,
        type: _selectedType == 'all' ? null : _selectedType,
      );
      final newProducts = feedData['data'] as List<Product>;
      if (mounted) {
        setState(() {
          _currentPage++;
          _products.addAll(newProducts);
          _videoProducts = _products.where((p) => p.hasVideo).toList();
          _loadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _currentPage = 1;
      _products.clear();
      _videoProducts.clear();
    });
    await _loadData();
  }

  Future<void> _filterByCategory(String? categoryId) async {
    setState(() {
      _selectedCategory = categoryId;
      _currentPage = 1;
      _products.clear();
      _loading = true;
    });
    try {
      final feedData = await context.read<ProductService>().getProducts(
        page: 1,
        categoryId: categoryId,
        type: _selectedType == 'all' ? null : _selectedType,
      );
      if (mounted) {
        setState(() {
          _products = feedData['data'] as List<Product>;
          _lastPage = feedData['last_page'] as int? ?? 1;
          _videoProducts = _products.where((p) => p.hasVideo).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleSave(Product product) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      context.push('/login');
      return;
    }
    setState(() => product.isSaved = !product.isSaved);
    try {
      await context.read<ProductService>().toggleSave(product.id);
    } catch (_) {
      if (mounted) setState(() => product.isSaved = !product.isSaved);
    }
  }

  void _openVideoFeed({int initialIndex = 0}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoFeedScreen(
          videos: _videoProducts,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SearchScreen()),
    );
  }

  // ═══════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final notifs = context.watch<NotificationProvider>();

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(notifs),
            Expanded(
              child: _loading
                  ? _buildSkeleton()
                  : RefreshIndicator(
                onRefresh: _refresh,
                color: AppColors.accent,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildFilterBar()),

                    if (_videoProducts.isNotEmpty)
                      SliverToBoxAdapter(child: _buildVideoBanner()),

                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Annonces récentes',
                                style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2)),
                            Builder(builder: (_) {
                              final nbProducts = _products.where((p) => !p.isService).length;
                              final nbServices = _products.where((p) => p.isService).length;
                              return Text(
                                '$nbProducts produits · $nbServices services',
                                style: TextStyle(
                                    color: AppColors.textMuted, fontSize: 12),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),

                    if (_products.isEmpty)
                      SliverFillRemaining(child: _buildEmptyState())
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        sliver: SliverGrid(
                          gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.68,
                          ),
                          delegate: SliverChildBuilderDelegate(
                                (context, index) =>
                                _buildProductCard(_products[index]),
                            childCount: _products.length,
                          ),
                        ),
                      ),

                    if (_loadingMore)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: 80)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── TOP BAR ───
  Widget _buildTopBar(NotificationProvider notifs) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const QuinchLogo(size: 30, withShadow: false),
          const SizedBox(width: 10),

          // Barre de recherche — fonctionnelle, ouvre un vrai écran de
          // recherche (produits + vendeurs), pas une redirection morte.
          Expanded(
            child: GestureDetector(
              onTap: _openSearch,
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.bgInput,
                  borderRadius: BorderRadius.circular(19),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, color: AppColors.textMuted, size: 17),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Rechercher un produit, un vendeur…',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 6),

          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: () => context.push('/notifications'),
                icon: Icon(Icons.notifications_outlined,
                    color: AppColors.textSecondary, size: 23),
              ),
              if (notifs.unreadCount > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: AppColors.danger, shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── FILTRES : ligne principale (Tout / Produits / Services), catégories en dessous ───
  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ligne principale — segmented control plein largeur, plus visible
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _typeSegment(label: 'Tout', value: 'all'),
                const SizedBox(width: 8),
                _typeSegment(label: 'Produits', value: 'product'),
                const SizedBox(width: 8),
                _typeSegment(label: 'Services', value: 'service'),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Catégories — ligne secondaire, scrollable
          if (_categories.isNotEmpty)
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 18),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final selected = _selectedCategory == cat.id;
                  return _underlineFilterChip(
                    label: cat.name,
                    icon: _categoriesIcons[cat.name],
                    selected: selected,
                    onTap: () => _filterByCategory(selected ? null : cat.id),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _typeSegment({required String label, required String value}) {
    final selected = _selectedType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedType == value) return;
          setState(() {
            _selectedType = value;
            _currentPage = 1;
            _products.clear();
          });
          _filterByCategory(_selectedCategory);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : AppColors.bgCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? AppColors.accent : AppColors.border),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _underlineFilterChip({
    required String label,
    required bool selected,
    IconData? icon,
    bool bold = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? AppColors.accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 13,
                  color: selected ? AppColors.accent : AppColors.textMuted),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.textPrimary : AppColors.textMuted,
                fontSize: 13,
                fontWeight: selected || bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── BANNIÈRE VIDÉOS (ouvre l'écran plein écran dédié) ───
  String _videoBannerSubtitle() {
    final products = _videoProducts.where((p) => p.isProduct).length;
    final services = _videoProducts.where((p) => p.isService).length;
    if (products > 0 && services > 0) {
      return '$products produits · $services services en vidéo';
    }
    if (services > 0) return '$services services en vidéo';
    return '$products produits en vidéo';
  }

  Widget _buildVideoBanner() {
    final preview = _videoProducts.take(3).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: GestureDetector(
        onTap: () => _openVideoFeed(),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              // Aperçu empilé des miniatures (statique, pas d'autoplay ici)
              SizedBox(
                width: 56,
                height: 40,
                child: Stack(
                  children: [
                    for (var i = 0; i < preview.length; i++)
                      Positioned(
                        left: i * 14.0,
                        child: Container(
                          width: 34,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border:
                            Border.all(color: AppColors.bgCard, width: 2),
                            image: preview[i].mediaUrl.isNotEmpty
                                ? DecorationImage(
                              image: CachedNetworkImageProvider(
                                  preview[i].mediaUrl),
                              fit: BoxFit.cover,
                            )
                                : null,
                            color: AppColors.bgElevated,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Vidéos',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(_videoBannerSubtitle(),
                        style:
                        TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.accentSubtle,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.play_arrow, color: AppColors.accent, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── CARTE PRODUIT — minimum vital : image, prix, badge vidéo, titre ───
  Widget _buildProductCard(Product product) {
    return GestureDetector(
      onTap: () {
        if (product.hasVideo) {
          final idx = _videoProducts.indexOf(product);
          if (idx != -1) {
            _openVideoFeed(initialIndex: idx);
            return;
          }
        }
        context.push('/product/${product.slug}');
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (product.mediaUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: product.mediaUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: AppColors.bgElevated),
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.bgElevated,
                        child: Icon(
                          product.isService ? Icons.build : Icons.shopping_bag,
                          color: AppColors.textMuted,
                          size: 26,
                        ),
                      ),
                    )
                  else
                    Container(
                      color: AppColors.bgElevated,
                      child: Center(
                        child: Icon(
                          product.isService ? Icons.build : Icons.shopping_bag,
                          color: AppColors.textMuted,
                          size: 26,
                        ),
                      ),
                    ),

                  // Scrim bas pour lisibilité du prix
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.55),
                          ],
                          stops: const [0.55, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Badge type — produit / service, demandé explicitement
                  // pour identifier chaque annonce au premier coup d'oeil.
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: product.isService ? AppColors.secondary : AppColors.accent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        product.isService ? 'Service' : 'Produit',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),

                  // Badge vidéo — à côté du badge type, décalé pour ne pas
                  // se chevaucher.
                  if (product.hasVideo)
                    Positioned(
                      top: 8,
                      left: product.isService ? 70 : 72,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow,
                            color: Colors.white, size: 14),
                      ),
                    ),

                  // Sauvegarde — action essentielle, pas un compteur vanity
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => _toggleSave(product),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          product.isSaved ? Icons.bookmark : Icons.bookmark_border,
                          color: product.isSaved ? AppColors.saved : Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ),

                  // Prix en overlay
                  Positioned(
                    left: 10,
                    bottom: 10,
                    right: 10,
                    child: Text(
                      product.displayPrice,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 6),

          // Titre — seule info sous l'image
          Text(
            product.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ─── SKELETON ───
  Widget _buildSkeleton() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _skeletonBox(160, 14),
                const SizedBox(height: 18),
                _skeletonBox(double.infinity, 64),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.68,
            ),
            delegate: SliverChildBuilderDelegate(
                  (context, index) => _skeletonCard(),
              childCount: 6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _skeletonBox(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _skeletonCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  // ─── EMPTY STATE ───
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 52, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text('Aucune annonce trouvée',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Essayez une autre catégorie ou revenez plus tard',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedCategory = null;
                _selectedType = 'all';
              });
              _loadData();
            },
            child: Text('Réinitialiser les filtres',
                style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}