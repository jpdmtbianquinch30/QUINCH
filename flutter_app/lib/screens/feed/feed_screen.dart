import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/product.dart';
import '../../services/product_service.dart';
import '../../services/follow_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/notification_provider.dart';
import '../../config/api_config.dart';
import '../../config/theme.dart';

// ═══ Sky Blue accent for header elements ═══
const Color _skyBlue = Color(0xFF7EC8E3);
const Color _skyBlueActive = Color(0xFFAEDFF7);

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final PageController _pageController = PageController();
  final List<Product> _products = [];
  int _currentPage = 1;
  int _lastPage = 1;
  bool _loading = false;
  int _currentIndex = 0;
  String _activeTab = 'foryou';
  VideoPlayerController? _videoController;
  bool _videoPaused = false;

  // Double-tap heart animation
  bool _showHeart = false;

  // Search overlay
  bool _showSearch = false;
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  List<dynamic> _searchResults = [];
  List<dynamic> _suggestions = [];
  bool _searching = false;

  // Follow suggestions
  List<dynamic> _followSuggestions = [];
  bool _loadingSuggestions = false;

  // Track followed user IDs for instant UI updates
  final Set<String> _followedIds = {};

  // Track already-loaded product IDs to exclude from subsequent loads
  final Set<String> _seenProductIds = {};
  // Per-session random seed so feed order varies on each app launch / refresh
  int _feedSeed = DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    _loadFeed();
    _loadFollowSuggestions();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _videoController?.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ─── SEARCH ───
  void _openSearch() {
    setState(() => _showSearch = true);
    _loadSearchSuggestions();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  void _closeSearch() {
    setState(() {
      _showSearch = false;
      _searchController.clear();
      _searchResults.clear();
      _searching = false;
    });
  }

  Future<void> _loadSearchSuggestions() async {
    try {
      final service = context.read<ProductService>();
      final auth = context.read<AuthProvider>();
      List<dynamic> data = [];
      try {
        data = auth.isAuthenticated
            ? await service.getSuggestions()
            : await service.getTrending();
      } catch (_) {
        // Fallback: if trending fails too, just leave empty
      }
      if (mounted) setState(() => _suggestions = data);
    } catch (_) {}
  }

  Future<void> _doSearch(String query) async {
    if (query.length < 2) {
      setState(() { _searchResults.clear(); _searching = false; });
      return;
    }
    setState(() => _searching = true);
    try {
      final result = await context.read<ProductService>().search(query);
      if (!mounted) return;
      final users = result['users'] ?? result['sellers'] ?? [];
      final products = result['products'] ?? result['data'] ?? [];
      setState(() {
        _searchResults = [
          ...((users as List).map((u) => {'type': 'user', 'data': u})),
          ...((products as List).map((p) => {'type': 'product', 'data': p})),
        ];
        _searching = false;
      });
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  // ─── FEED LOADING ───
  Future<void> _loadFeed({bool refresh = false}) async {
    if (_loading || !mounted) return;
    setState(() => _loading = true);
    try {
      final service = context.read<ProductService>();
      final auth = context.read<AuthProvider>();
      final page = refresh ? 1 : _currentPage;
      FeedResponse response;

      // On refresh, generate a new seed and clear seen IDs for a fresh ordering
      if (refresh) {
        _feedSeed = DateTime.now().millisecondsSinceEpoch;
        _seenProductIds.clear();
      }

      // Build the exclude list from already-loaded products
      final excludeIds = _seenProductIds.isNotEmpty ? _seenProductIds.toList() : null;

      // "following" and "friends" tabs require authentication
      if (_activeTab == 'following' && auth.isAuthenticated) {
        response = await service.getFollowingFeed(page: page, perPage: 10, excludeIds: excludeIds);
      } else if (_activeTab == 'friends' && auth.isAuthenticated) {
        response = await service.getFriendsFeed(page: page, excludeIds: excludeIds);
      } else {
        // "Pour toi" is public, also fallback for non-auth tabs
        response = await service.getFeed(page: page, perPage: 10, excludeIds: excludeIds, seed: _feedSeed);
      }
      if (!mounted) return;
      // Initialize followedIds from product data
      for (final p in response.data) {
        if (p.seller != null && p.seller!.isFollowing == true) {
          _followedIds.add(p.seller!.id);
        }
        // Track IDs of loaded products so we don't get them again
        _seenProductIds.add(p.id);
      }
      setState(() {
        if (refresh) { _products.clear(); _currentPage = 1; }
        _products.addAll(response.data);
        _lastPage = response.lastPage;
        _loading = false;
      });
      if (_products.isNotEmpty && _currentIndex == 0) _initVideo(0);
    } catch (e) {
      debugPrint('[FeedScreen] Error loading feed ($_activeTab): $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  // ─── FOLLOW SUGGESTIONS ───
  Future<void> _loadFollowSuggestions() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) return;
    setState(() => _loadingSuggestions = true);
    try {
      final service = context.read<ProductService>();
      List<dynamic> users = [];

      // Get suggested profiles via search
      try {
        final searchResult = await service.search('a');
        if (searchResult['users'] is List) {
          users = (searchResult['users'] as List).take(10).toList();
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _followSuggestions = users;
          _loadingSuggestions = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSuggestions = false);
    }
  }

  // ─── VIDEO ───
  void _initVideo(int index) {
    if (index >= _products.length) return;
    final product = _products[index];
    _videoController?.dispose();
    _videoController = null;
    if (product.hasVideo) {
      final videoUrl = product.video!.effectiveUrl;
      debugPrint('[FeedScreen] Loading video: $videoUrl');
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      _videoController = controller;
      controller.initialize().then((_) {
        if (mounted && _videoController == controller) {
          controller.setLooping(true);
          controller.setVolume(1.0);
          controller.play();
          setState(() {});
          debugPrint('[FeedScreen] Video playing, looping=true, duration=${controller.value.duration}');
        }
      }).catchError((e) {
        debugPrint('[FeedScreen] Video error: $e');
        if (mounted) setState(() {});
      });
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    _initVideo(index);
    // Track view only if authenticated (it's an auth-required endpoint)
    if (index < _products.length) {
      final auth = context.read<AuthProvider>();
      if (auth.isAuthenticated) {
        context.read<ProductService>().trackView(_products[index].id).catchError((_) {});
      }
    }
    if (index >= _products.length - 3 && _currentPage < _lastPage) {
      _currentPage++;
      _loadFeed();
    }
  }

  void _switchTab(String tab) {
    setState(() { _activeTab = tab; _products.clear(); _currentPage = 1; _currentIndex = 0; });
    _seenProductIds.clear();
    _feedSeed = DateTime.now().millisecondsSinceEpoch;
    _videoController?.dispose();
    _videoController = null;
    _loadFeed(refresh: true);
  }

  // ─── VIDEO PLAY/PAUSE ───
  void _toggleVideoPlayPause() {
    final ctrl = _videoController;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    setState(() {
      if (ctrl.value.isPlaying) {
        ctrl.pause();
        _videoPaused = true;
      } else {
        ctrl.play();
        _videoPaused = false;
      }
    });
  }

  // ─── DOUBLE TAP LIKE WITH HEART ANIMATION ───
  void _doubleTapLike(Product product) {
    // Show heart animation
    setState(() => _showHeart = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showHeart = false);
    });
    // Like (only if not already liked)
    if (!product.isLiked) {
      _toggleLike(product);
    }
  }

  // ─── INTERACTIONS (optimistic / instant) ───
  void _toggleLike(Product product) {
    if (!context.read<AuthProvider>().isAuthenticated) { context.push('/auth/login'); return; }
    final wasLiked = product.isLiked;
    // Optimistic update — instant UI with count
    setState(() {
      product.isLiked = !wasLiked;
      product.likeCount += wasLiked ? -1 : 1;
      if (product.likeCount < 0) product.likeCount = 0;
    });
    // API call
    context.read<ProductService>().toggleLike(product.id).then((result) {
      if (mounted) {
        setState(() {
          product.isLiked = result['is_liked'] ?? product.isLiked;
          if (result['like_count'] != null) product.likeCount = result['like_count'];
        });
      }
    }).catchError((_) {
      // Revert on error
      if (mounted) {
        setState(() {
          product.isLiked = wasLiked;
          product.likeCount += wasLiked ? 1 : -1;
        });
      }
    });
  }

  void _toggleSave(Product product) {
    if (!context.read<AuthProvider>().isAuthenticated) { context.push('/auth/login'); return; }
    final wasSaved = product.isSaved;
    // Optimistic update
    setState(() { product.isSaved = !wasSaved; });
    context.read<ProductService>().toggleSave(product.id).then((result) {
      if (mounted) {
        setState(() { product.isSaved = result['saved'] ?? product.isSaved; });
      }
    }).catchError((_) {
      if (mounted) setState(() { product.isSaved = wasSaved; });
    });
  }

  void _toggleFollow(String userId) {
    if (!context.read<AuthProvider>().isAuthenticated) { context.push('/auth/login'); return; }
    final followService = context.read<FollowService>();
    final wasFollowing = _followedIds.contains(userId);
    debugPrint('[Feed] toggleFollow userId=$userId wasFollowing=$wasFollowing');
    // Optimistic
    setState(() {
      if (wasFollowing) {
        _followedIds.remove(userId);
      } else {
        _followedIds.add(userId);
      }
    });
    if (wasFollowing) {
      followService.unfollow(userId).then((_) {
        debugPrint('[Feed] unfollow SUCCESS userId=$userId');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Désabonné'), duration: Duration(seconds: 1)),
          );
        }
      }).catchError((e) {
        debugPrint('[Feed] unfollow ERROR userId=$userId: $e');
        if (mounted) {
          setState(() => _followedIds.add(userId));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erreur lors du désabonnement'), duration: Duration(seconds: 1)),
          );
        }
      });
    } else {
      followService.follow(userId).then((result) {
        debugPrint('[Feed] follow SUCCESS userId=$userId result=$result');
        if (mounted) {
          final isMutual = result['is_mutual'] == true;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isMutual ? 'Vous êtes maintenant amis !' : 'Abonné !'),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }).catchError((e) {
        debugPrint('[Feed] follow ERROR userId=$userId: $e');
        final errStr = e.toString();
        if (errStr.contains('422')) {
          // 422 = already following — keep the green check, don't revert
          debugPrint('[Feed] Already following userId=$userId — keeping state');
          if (mounted) {
            setState(() => _followedIds.add(userId)); // ensure it stays
          }
        } else {
          if (mounted) {
            setState(() => _followedIds.remove(userId));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Erreur lors de l\'abonnement'), duration: Duration(seconds: 1)),
            );
          }
        }
      });
    }
  }

  void _shareProduct(Product product) {
    if (context.read<AuthProvider>().isAuthenticated) {
      context.read<ProductService>().shareProduct(product.id).catchError((_) {});
    }
  }

  Future<void> _contactSeller(Product product) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) { context.push('/auth/login'); return; }
    if (product.seller == null) return;

    // Check if trying to contact yourself
    if (product.seller!.id == auth.user?.id) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('C\'est votre propre publication', style: TextStyle(fontSize: 13)),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return;
    }

    // Show loading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 12),
            Text('Démarrage de la conversation...', style: TextStyle(fontSize: 13)),
          ]),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    // Start or find existing conversation with this seller about this product
    final chat = context.read<ChatProvider>();
    final convId = await chat.startConversation(
      sellerId: product.seller!.id,
      productId: product.id,
      message: 'Bonjour, je suis intéressé(e) par "${product.title}".',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (convId != null) {
      context.push('/messages/$convId');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Impossible de démarrer la conversation. Réessayez.', style: TextStyle(fontSize: 13)),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  // ─── BUILD ───
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF06060C),
      body: Stack(
        children: [
          // ═══ BACKGROUND GLOW ═══
          Positioned(
            top: -100, left: -50,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [_skyBlue.withValues(alpha: 0.04), Colors.transparent]),
              ),
            ),
          ),

          // ═══ MAIN CONTENT ═══
          if (_products.isEmpty && _loading)
            const Center(child: CircularProgressIndicator(color: _skyBlue))
          else if (_products.isEmpty)
            _buildEmptyState()
          else
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              onPageChanged: _onPageChanged,
              itemCount: _products.length,
              itemBuilder: (context, index) => _buildFeedItem(_products[index], index),
            ),

          // ═══ HEADER ═══
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // Search icon — sky blue
                  GestureDetector(
                    onTap: _openSearch,
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: _skyBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: const Icon(Icons.search, color: _skyBlue, size: 22),
                    ),
                  ),
                  // Tabs
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (auth.isAuthenticated)
                          _TabButton(label: 'Abonnés', active: _activeTab == 'following', onTap: () => _switchTab('following')),
                        _TabButton(label: 'Pour toi', active: _activeTab == 'foryou', onTap: () => _switchTab('foryou')),
                        if (auth.isAuthenticated)
                          _TabButton(label: 'Amis', active: _activeTab == 'friends', onTap: () => _switchTab('friends')),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  const _NotifBell(),
                ],
              ),
            ),
          ),

          // ═══ SEARCH OVERLAY ═══
          if (_showSearch) _buildSearchOverlay(),
        ],
      ),
    );
  }

  // ─── EMPTY STATE WITH FOLLOW SUGGESTIONS ───
  Widget _buildEmptyState() {
    final auth = context.watch<AuthProvider>();
    final showSuggestions = auth.isAuthenticated && (_activeTab == 'following' || _activeTab == 'friends');

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _activeTab == 'following' ? Icons.people_outline
                : _activeTab == 'friends' ? Icons.group_outlined
                : Icons.play_circle_outline,
              size: 64, color: _skyBlue.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              _activeTab == 'following' ? 'Suivez des vendeurs'
                : _activeTab == 'friends' ? 'Ajoutez des amis'
                : 'Aucune publication',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              _activeTab == 'following' ? 'Suivez des vendeurs pour voir leurs publications ici'
                : _activeTab == 'friends' ? 'Les publications de vos amis apparaîtront ici'
                : 'Revenez bientôt !',
              style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            // Follow suggestions
            if (showSuggestions) ...[
              const SizedBox(height: 28),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Suggestions de suivi', style: TextStyle(color: _skyBlue, fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 12),
              if (_loadingSuggestions)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: _skyBlue, strokeWidth: 2),
                )
              else if (_followSuggestions.isEmpty)
                Text('Aucune suggestion pour le moment', style: TextStyle(color: AppColors.textMuted, fontSize: 13))
              else
                ..._followSuggestions.map((user) => _buildSuggestionCard(user)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionCard(dynamic user) {
    final userId = user['id']?.toString() ?? '';
    final name = user['full_name'] ?? user['username'] ?? '';
    final username = user['username'] ?? '';
    final avatar = user['avatar_url'] ?? user['avatar'] ?? '';
    final city = user['city'] ?? '';
    final isFollowed = _followedIds.contains(userId) || (user['is_following'] == true);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _skyBlue.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          // Avatar
          GestureDetector(
            onTap: () => context.push('/seller/$username'),
            child: _buildAvatar(avatar, name, 44),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: GestureDetector(
              onTap: () => context.push('/seller/$username'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('@$username${city.isNotEmpty ? ' · $city' : ''}', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Follow button — instant response
          GestureDetector(
            onTap: () => _toggleFollow(userId),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isFollowed ? AppColors.bgElevated : _skyBlue,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isFollowed ? AppColors.border : _skyBlue),
              ),
              child: Text(
                isFollowed ? 'Suivi' : 'Suivre',
                style: TextStyle(
                  color: isFollowed ? AppColors.textMuted : Colors.white,
                  fontWeight: FontWeight.w600, fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── FEED ITEM ───
  Widget _buildFeedItem(Product product, int index) {
    final isActive = index == _currentIndex;
    final controller = isActive ? _videoController : null;
    final hasPlayingVideo = product.hasVideo && isActive && controller != null && controller.value.isInitialized;

    return GestureDetector(
      onDoubleTap: () => _doubleTapLike(product),
      onTap: () {
        // Tap on video = pause/play, tap on image = nothing (use buttons)
        if (hasPlayingVideo) {
          _toggleVideoPlayPause();
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ═══ VIDEO / IMAGE ═══
          if (hasPlayingVideo)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            )
          else if (product.hasVideo)
            // For videos: plain dark background while loading (no thumbnail)
            Container(color: const Color(0xFF0A0A16))
          else if (product.mediaUrl.isNotEmpty)
            CachedNetworkImage(imageUrl: product.mediaUrl, fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: const Color(0xFF0A0A16)),
              errorWidget: (_, __, ___) => Container(color: const Color(0xFF0A0A16), child: const Icon(Icons.image, color: Colors.white12, size: 48)),
            )
          else
            Container(color: const Color(0xFF0A0A16), child: Icon(product.isService ? Icons.handyman : Icons.image, size: 48, color: Colors.white12)),

          // ═══ VIDEO LOADING INDICATOR (small spinner) ═══
          if (product.hasVideo && !hasPlayingVideo)
            const Center(
              child: SizedBox(
                width: 32, height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white38,
                ),
              ),
            ),

          // ═══ DOUBLE-TAP HEART ANIMATION ═══
          if (_showHeart && isActive)
            Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.5, end: 1.0),
                duration: const Duration(milliseconds: 400),
                curve: Curves.elasticOut,
                builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
                child: const Icon(Icons.favorite, color: Colors.redAccent, size: 100,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 20)],
                ),
              ),
            ),

          // ═══ GRADIENT ═══
          const Positioned.fill(
            child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.transparent, Color(0xDD000000)],
              stops: [0.0, 0.35, 1.0],
            ))),
          ),

          // ═══ TYPE BADGE ═══
          Positioned(
            top: 100, left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: product.isService ? const Color(0xCC10B981) : const Color(0xCC6366F1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(product.isService ? Icons.handyman : Icons.shopping_bag, color: Colors.white, size: 13),
                const SizedBox(width: 4),
                Text(product.isService ? 'Service' : 'Produit',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),

          // ═══ BOTTOM INFO ═══
          Positioned(
            left: 16, right: 80, bottom: 90,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Seller name (registered name, no avatar)
                GestureDetector(
                  onTap: () {
                    if (product.seller?.username != null) context.push('/seller/${product.seller!.username}');
                  },
                  child: Row(children: [
                    Flexible(
                      child: Text(
                        product.seller?.displayName ?? product.seller?.username ?? 'Vendeur',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if ((product.seller?.trustScore ?? 0) >= 0.7) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified, color: _skyBlue, size: 15),
                    ],
                    if (product.seller?.city != null && product.seller!.city!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text('· ${product.seller!.city!}', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                    ],
                  ]),
                ),
                const SizedBox(height: 8),
                // Title
                Text(product.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                if (product.description != null && product.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(product.description!, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                ],
                const SizedBox(height: 10),
                // Price badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: product.isService
                        ? const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF34D399)])
                        : const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF818CF8)]),
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: [
                      BoxShadow(
                        color: (product.isService ? AppColors.secondary : AppColors.accent).withValues(alpha: 0.3),
                        blurRadius: 12, offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(product.displayPrice, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                    if (product.isNegotiable) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                        child: const Text('Négo', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ]),
                ),
                // ═══ ACTION BUTTONS: Voir détail + Contacter ═══
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Voir détail
                    Expanded(
                      child: GestureDetector(
                        onTap: () => context.push('/product/${product.slug}'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.visibility_outlined, color: Colors.white, size: 16),
                              SizedBox(width: 6),
                              Text('Voir détail', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Contacter — green for services, indigo for products
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _contactSeller(product),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            gradient: product.isService
                                ? const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF34D399)])
                                : const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF818CF8)]),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline, color: Colors.white, size: 16),
                              SizedBox(width: 6),
                              Text('Contacter', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ═══ RIGHT SIDE ACTIONS ═══
          Positioned(
            right: 10, bottom: 160,
            child: Column(
              children: [
                // ── Seller avatar + Follow ──
                GestureDetector(
                  onTap: () {
                    if (product.seller?.username != null) context.push('/seller/${product.seller!.username}');
                  },
                  child: Builder(builder: (ctx) {
                    final sellerId = product.seller?.id ?? '';
                    final isFollowed = _followedIds.contains(sellerId) || (product.seller?.isFollowing == true);
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _buildAvatar(product.seller?.displayAvatar ?? '', product.seller?.displayName ?? 'V', 48),
                        // Follow / Following button
                        if (product.seller != null)
                          Positioned(
                            bottom: -6, left: 0, right: 0,
                            child: Center(
                              child: GestureDetector(
                                onTap: () => _toggleFollow(sellerId),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 22, height: 22,
                                  decoration: BoxDecoration(
                                    color: isFollowed ? AppColors.success : _skyBlue,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFF06060C), width: 2),
                                  ),
                                  child: Icon(
                                    isFollowed ? Icons.check : Icons.add,
                                    color: Colors.white, size: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  }),
                ),
                const SizedBox(height: 16),
                // ── Like ──
                _SideAction(
                  icon: product.isLiked ? Icons.favorite : Icons.favorite_border,
                  label: _fmtCount(product.likeCount),
                  color: product.isLiked ? AppColors.liked : Colors.white,
                  onTap: () => _toggleLike(product),
                ),
                const SizedBox(height: 10),
                // ── Avis ──
                _SideAction(
                  icon: Icons.chat_bubble_outline,
                  label: 'Avis',
                  onTap: () => context.push('/product/${product.slug}'),
                ),
                const SizedBox(height: 10),
                // ── Share ──
                _SideAction(
                  icon: Icons.reply,
                  label: _fmtCount(product.shareCount),
                  onTap: () => _shareProduct(product),
                ),
                const SizedBox(height: 10),
                // ── Save ──
                _SideAction(
                  icon: product.isSaved ? Icons.bookmark : Icons.bookmark_border,
                  label: product.isSaved ? 'Sauvé' : 'Sauver',
                  color: product.isSaved ? AppColors.saved : Colors.white,
                  onTap: () => _toggleSave(product),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── AVATAR BUILDER ───
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
                name.isNotEmpty ? name[0].toUpperCase() : 'V',
                style: TextStyle(color: _skyBlue, fontWeight: FontWeight.w700, fontSize: size * 0.4),
              )),
            )
          : Center(child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'V',
              style: TextStyle(color: _skyBlue, fontWeight: FontWeight.w700, fontSize: size * 0.4),
            )),
    );
  }

  String _fmtCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  // ─── SEARCH OVERLAY ───
  Widget _buildSearchOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: _closeSearch,
        child: Container(
          color: Colors.black.withValues(alpha: 0.88),
          child: SafeArea(
            child: GestureDetector(
              onTap: () {},
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _skyBlue.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      IconButton(
                        onPressed: _closeSearch,
                        icon: const Icon(Icons.arrow_back, color: _skyBlue, size: 22),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocus,
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
                          decoration: InputDecoration(
                            hintText: 'Rechercher produits, services, vendeurs...',
                            hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 14),
                          ),
                          onChanged: _doSearch,
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() { _searchResults.clear(); _searching = false; });
                          },
                          icon: Icon(Icons.close, color: AppColors.textMuted, size: 20),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _searching
                        ? const Center(child: CircularProgressIndicator(color: _skyBlue, strokeWidth: 2))
                        : _searchController.text.length >= 2 && _searchResults.isNotEmpty
                            ? ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: _searchResults.length,
                                itemBuilder: (context, i) {
                                  final item = _searchResults[i];
                                  if (item['type'] == 'user') {
                                    final u = item['data'];
                                    return ListTile(
                                      leading: _buildAvatar(u['avatar_url'] ?? '', u['full_name'] ?? u['username'] ?? '?', 40),
                                      title: Text(u['full_name'] ?? u['username'] ?? '', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                                      subtitle: Text('@${u['username'] ?? ''}', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                      trailing: const Icon(Icons.person, color: _skyBlue, size: 18),
                                      onTap: () { _closeSearch(); context.push('/seller/${u['username']}'); },
                                    );
                                  }
                                  final p = item['data'];
                                  return ListTile(
                                    leading: Container(
                                      width: 44, height: 44,
                                      decoration: BoxDecoration(color: AppColors.bgElevated, borderRadius: BorderRadius.circular(10)),
                                      clipBehavior: Clip.antiAlias,
                                      child: p['poster'] != null || p['images'] != null
                                          ? CachedNetworkImage(
                                              imageUrl: p['poster'] ?? (p['images'] is List && (p['images'] as List).isNotEmpty ? p['images'][0] : ''),
                                              fit: BoxFit.cover,
                                              errorWidget: (_, __, ___) => Icon(Icons.image, color: AppColors.textMuted, size: 20),
                                            )
                                          : Icon(p['type'] == 'service' ? Icons.handyman : Icons.shopping_bag, color: AppColors.textMuted, size: 20),
                                    ),
                                    title: Text(p['title'] ?? '', style: TextStyle(color: AppColors.textPrimary, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    subtitle: Text('${p['price'] ?? 0} FCFA', style: const TextStyle(color: _skyBlue, fontSize: 12, fontWeight: FontWeight.w600)),
                                    onTap: () { _closeSearch(); context.push('/product/${p['slug']}'); },
                                  );
                                },
                              )
                            : _searchController.text.length >= 2 && _searchResults.isEmpty
                                ? Center(
                                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                                      Icon(Icons.search_off, size: 48, color: AppColors.textMuted.withValues(alpha: 0.3)),
                                      const SizedBox(height: 8),
                                      Text('Aucun résultat', style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                                    ]),
                                  )
                                : _suggestions.isNotEmpty
                                    ? ListView(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        children: [
                                          const Padding(
                                            padding: EdgeInsets.only(bottom: 8),
                                            child: Text('Suggestions', style: TextStyle(color: _skyBlue, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                                          ),
                                          ..._suggestions.map((s) => ListTile(
                                            leading: const Icon(Icons.trending_up, color: _skyBlue, size: 18),
                                            title: Text(s is String ? s : s['name'] ?? s.toString(),
                                              style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                                            dense: true,
                                            onTap: () {
                                              final q = s is String ? s : s['name'] ?? s.toString();
                                              _searchController.text = q;
                                              _doSearch(q);
                                            },
                                          )),
                                        ],
                                      )
                                    : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// NOTIFICATION BELL — sky blue
// ═══════════════════════════════════════════════════════════════════════════════
class _NotifBell extends StatelessWidget {
  const _NotifBell();

  @override
  Widget build(BuildContext context) {
    final notif = context.watch<NotificationProvider>();
    final auth = context.watch<AuthProvider>();
    final count = auth.isAuthenticated ? notif.unreadCount : 0;

    return GestureDetector(
      onTap: () {
        if (!auth.isAuthenticated) { context.push('/auth/login'); return; }
        context.push('/notifications');
      },
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: _skyBlue.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(50),
        ),
        child: Stack(
          children: [
            const Center(child: Icon(Icons.notifications_none_rounded, color: _skyBlue, size: 22)),
            if (count > 0)
              Positioned(
                top: 2, right: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)]),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF06060C), width: 1.5),
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 14),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800, height: 1.1),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB BUTTON — sky blue active
// ═══════════════════════════════════════════════════════════════════════════════
class _TabButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabButton({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(
              color: active ? _skyBlueActive : Colors.white60,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              fontSize: 14,
            )),
            const SizedBox(height: 4),
            Container(
              width: 20, height: 3,
              decoration: BoxDecoration(
                color: active ? _skyBlue : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SIDE ACTION — bigger icons (50×50, icon 28)
// ═══════════════════════════════════════════════════════════════════════════════
class _SideAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SideAction({required this.icon, required this.label, this.color = Colors.white, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 30, shadows: const [Shadow(color: Colors.black, blurRadius: 6)]),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600,
            shadows: [Shadow(color: Colors.black, blurRadius: 4)])),
        ],
      ),
    );
  }
}
