import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/product.dart';
import '../../models/category.dart';
import '../../services/product_service.dart';
import '../../services/follow_service.dart';
import '../../providers/auth_provider.dart';
import '../../config/api_config.dart';
import '../../config/theme.dart';

const Color _skyBlue = Color(0xFF7EC8E3);

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final _searchController = TextEditingController();
  List<Product> _products = [];
  List<Category> _categories = [];
  String? _selectedCategory;
  String? _type;
  bool _loading = true;
  int _page = 1;
  int _lastPage = 1;

  // Follow suggestions
  List<dynamic> _suggestedUsers = [];
  final Set<String> _followedIds = {};

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadProducts();
    _loadSuggestedUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await context.read<ProductService>().getCategories();
      if (mounted) setState(() => _categories = cats);
    } catch (_) {}
  }

  Future<void> _loadProducts({bool refresh = false}) async {
    if (refresh) { _page = 1; _products.clear(); }
    setState(() => _loading = true);
    try {
      final result = await context.read<ProductService>().getProducts(
        page: _page,
        search: _searchController.text.isNotEmpty ? _searchController.text : null,
        categoryId: _selectedCategory,
        type: _type,
      );
      if (!mounted) return;
      setState(() {
        if (refresh) _products.clear();
        _products.addAll(result['data'] as List<Product>);
        _lastPage = result['last_page'] as int? ?? 1;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[MarketplaceScreen] Error loading products: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadSuggestedUsers() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) return;
    try {
      final result = await context.read<ProductService>().search('a');
      if (!mounted) return;
      final users = result['users'] ?? [];
      if (users is List && users.isNotEmpty) {
        setState(() => _suggestedUsers = users.take(8).toList());
      }
    } catch (_) {}
  }

  void _loadMore() {
    if (_page < _lastPage) { _page++; _loadProducts(); }
  }

  void _toggleFollow(String userId) {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) { context.push('/auth/login'); return; }
    final followService = context.read<FollowService>();
    final wasFollowing = _followedIds.contains(userId);
    setState(() {
      if (wasFollowing) { _followedIds.remove(userId); } else { _followedIds.add(userId); }
    });
    if (wasFollowing) {
      followService.unfollow(userId).catchError((e) {
        if (mounted) setState(() => _followedIds.add(userId));
        return;
      });
    } else {
      followService.follow(userId).then((_) {}).catchError((e) {
        if (mounted) setState(() => _followedIds.remove(userId));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgSecondary,
        title: const Text('Explorer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Rechercher produits, services...',
                prefixIcon: const Icon(Icons.search, color: _skyBlue, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(icon: Icon(Icons.close, size: 18, color: AppColors.textMuted),
                        onPressed: () { _searchController.clear(); _loadProducts(refresh: true); })
                    : null,
                filled: true,
                fillColor: AppColors.bgInput,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onSubmitted: (_) => _loadProducts(refresh: true),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // ═══ FILTERS ═══
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(children: [
                    Expanded(child: _FilterChip(label: 'Tout', active: _type == null, onTap: () { setState(() => _type = null); _loadProducts(refresh: true); })),
                    const SizedBox(width: 8),
                    Expanded(child: _FilterChip(label: 'Produits', icon: Icons.shopping_bag, active: _type == 'product',
                      onTap: () { setState(() => _type = 'product'); _loadProducts(refresh: true); })),
                    const SizedBox(width: 8),
                    Expanded(child: _FilterChip(label: 'Services', icon: Icons.handyman, active: _type == 'service',
                      color: AppColors.secondary,
                      onTap: () { setState(() => _type = 'service'); _loadProducts(refresh: true); })),
                  ]),
                ),
                const SizedBox(height: 8),
                if (_categories.isNotEmpty)
                  SizedBox(
                    height: 32,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _categories.length + 1,
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return _CatChip(label: 'Toutes', active: _selectedCategory == null,
                            onTap: () { setState(() => _selectedCategory = null); _loadProducts(refresh: true); });
                        }
                        final cat = _categories[i - 1];
                        return _CatChip(label: cat.name, active: _selectedCategory == cat.id,
                          onTap: () { setState(() => _selectedCategory = cat.id); _loadProducts(refresh: true); });
                      },
                    ),
                  ),
              ],
            ),
          ),

          // ═══ MAIN CONTENT ═══
          Expanded(
            child: _loading && _products.isEmpty
                ? const Center(child: CircularProgressIndicator(color: _skyBlue))
                : _products.isEmpty
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.search_off, size: 48, color: AppColors.textMuted.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        Text('Aucun résultat', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('Essayez avec d\'autres filtres', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                      ]))
                    : NotificationListener<ScrollNotification>(
                        onNotification: (scroll) {
                          if (scroll.metrics.pixels > scroll.metrics.maxScrollExtent - 200) _loadMore();
                          return false;
                        },
                        child: CustomScrollView(
                          slivers: [
                            // ═══ FOLLOW SUGGESTIONS (horizontal) ═══
                            if (auth.isAuthenticated && _suggestedUsers.isNotEmpty)
                              SliverToBoxAdapter(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                                      child: Text('Suggestions de suivi', style: TextStyle(color: _skyBlue, fontWeight: FontWeight.w700, fontSize: 14)),
                                    ),
                                    SizedBox(
                                      height: 150,
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        itemCount: _suggestedUsers.length,
                                        itemBuilder: (context, i) => _buildSuggestionCard(_suggestedUsers[i]),
                                      ),
                                    ),
                                    Divider(color: AppColors.border, height: 16),
                                  ],
                                ),
                              ),

                            // ═══ PRODUCT GRID ═══
                            SliverPadding(
                              padding: const EdgeInsets.all(12),
                              sliver: SliverGrid(
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2, childAspectRatio: 0.68,
                                  crossAxisSpacing: 10, mainAxisSpacing: 10,
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, i) => _MarketCard(product: _products[i]),
                                  childCount: _products.length,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(dynamic user) {
    final userId = user['id']?.toString() ?? '';
    final name = user['full_name'] ?? user['username'] ?? '';
    final username = user['username'] ?? '';
    final avatar = user['avatar_url'] ?? user['avatar'] ?? '';
    final city = user['city'] ?? '';
    final isFollowed = _followedIds.contains(userId);

    return GestureDetector(
      onTap: () => context.push('/seller/$username'),
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _skyBlue.withValues(alpha: 0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildAvatar(avatar, name, 44),
            const SizedBox(height: 8),
            Text(name, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 12),
              maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
            if (city.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(city, style: TextStyle(color: AppColors.textMuted, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
            const Spacer(),
            GestureDetector(
              onTap: () => _toggleFollow(userId),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: isFollowed ? AppColors.bgElevated : _skyBlue,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  isFollowed ? 'Suivi' : 'Suivre',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isFollowed ? AppColors.textMuted : Colors.white,
                    fontWeight: FontWeight.w600, fontSize: 11,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String url, String name, double size) {
    final resolvedUrl = url.isNotEmpty ? ApiConfig.resolveUrl(url) : '';
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _skyBlue.withValues(alpha: 0.5), width: 2),
        color: AppColors.bgElevated,
      ),
      clipBehavior: Clip.antiAlias,
      child: resolvedUrl.isNotEmpty
          ? CachedNetworkImage(imageUrl: resolvedUrl, fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Center(child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(color: _skyBlue, fontWeight: FontWeight.w700, fontSize: size * 0.4),
              )),
            )
          : Center(child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(color: _skyBlue, fontWeight: FontWeight.w700, fontSize: size * 0.4),
            )),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool active;
  final Color? color;
  final VoidCallback onTap;
  const _FilterChip({required this.label, this.icon, required this.active, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.accent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? c.withValues(alpha: 0.15) : AppColors.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? c.withValues(alpha: 0.4) : AppColors.border),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (icon != null) ...[Icon(icon, size: 14, color: active ? c : AppColors.textMuted), SizedBox(width: 4)],
          Text(label, style: TextStyle(fontSize: 13, fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            color: active ? c : AppColors.textSecondary)),
        ]),
      ),
    );
  }
}

class _CatChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _CatChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: active ? AppColors.accentSubtle : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? AppColors.accent.withValues(alpha: 0.3) : AppColors.border),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          color: active ? AppColors.accentLight : AppColors.textMuted)),
      ),
    );
  }
}

class _MarketCard extends StatelessWidget {
  final Product product;
  const _MarketCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/product/${product.slug}'),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (product.mediaUrl.isNotEmpty)
              CachedNetworkImage(imageUrl: product.mediaUrl, fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [Color(0xFF12141D), Color(0xFF1A1D2E)]),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(color: AppColors.bgCard,
                  child: Icon(Icons.image, color: AppColors.textMuted, size: 32)),
              )
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0xFF12141D), Color(0xFF1A1D2E)]),
                ),
                child: Icon(product.isService ? Icons.handyman : Icons.inventory_2, color: AppColors.textMuted, size: 32),
              ),
            const Positioned.fill(
              child: DecoratedBox(decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.transparent, Color(0x26000000), Color(0xA6000000)],
                  stops: [0.0, 0.4, 0.65, 1.0]),
              )),
            ),
            Positioned(
              top: 8, left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: product.isService ? const Color(0xE010B981) : const Color(0xE06366F1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(product.isService ? 'Service' : 'Produit',
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
              ),
            ),
            if (product.condition.isNotEmpty)
              Positioned(
                top: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(20)),
                  child: Text(product.condition, style: const TextStyle(color: Colors.white70, fontSize: 9)),
                ),
              ),
            if (product.isNegotiable)
              Positioned(
                bottom: 56, left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(20)),
                  child: const Text('Négociable', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
                ),
              ),
            Positioned(
              left: 10, right: 10, bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Flexible(
                      child: Text(product.displayPrice, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.accentLight, fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                    if (product.seller != null) ...[
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text('@${product.seller!.username}', maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10)),
                      ),
                    ],
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
