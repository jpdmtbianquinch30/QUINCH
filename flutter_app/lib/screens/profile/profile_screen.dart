import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/product.dart';
import '../../models/favorite.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/user_service.dart';
import '../../services/product_service.dart';
import '../../services/favorite_service.dart';
import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../widgets/cached_avatar.dart';

/// ═══════════════════════════════════════════════════════════════
/// PROFIL (le sien)
/// ───────────────────────────────────────────────────────────────
/// Le système d'abonnement (Abonnés/Abonnements + bouton Suivre) a
/// été retiré : sur un marketplace, ce qui compte c'est la
/// confiance et l'activité réelle (annonces, favoris), pas un
/// compteur social. Remplacé par Produits / Favoris / Confiance.
/// ═══════════════════════════════════════════════════════════════

class ProfileScreen extends StatefulWidget {
  final String? username;
  const ProfileScreen({super.key, this.username});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _profileData;
  List<Product> _myProducts = [];
  List<Product> _likedProducts = [];
  List<FavoriteItem> _savedItems = [];
  bool _loading = true;
  bool _isOwnProfile = true;

  // Filter for own products tab
  String _productFilter = 'all'; // 'all', 'recent', 'product', 'service'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthProvider>();
      final userService = context.read<UserService>();
      final productService = context.read<ProductService>();

      if (widget.username != null && widget.username != auth.user?.username) {
        _isOwnProfile = false;
        _profileData = await userService.getSellerProfile(widget.username!);
      } else {
        _isOwnProfile = true;
        _profileData = {'user': auth.user};
      }

      // Load products — use dedicated MY products endpoint for own profile
      try {
        if (_isOwnProfile) {
          _myProducts = await productService.getMyProducts();
        } else {
          final sellerProducts = await userService.getSellerProducts(
            widget.username ?? auth.user?.username ?? '',
          );
          _myProducts = sellerProducts.map((p) {
            if (p is Product) return p;
            if (p is Map<String, dynamic>) return Product.fromJson(p);
            return null;
          }).whereType<Product>().toList();
        }
      } catch (e) {
        debugPrint('[Profile] Error loading products: $e');
      }

      // Load liked products (own profile only)
      if (_isOwnProfile && auth.isAuthenticated) {
        try {
          _likedProducts = await productService.getLikedProducts();
        } catch (e) {
          debugPrint('[Profile] Error loading likes: $e');
        }

        // Load saved/favorited items
        try {
          if (!mounted) return;
          final favService = context.read<FavoriteService>();
          _savedItems = await favService.getFavorites();
        } catch (e) {
          debugPrint('[Profile] Error loading favorites: $e');
        }
      }

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Product> get _filteredProducts {
    switch (_productFilter) {
      case 'recent':
        final sorted = List<Product>.from(_myProducts);
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return sorted;
      case 'product':
        return _myProducts.where((p) => p.isProduct).toList();
      case 'service':
        return _myProducts.where((p) => p.isService).toList();
      default:
        return _myProducts;
    }
  }

  Future<void> _startConversation() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      context.push('/auth/login');
      return;
    }

    final userId = (_profileData?['user']?['id'] ?? _profileData?['seller']?['id'])?.toString();
    if (userId == null || userId == auth.user?.id) return;

    try {
      final chat = context.read<ChatProvider>();
      final convId = await chat.startConversation(sellerId: userId);
      if (mounted && convId != null) {
        context.push('/messages/$convId');
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    dynamic user;
    if (_isOwnProfile) {
      user = auth.user;
    } else {
      user = _profileData?['user'] ?? _profileData?['seller'];
    }

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : NestedScrollView(
        headerSliverBuilder: (_, __) => [
          // ═══ COVER + AVATAR HEADER ═══
          SliverToBoxAdapter(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Cover
                Container(
                  height: 200,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [Color(0xFF1A1F35), Color(0xFF2A2F55), Color(0xFF1A1F35)],
                    ),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                  ),
                  child: _getCoverWidget(user),
                ),

                // Gradient overlay
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.transparent, AppColors.bgPrimary.withValues(alpha: 0.5)],
                    ),
                  ),
                ),

                // Back button + settings (NO logout)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 12, right: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (!_isOwnProfile)
                        _GlassButton(icon: Icons.arrow_back, onTap: () => Navigator.pop(context)),
                      const Spacer(),
                      if (_isOwnProfile)
                        _GlassButton(icon: Icons.settings, onTap: () => context.push('/settings')),
                    ],
                  ),
                ),

                // Avatar
                Positioned(
                  bottom: -45, left: 0, right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.accent, width: 3),
                        boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.3), blurRadius: 20)],
                      ),
                      child: CachedAvatar(
                        url: _getAvatarUrl(user),
                        size: 100,
                        name: _getName(user),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ═══ PROFILE INFO ═══
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 0),
              child: Column(
                children: [
                  Text(_getName(user),
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text('@${_getUsername(user)}',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),

                  const SizedBox(height: 20),

                  // Stats — Produits / Favoris / Confiance (plus de
                  // compteurs sociaux abonnés/abonnements)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        _StatButton(label: 'Produits', value: '${_myProducts.where((p) => !p.isService).length}'),
                        _divider(),
                        _StatButton(label: 'Services', value: '${_myProducts.where((p) => p.isService).length}'),
                        _divider(),
                        _StatButton(label: 'Favoris', value: '${_savedItems.length}'),
                        _divider(),
                        _StatButton(
                          label: 'Confiance',
                          value: '${_getTrustPercent(user)}%',
                          valueColor: _trustColor(_getTrustScore(user)),
                        ),
                      ],
                    ),
                  ),

                  // Trust bar
                  if (_getTrustScore(user) > 0) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _getTrustScore(user),
                        minHeight: 6,
                        backgroundColor: AppColors.bgCard,
                        valueColor: AlwaysStoppedAnimation(_trustColor(_getTrustScore(user))),
                      ),
                    ),
                  ],

                  // Actions
                  const SizedBox(height: 16),
                  if (_isOwnProfile)
                    SizedBox(
                      width: double.infinity, height: 44,
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/profile/edit'),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Modifier le profil'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    )
                  else
                  // Plus de bouton Suivre : le lien acheteur/vendeur se
                  // fait via le message et les échanges réels, pas un
                  // compteur social.
                    SizedBox(
                      width: double.infinity, height: 44,
                      child: ElevatedButton.icon(
                        onPressed: _startConversation,
                        icon: const Icon(Icons.chat_bubble_outline, size: 16, color: Colors.white),
                        label: const Text('Contacter', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),

                  // Bio — displayed under "Modifier le profil"
                  if (_getBio(user).isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(_getBio(user), textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
                    ),
                  ],

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // ═══ TABS ═══
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabHeaderDelegate(tabController: _tabController, isOwnProfile: _isOwnProfile),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: My Products
            _buildProductsTab(),
            // Tab 2: Liked
            _buildLikesTab(),
            // Tab 3: Saved/Favorites
            _buildFavoritesTab(),
          ],
        ),
      ),
    );
  }

  // ═══ PRODUCTS TAB ═══
  Widget _buildProductsTab() {
    final filtered = _filteredProducts;
    return Column(children: [
      // Filter chips
      if (_isOwnProfile)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _FilterChipWidget(label: 'Tout', selected: _productFilter == 'all', onTap: () => setState(() => _productFilter = 'all')),
              const SizedBox(width: 8),
              _FilterChipWidget(label: 'Récent', selected: _productFilter == 'recent', onTap: () => setState(() => _productFilter = 'recent')),
              const SizedBox(width: 8),
              _FilterChipWidget(label: 'Produits', selected: _productFilter == 'product', onTap: () => setState(() => _productFilter = 'product'),
                  count: _myProducts.where((p) => p.isProduct).length),
              const SizedBox(width: 8),
              _FilterChipWidget(label: 'Services', selected: _productFilter == 'service', onTap: () => setState(() => _productFilter = 'service'),
                  count: _myProducts.where((p) => p.isService).length),
            ]),
          ),
        ),

      Expanded(
        child: filtered.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.inventory_2_outlined, color: AppColors.textMuted, size: 48),
          const SizedBox(height: 12),
          Text(_isOwnProfile ? 'Vous n\'avez aucun produit' : 'Aucun produit',
              style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
          if (_isOwnProfile) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => context.push('/sell'),
              icon: const Icon(Icons.add, size: 16, color: Colors.white),
              label: const Text('Publier', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
          ],
        ]))
            : GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, childAspectRatio: 0.72,
            crossAxisSpacing: 8, mainAxisSpacing: 8,
          ),
          itemCount: filtered.length,
          itemBuilder: (_, i) => _MyProductCard(product: filtered[i], isOwn: _isOwnProfile),
        ),
      ),
    ]);
  }

  // ═══ LIKES TAB ═══
  Widget _buildLikesTab() {
    if (_likedProducts.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.favorite_border, color: AppColors.textMuted, size: 48),
        SizedBox(height: 12),
        Text('Aucun like pour le moment', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
      ]));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, childAspectRatio: 0.72,
        crossAxisSpacing: 8, mainAxisSpacing: 8,
      ),
      itemCount: _likedProducts.length,
      itemBuilder: (_, i) => _MyProductCard(product: _likedProducts[i], isOwn: false),
    );
  }

  // ═══ FAVORITES TAB ═══
  Widget _buildFavoritesTab() {
    if (_savedItems.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.bookmark_border, color: AppColors.textMuted, size: 48),
        SizedBox(height: 12),
        Text('Aucun favori pour le moment', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
      ]));
    }
    // Filter only items that have a product attached
    final withProduct = _savedItems.where((s) => s.product != null).toList();
    if (withProduct.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.bookmark_border, color: AppColors.textMuted, size: 48),
        SizedBox(height: 12),
        Text('Aucun favori pour le moment', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
      ]));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, childAspectRatio: 0.72,
        crossAxisSpacing: 8, mainAxisSpacing: 8,
      ),
      itemCount: withProduct.length,
      itemBuilder: (_, i) => _MyProductCard(product: withProduct[i].product!, isOwn: false),
    );
  }

  // ── Helpers for accessing user data ──

  String _getName(dynamic user) {
    if (user == null) return 'Utilisateur';
    if (user is Map) return user['full_name'] ?? user['name'] ?? 'Utilisateur';
    return user.fullName ?? 'Utilisateur';
  }

  String _getUsername(dynamic user) {
    if (user == null) return 'user';
    if (user is Map) return user['username'] ?? 'user';
    return user.username ?? 'user';
  }

  String _getBio(dynamic user) {
    if (user == null) return '';
    if (user is Map) return user['bio'] ?? '';
    return user.bio ?? '';
  }

  double _getTrustScore(dynamic user) {
    if (user == null) return 0;
    if (user is Map) return (user['trust_score'] ?? 0).toDouble();
    return user.trustScore ?? 0;
  }

  int _getTrustPercent(dynamic user) => (_getTrustScore(user) * 100).toInt();

  String? _getAvatarUrl(dynamic user) {
    if (user == null) return null;
    String? url;
    if (user is Map) {
      url = user['avatar_url'] ?? user['avatar'];
    } else {
      url = user.avatarUrl;
    }
    if (url != null && url.isNotEmpty) return ApiConfig.resolveUrl(url);
    return null;
  }

  Widget? _getCoverWidget(dynamic user) {
    String? coverUrl;
    if (user is Map) {
      coverUrl = user['cover_url'];
    } else if (user != null) {
      coverUrl = user.coverUrl;
    }
    if (coverUrl != null && coverUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        child: CachedNetworkImage(
          imageUrl: ApiConfig.resolveUrl(coverUrl),
          fit: BoxFit.cover,
          width: double.infinity,
          errorWidget: (_, __, ___) => const SizedBox.shrink(),
        ),
      );
    }
    return null;
  }

  Color _trustColor(double score) {
    if (score >= 0.7) return AppColors.success;
    if (score >= 0.4) return AppColors.warning;
    return AppColors.danger;
  }

  Widget _divider() => Container(width: 1, height: 32, color: AppColors.border);
}

// ═══ FILTER CHIP WIDGET ═══
class _FilterChipWidget extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;
  const _FilterChipWidget({required this.label, required this.selected, required this.onTap, this.count});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.accent : AppColors.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          )),
          if (count != null) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: selected ? Colors.white.withValues(alpha: 0.25) : AppColors.bgInput,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$count', style: TextStyle(
                color: selected ? Colors.white : AppColors.textMuted,
                fontSize: 10, fontWeight: FontWeight.w600,
              )),
            ),
          ],
        ]),
      ),
    );
  }
}

// ═══ PRODUCT CARD WITH TYPE BADGE + STOCK STATUS ═══
class _MyProductCard extends StatelessWidget {
  final Product product;
  final bool isOwn;
  const _MyProductCard({required this.product, required this.isOwn});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/product/${product.slug}'),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          color: AppColors.bgCard,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          // Image
          Expanded(
            child: Stack(fit: StackFit.expand, children: [
              if (product.mediaUrl.isNotEmpty)
                CachedNetworkImage(imageUrl: product.mediaUrl, fit: BoxFit.cover)
              else
                Container(color: AppColors.bgInput, child: Icon(Icons.image, color: AppColors.textMuted)),

              // Gradient overlay
              const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0x80000000)], stops: [0.5, 1.0])))),

              // Type badge — top left
              Positioned(top: 6, left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: product.isService ? const Color(0xFF10B981) : const Color(0xFF6366F1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    product.isService ? 'Service' : 'Produit',
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                  ),
                ),
              ),

              // Video icon — top right
              if (product.hasVideo)
                Positioned(top: 6, right: 6,
                    child: Container(width: 22, height: 22, decoration: BoxDecoration(
                        color: Colors.black54, borderRadius: BorderRadius.circular(11)),
                        child: const Icon(Icons.play_arrow, color: Colors.white, size: 13))),

              // Stock badge — bottom right (products only)
              if (product.isProduct && isOwn)
                Positioned(bottom: 6, right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: product.isInStock
                          ? AppColors.success.withValues(alpha: 0.9)
                          : AppColors.danger.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                        product.isInStock ? Icons.check_circle : Icons.cancel,
                        color: Colors.white, size: 10,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        product.isInStock ? 'Stock: ${product.stockQuantity}' : 'Épuisé',
                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700),
                      ),
                    ]),
                  ),
                ),
            ]),
          ),

          // Info section
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(product.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text(product.displayPrice,
                  style: TextStyle(
                      color: product.isService ? const Color(0xFF10B981) : AppColors.accent,
                      fontSize: 13, fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ═══ STAT BUTTON ═══
class _StatButton extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  final VoidCallback? onTap;
  const _StatButton({required this.label, required this.value, this.valueColor, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: valueColor ?? AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: onTap != null ? AppColors.accent : AppColors.textMuted)),
        ]),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _TabHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TabController tabController;
  final bool isOwnProfile;
  const _TabHeaderDelegate({required this.tabController, required this.isOwnProfile});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.bgPrimary,
      child: TabBar(
        controller: tabController,
        indicatorColor: AppColors.accent,
        labelColor: AppColors.accent,
        unselectedLabelColor: AppColors.textMuted,
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        tabs: const [
          Tab(icon: Icon(Icons.grid_on, size: 20), text: 'Mes posts'),
          Tab(icon: Icon(Icons.favorite_border, size: 20), text: 'Likes'),
          Tab(icon: Icon(Icons.bookmark_border, size: 20), text: 'Favoris'),
        ],
      ),
    );
  }

  @override
  double get maxExtent => 64;
  @override
  double get minExtent => 64;
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => false;
}