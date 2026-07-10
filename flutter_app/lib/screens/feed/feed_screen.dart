import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../../models/product.dart';
import '../../models/category.dart';
import '../../services/product_service.dart';
import '../../services/follow_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/notification_provider.dart';
import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../widgets/quinch_logo.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});
  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  // Data
  List<Product> _products = [];
  List<Product> _videoProducts = [];
  List<Category> _categories = [];
  List<dynamic> _sellers = [];
  int _currentPage = 1;
  int _lastPage = 1;
  bool _loading = false;
  bool _loadingMore = false;
  String? _selectedCategory;
  String _selectedType = 'all'; // all, product, service

  // Video player for featured video
  VideoPlayerController? _videoController;
  int _activeVideoIndex = 0;

  // Search
  bool _showSearch = false;
  List<dynamic> _searchResults = [];
  bool _searching = false;

  // Follow tracking
  final Set<String> _followedIds = {};

  static const _categories_icons = {
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
    _searchController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final ps = context.read<ProductService>();
      final feedData = await ps.getFeed(page: 1, perPage: 20);
      final categories = await ps.getCategories();

      // Active sellers from dedicated endpoint
      List<dynamic> activeSellers = [];
      try {
        final sellersResp = await ps.getActiveSellers();
        activeSellers = sellersResp;
      } catch (_) {
        // fallback to suggestions
        try { activeSellers = await ps.getSuggestions(); } catch (_) {}
      }

      final products = feedData.data;

      if (mounted) {
        setState(() {
          _products = products;
          _lastPage = feedData.lastPage;
          _categories = categories;
          _videoProducts = products.where((p) => p.hasVideo).toList();
          _sellers = activeSellers;
          _loading = false;
        });
        if (_videoProducts.isNotEmpty) _initVideo(0);
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
          _loadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _refresh() async {
    setState(() { _currentPage = 1; _products.clear(); _videoProducts.clear(); });
    await _loadData();
  }

  Future<void> _filterByCategory(String? categoryId) async {
    setState(() { _selectedCategory = categoryId; _currentPage = 1; _products.clear(); _loading = true; });
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
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _initVideo(int index) {
    _videoController?.dispose();
    if (index >= _videoProducts.length) return;
    final product = _videoProducts[index];
    final url = product.video?.effectiveUrl ?? '';
    if (url.isEmpty) return;
    final resolvedUrl = ApiConfig.resolveUrl(url);
    _videoController = VideoPlayerController.networkUrl(Uri.parse(resolvedUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
          _videoController?.setLooping(true);
          _videoController?.play();
        }
      });
  }

  Future<void> _toggleLike(Product product) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) { context.push('/login'); return; }
    final wasLiked = product.isLiked;
    setState(() {
      product.isLiked = !wasLiked;
      product.likeCount += wasLiked ? -1 : 1;
    });
    try {
      await context.read<ProductService>().toggleLike(product.id);
    } catch (_) {
      setState(() {
        product.isLiked = wasLiked;
        product.likeCount += wasLiked ? 1 : -1;
      });
    }
  }

  Future<void> _toggleSave(Product product) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) { context.push('/login'); return; }
    setState(() => product.isSaved = !product.isSaved);
    try {
      await context.read<ProductService>().toggleSave(product.id);
    } catch (_) {
      setState(() => product.isSaved = !product.isSaved);
    }
  }

  Future<void> _contactSeller(Product product) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) { context.push('/login'); return; }
    if (product.seller == null) return;
    if (product.seller!.id == auth.user?.id) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text("C'est votre propre publication"),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }
    final chat = context.read<ChatProvider>();
    final convId = await chat.startConversation(
      sellerId: product.seller!.id,
      productId: product.id,
      message: 'Bonjour, je suis intéressé(e) par "${product.title}".',
    );
    if (!mounted) return;
    if (convId != null) context.push('/messages/$convId');
  }

  Future<void> _toggleFollow(String userId) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) { context.push('/login'); return; }
    final isFollowing = _followedIds.contains(userId);
    setState(() {
      if (isFollowing) _followedIds.remove(userId);
      else _followedIds.add(userId);
    });
    try {
      final fs = context.read<FollowService>();
      if (isFollowing) await fs.unfollow(userId);
      else await fs.follow(userId);
    } catch (_) {
      setState(() {
        if (isFollowing) _followedIds.add(userId);
        else _followedIds.remove(userId);
      });
    }
  }

  String _fmtCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  // ═══════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final notifs = context.watch<NotificationProvider>();

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // ─── TOP BAR ───
            _buildTopBar(auth, notifs),

            // ─── CONTENT ───
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
                    // Stories / Sellers
                    if (_sellers.isNotEmpty)
                      SliverToBoxAdapter(child: _buildStoriesRow()),

                    // Category chips
                    if (_categories.isNotEmpty)
                      SliverToBoxAdapter(child: _buildCategoryChips()),

                    // Type filter
                    SliverToBoxAdapter(child: _buildTypeFilter()),

                    // Featured video section
                    if (_videoProducts.isNotEmpty)
                      SliverToBoxAdapter(child: _buildVideoSection()),

                    // Section header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Annonces récentes',
                                style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                            Text('${_products.length} résultats',
                                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),

                    // Products grid
                    if (_products.isEmpty)
                      SliverFillRemaining(child: _buildEmptyState())
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.72,
                          ),
                          delegate: SliverChildBuilderDelegate(
                                (context, index) => _buildProductCard(_products[index]),
                            childCount: _products.length,
                          ),
                        ),
                      ),

                    // Load more
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
  Widget _buildTopBar(AuthProvider auth, NotificationProvider notifs) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Logo QUINCH
          const QuinchLogo(size: 34, withShadow: false),
          const SizedBox(width: 4),
          Text('QUINCH', style: TextStyle(
            color: AppColors.textPrimary, fontSize: 19,
            fontWeight: FontWeight.w900, letterSpacing: -0.5,
          )),

          const SizedBox(width: 12),

          // Search bar
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showSearch = !_showSearch),
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.bgInput,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, color: AppColors.textMuted, size: 18),
                    const SizedBox(width: 8),
                    Text('Rechercher...', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Notifications
          Stack(
            children: [
              IconButton(
                onPressed: () => context.push('/notifications'),
                icon: Icon(Icons.notifications_outlined, color: AppColors.textSecondary),
                iconSize: 24,
              ),
              if (notifs.unreadCount > 0)
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    width: 16, height: 16,
                    decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                    child: Center(
                      child: Text('${notifs.unreadCount}',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── VENDEURS ACTIFS ───
  Widget _buildStoriesRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(width: 3, height: 14,
                        decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 8),
                    Text('Vendeurs actifs',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                  ],
                ),
                GestureDetector(
                  onTap: () => context.push('/explore'),
                  child: Text('Voir tout',
                      style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _sellers.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final seller = _sellers[index];
                final name = (seller['full_name'] ?? seller['title'] ?? seller['name'] ?? 'Vendeur') as String;
                final avatarRaw = (seller['avatar_url'] ?? seller['poster'] ?? seller['image'] ?? '') as String;
                final avatar = avatarRaw.isNotEmpty ? ApiConfig.resolveUrl(avatarRaw) : '';
                final username = (seller['seller'] ?? seller['username'] ?? '') as String;
                final sellerId = (seller['id'] ?? '') as String;
                final isFollowed = _followedIds.contains(sellerId);
                final city = (seller['city'] ?? '') as String;

                return GestureDetector(
                  onTap: () {
                    if (username.isNotEmpty) context.push('/seller/$username');
                  },
                  child: SizedBox(
                    width: 66,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Avatar with gradient ring if followed
                        Stack(
                          children: [
                            Container(
                              width: 60, height: 60,
                              padding: const EdgeInsets.all(2.5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: isFollowed
                                      ? [AppColors.accent, AppColors.accentLight]
                                      : [AppColors.border, AppColors.border],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.bgPrimary,
                                ),
                                padding: const EdgeInsets.all(2),
                                child: ClipOval(
                                  child: avatar.isNotEmpty
                                      ? CachedNetworkImage(
                                    imageUrl: avatar,
                                    fit: BoxFit.cover,
                                    width: 50, height: 50,
                                    errorWidget: (_, __, ___) => _avatarFallback(name, 50),
                                  )
                                      : _avatarFallback(name, 50),
                                ),
                              ),
                            ),
                            // Online dot
                            Positioned(
                              bottom: 2, right: 2,
                              child: Container(
                                width: 12, height: 12,
                                decoration: BoxDecoration(
                                  color: AppColors.online,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.bgPrimary, width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          name.split(' ').first,
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 10, fontWeight: FontWeight.w600),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                        if (city.isNotEmpty)
                          Text(city,
                            style: TextStyle(color: AppColors.textMuted, fontSize: 9),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(color: AppColors.border, height: 1),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback(String name, double size) {
    return Container(
      color: AppColors.accentSubtle,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'V',
          style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: size * 0.35),
        ),
      ),
    );
  }

  // ─── CATEGORY CHIPS ───
  Widget _buildCategoryChips() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            final isSelected = _selectedCategory == null;
            return GestureDetector(
              onTap: () => _filterByCategory(null),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.accent : AppColors.bgCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSelected ? AppColors.accent : AppColors.border),
                ),
                child: Text('Tout', style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontSize: 13, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                )),
              ),
            );
          }
          final cat = _categories[index - 1];
          final isSelected = _selectedCategory == cat.id;
          final icon = _categories_icons[cat.name] ?? Icons.category;
          return GestureDetector(
            onTap: () => _filterByCategory(isSelected ? null : cat.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.accent : AppColors.bgCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? AppColors.accent : AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 13, color: isSelected ? Colors.white : AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text(cat.name, style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── TYPE FILTER ───
  Widget _buildTypeFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          _typeBtn('all', 'Tout'),
          const SizedBox(width: 8),
          _typeBtn('product', 'Produits'),
          const SizedBox(width: 8),
          _typeBtn('service', 'Services'),
        ],
      ),
    );
  }

  Widget _typeBtn(String type, String label) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () {
        if (_selectedType == type) return;
        setState(() { _selectedType = type; _currentPage = 1; _products.clear(); });
        _filterByCategory(_selectedCategory);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentSubtle : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? AppColors.accent : AppColors.border),
        ),
        child: Text(label, style: TextStyle(
          color: isSelected ? AppColors.accent : AppColors.textMuted,
          fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        )),
      ),
    );
  }

  // ─── VIDEO SECTION ───
  Widget _buildVideoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 4, height: 16,
                    decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 8),
                  Text('Vidéos à la une',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
              Text('${_videoProducts.length} vidéos',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _videoProducts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => _buildVideoCard(_videoProducts[index], index),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoCard(Product product, int index) {
    final isActive = index == _activeVideoIndex;
    final hasPlaying = isActive && _videoController != null && _videoController!.value.isInitialized;

    return GestureDetector(
      onTap: () {
        setState(() => _activeVideoIndex = index);
        _initVideo(index);
      },
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isActive ? AppColors.accent : AppColors.border, width: isActive ? 2 : 1),
          boxShadow: isActive ? [BoxShadow(color: AppColors.accentGlow, blurRadius: 12)] : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Media
            if (hasPlaying)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoController!.value.size.width,
                  height: _videoController!.value.size.height,
                  child: VideoPlayer(_videoController!),
                ),
              )
            else if (product.mediaUrl.isNotEmpty)
              CachedNetworkImage(imageUrl: product.mediaUrl, fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(color: AppColors.bgElevated,
                      child: Icon(Icons.videocam, color: AppColors.textMuted, size: 32)))
            else
              Container(color: AppColors.bgElevated,
                  child: Icon(Icons.videocam, color: AppColors.textMuted, size: 32)),

            // Gradient
            Positioned.fill(
              child: DecoratedBox(decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                  stops: const [0.4, 1.0],
                ),
              )),
            ),

            // Play icon
            if (!hasPlaying)
              Center(
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.play_arrow, color: AppColors.accent, size: 22),
                ),
              ),

            // Info at bottom
            Positioned(
              bottom: 8, left: 8, right: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(product.displayPrice,
                      style: TextStyle(color: AppColors.accentLight, fontSize: 11, fontWeight: FontWeight.w700)),
                ],
              ),
            ),

            // Type badge
            Positioned(
              top: 8, left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: product.isService ? AppColors.secondary : AppColors.accent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(product.isService ? 'Service' : 'Produit',
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── PRODUCT CARD (2-column grid) ───
  Widget _buildProductCard(Product product) {
    final accentColor = product.isService ? AppColors.secondary : AppColors.accent;

    return GestureDetector(
      onTap: () => context.push('/product/${product.slug}'),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image / Thumbnail ──
            Expanded(
              flex: 55,
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
                        child: Icon(product.isService ? Icons.build : Icons.shopping_bag,
                            color: AppColors.textMuted, size: 28),
                      ),
                    )
                  else
                    Container(
                      color: AppColors.bgElevated,
                      child: Center(child: Icon(
                        product.isService ? Icons.build : Icons.shopping_bag,
                        color: AppColors.textMuted, size: 28,
                      )),
                    ),

                  // Video play overlay
                  if (product.hasVideo)
                    Center(
                      child: Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.85), shape: BoxShape.circle),
                        child: Icon(Icons.play_arrow, color: accentColor, size: 18),
                      ),
                    ),

                  // Type badge
                  Positioned(
                    top: 6, left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(product.isService ? 'Service' : 'Produit',
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700)),
                    ),
                  ),

                  // Save button
                  Positioned(
                    top: 4, right: 4,
                    child: GestureDetector(
                      onTap: () => _toggleSave(product),
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.bgCard.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          product.isSaved ? Icons.bookmark : Icons.bookmark_border,
                          color: product.isSaved ? AppColors.saved : AppColors.textMuted,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Info ──
            Expanded(
              flex: 45,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product.title,
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600, height: 1.3)),
                        if (product.seller?.displayName != null) ...[
                          const SizedBox(height: 2),
                          Text('@${product.seller!.username ?? product.seller!.displayName}',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ],
                    ),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product.displayPrice,
                            style: TextStyle(color: accentColor, fontSize: 13, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => _toggleLike(product),
                              child: Row(
                                children: [
                                  Icon(
                                    product.isLiked ? Icons.favorite : Icons.favorite_border,
                                    color: product.isLiked ? AppColors.liked : AppColors.textMuted,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(_fmtCount(product.likeCount),
                                      style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                                ],
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => _contactSeller(product),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: accentColor,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('Contacter',
                                    style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── SKELETON LOADING ───
  Widget _buildSkeleton() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _skeletonBox(100, 12),
                const SizedBox(height: 16),
                SizedBox(
                  height: 60,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 6,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, __) => _skeletonCircle(52),
                  ),
                ),
                const SizedBox(height: 20),
                _skeletonBox(120, 14),
                const SizedBox(height: 12),
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 5,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, __) => _skeletonBox(80, 32),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.72,
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
      width: width, height: height,
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _skeletonCircle(double size) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: AppColors.bgCard, shape: BoxShape.circle),
    );
  }

  Widget _skeletonCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
    );
  }

  // ─── EMPTY STATE ───
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 56, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text('Aucune annonce trouvée',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Essayez une autre catégorie ou revenez plus tard',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () { setState(() { _selectedCategory = null; _selectedType = 'all'; }); _loadData(); },
            child: const Text('Réinitialiser les filtres'),
          ),
        ],
      ),
    );
  }
}