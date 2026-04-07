import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart' as share_plus;
import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/user_service.dart';
import '../../services/product_service.dart';
import '../../services/review_service.dart';
import '../../services/follow_service.dart';
import 'package:dio/dio.dart';
import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../widgets/cached_avatar.dart';

class SellerProfileScreen extends StatefulWidget {
  final String username;
  const SellerProfileScreen({super.key, required this.username});
  @override
  State<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends State<SellerProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  Map<String, dynamic>? _profileData;
  dynamic _seller;
  List<Product> _products = [];
  List<dynamic> _reviews = [];
  Map<String, dynamic>? _reviewStats;
  bool _loading = true;
  bool _isFollowing = false;
  bool _isMutual = false;
  bool _followLoading = false;
  int _followersCount = 0;
  int _followingCount = 0;
  // ignore: unused_field
  String _sortBy = 'recent';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadProfile();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final userService = context.read<UserService>();
      final productService = context.read<ProductService>();

      _profileData = await userService.getSellerProfile(widget.username);
      _seller = _profileData?['user'] ?? _profileData?['seller'];

      if (_seller != null) {
        final sellerId = _seller['id']?.toString() ?? '';

        // Load products using the dedicated seller products endpoint
        try {
          final sellerProducts = await userService.getSellerProducts(widget.username);
          _products = sellerProducts.map((p) {
            if (p is Product) return p;
            if (p is Map<String, dynamic>) return Product.fromJson(p);
            return null;
          }).whereType<Product>().toList();
        } catch (e) {
          debugPrint('[SellerProfile] getSellerProducts error: $e');
          // Fallback to feed endpoint
          final result = await productService.getProducts(sellerId: sellerId, perPage: 50);
          _products = result['data'] as List<Product>;
        }

        // Load follow counts + status
        try {
          final followService = context.read<FollowService>();
          final counts = await followService.getFollowCounts(sellerId);
          debugPrint('[SellerProfile] getFollowCounts for $sellerId => $counts');
          _followersCount = counts['followers'] ?? 0;
          _followingCount = counts['following'] ?? 0;
          _isFollowing = counts['is_following'] == true;
          _isMutual = counts['is_mutual'] == true;
        } catch (e) {
          debugPrint('[SellerProfile] getFollowCounts error: $e');
          _followersCount = _seller['followers_count'] ?? 0;
          _followingCount = _seller['following_count'] ?? 0;
        }

        // Load reviews
        try {
          final reviewService = context.read<ReviewService>();
          final res = await reviewService.getSellerReviews(sellerId);
          _reviews = res['reviews']?['data'] ?? res['reviews'] ?? [];
          _reviewStats = res['stats'];
        } catch (_) {}
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggleFollow() async {
    if (_seller == null) return;
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      context.push('/auth/login');
      return;
    }

    final sellerId = _seller['id'].toString();
    setState(() => _followLoading = true);

    try {
      final followService = context.read<FollowService>();
      if (_isFollowing) {
        await followService.unfollow(sellerId);
        setState(() {
          _isFollowing = false;
          _isMutual = false;
          _followersCount = (_followersCount - 1).clamp(0, 999999);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Désabonné avec succès'), duration: Duration(seconds: 2)),
          );
        }
      } else {
        try {
          final result = await followService.follow(sellerId);
          final isMutualNow = result['is_mutual'] == true;
          setState(() {
            _isFollowing = true;
            _isMutual = isMutualNow;
            _followersCount++;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(isMutualNow ? 'Vous êtes maintenant amis !' : 'Abonnement réussi !'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } catch (followErr) {
          // 422 = already following — sync state instead of showing error
          final errStr = followErr.toString();
          if (errStr.contains('422')) {
            debugPrint('[SellerProfile] Already following — syncing state');
            setState(() {
              _isFollowing = true;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Vous êtes déjà abonné'), duration: Duration(seconds: 2)),
              );
            }
          } else {
            rethrow;
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
    if (mounted) setState(() => _followLoading = false);
  }

  Future<void> _startConversation() async {
    if (_seller == null) return;
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      context.push('/auth/login');
      return;
    }

    final sellerId = _seller['id'].toString();
    if (sellerId == auth.user?.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous ne pouvez pas vous contacter vous-même')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Démarrage de la conversation...'), duration: Duration(seconds: 2)),
    );

    try {
      final chat = context.read<ChatProvider>();
      final convId = await chat.startConversation(
        sellerId: sellerId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        if (convId != null) {
          context.push('/messages/$convId');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossible de démarrer la conversation'), backgroundColor: AppColors.danger),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  void _openFollowers() {
    if (_seller == null) return;
    final sellerId = _seller['id']?.toString() ?? '';
    final name = _seller['full_name'] ?? _seller['username'] ?? 'Vendeur';
    context.push('/followers/$sellerId?name=$name&tab=followers');
  }

  void _openFollowing() {
    if (_seller == null) return;
    final sellerId = _seller['id']?.toString() ?? '';
    final name = _seller['full_name'] ?? _seller['username'] ?? 'Vendeur';
    context.push('/followers/$sellerId?name=$name&tab=following');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    if (_seller == null) {
      return Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(backgroundColor: AppColors.bgSecondary),
        body: Center(child: Text('Profil introuvable', style: TextStyle(color: AppColors.textPrimary))),
      );
    }

    final s = _seller!;
    final name = s['full_name'] ?? s['name'] ?? 'Vendeur';
    final username = s['username'] ?? '';
    final avatarUrl = s['avatar_url'] ?? s['avatar'] ?? '';
    final coverUrl = s['cover_url'] ?? '';
    final city = s['city'] ?? '';
    final trust = ((s['trust_score'] ?? 0) * 100).toInt();
    final productsCount = s['products_count'] ?? _products.length;
    final bio = s['bio'] ?? '';
    final memberSince = s['created_at']?.toString().substring(0, 10) ?? '';

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.bgSecondary,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                  child: const Icon(Icons.share, color: Colors.white, size: 18),
                ),
                onPressed: () => share_plus.Share.share('Découvrez le profil de $name sur QUINCH !'),
              ),
              // Report user button (hidden for own profile)
              if (context.read<AuthProvider>().user?.id != s['id']?.toString())
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                    child: const Icon(Icons.flag_outlined, color: Colors.white, size: 18),
                  ),
                  onPressed: () => _showReportUserSheet(s),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(fit: StackFit.expand, children: [
                if (coverUrl.isNotEmpty)
                  CachedNetworkImage(imageUrl: ApiConfig.resolveUrl(coverUrl), fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(color: const Color(0xFF1A1F35)))
                else
                  Container(decoration: const BoxDecoration(gradient: LinearGradient(
                    colors: [Color(0xFF1A1F35), Color(0xFF2A2F55), Color(0xFF1A1F35)]))),
                Container(decoration: BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, AppColors.bgPrimary.withValues(alpha: 0.8)]))),
              ]),
            ),
          ),

          // Profile info
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(children: [
              const SizedBox(height: 12),
              // Avatar + name
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.accent, width: 3),
                  ),
                  child: CachedAvatar(
                    url: avatarUrl.isNotEmpty ? ApiConfig.resolveUrl(avatarUrl) : null,
                    size: 80, name: name,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(child: Text(name, style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700))),
                    if (trust >= 70) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.verified, color: AppColors.accent, size: 20),
                    ],
                  ]),
                  Text('@$username', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  if (city.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.location_on, size: 13, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Text(city, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ]),
                  ],
                  if (_isMutual) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.people, size: 12, color: AppColors.success),
                        SizedBox(width: 4),
                        Text('Ami(e)', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ],
                ])),
              ]),
              if (bio.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(bio, style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
              ],
              const SizedBox(height: 16),

              // Stats row — clickable followers/following
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border)),
                child: Row(children: [
                  _StatWidget(label: 'Produits', value: '$productsCount'),
                  _divider(),
                  _StatWidget(label: 'Abonnés', value: '$_followersCount', onTap: _openFollowers),
                  _divider(),
                  _StatWidget(label: 'Abonnements', value: '$_followingCount', onTap: _openFollowing),
                  _divider(),
                  _StatWidget(label: 'Confiance', value: '$trust%',
                    valueColor: trust >= 80 ? AppColors.success : trust >= 50 ? AppColors.warning : AppColors.danger),
                ]),
              ),
              const SizedBox(height: 12),

              // Action buttons
              Row(children: [
                Expanded(child: SizedBox(height: 42,
                  child: _isFollowing
                      ? OutlinedButton.icon(
                          onPressed: _followLoading ? null : _toggleFollow,
                          icon: _followLoading
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.danger))
                              : const Icon(Icons.person_remove, size: 16, color: AppColors.danger),
                          label: Text(
                            'Se désabonner',
                            style: TextStyle(fontSize: 13, color: _followLoading ? AppColors.textMuted : AppColors.danger),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: BorderSide(color: AppColors.danger.withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: _followLoading ? null : _toggleFollow,
                          icon: _followLoading
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.person_add, size: 16, color: Colors.white),
                          label: const Text('Suivre', style: TextStyle(color: Colors.white, fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                )),
                const SizedBox(width: 8),
                SizedBox(height: 42,
                  child: OutlinedButton.icon(
                    onPressed: _startConversation,
                    icon: const Icon(Icons.chat_bubble_outline, size: 16),
                    label: const Text('Message', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 16),

              // Tab bar
              TabBar(
                controller: _tabCtrl,
                labelColor: AppColors.accent,
                unselectedLabelColor: AppColors.textMuted,
                indicatorColor: AppColors.accent,
                indicatorSize: TabBarIndicatorSize.label,
                tabs: [
                  Tab(text: 'Produits (${_products.length})'),
                  Tab(text: 'Avis (${_reviews.length})'),
                  const Tab(text: 'À propos'),
                ],
              ),
            ]),
          )),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _buildProductsTab(),
            _buildReviewsTab(),
            _buildAboutTab(s, memberSince, trust),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsTab() {
    if (_products.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.inventory_2, color: AppColors.textMuted, size: 40),
        SizedBox(height: 8),
        Text('Aucun produit', style: TextStyle(color: AppColors.textMuted)),
      ]));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, childAspectRatio: 0.75, crossAxisSpacing: 10, mainAxisSpacing: 10),
      itemCount: _products.length,
      itemBuilder: (_, i) {
        final p = _products[i];
        return GestureDetector(
          onTap: () => context.push('/product/${p.slug}'),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.bgCard, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              Expanded(
                child: p.mediaUrl.isNotEmpty
                    ? CachedNetworkImage(imageUrl: p.mediaUrl, fit: BoxFit.cover, width: double.infinity)
                    : Container(color: AppColors.bgInput, child: Icon(Icons.image, color: AppColors.textMuted)),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(p.displayPrice, style: const TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w700)),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildReviewsTab() {
    final avg = (_reviewStats?['average'] ?? 0).toDouble();
    final total = _reviewStats?['total'] ?? 0;

    return ListView(padding: const EdgeInsets.all(16), children: [
      if (total > 0) Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          Column(children: [
            Text(avg.toStringAsFixed(1), style: TextStyle(color: AppColors.textPrimary, fontSize: 30, fontWeight: FontWeight.w800)),
            Row(children: List.generate(5, (i) => Icon(i < avg.round() ? Icons.star : Icons.star_border, color: const Color(0xFFFBBF24), size: 14))),
            Text('$total avis', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ]),
          const SizedBox(width: 20),
          Expanded(child: Column(children: [
            for (int star = 5; star >= 1; star--)
              Padding(padding: const EdgeInsets.symmetric(vertical: 1), child: Row(children: [
                Text('$star', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                const Icon(Icons.star, color: Color(0xFFFBBF24), size: 10),
                const SizedBox(width: 4),
                Expanded(child: LinearProgressIndicator(
                  value: total > 0 ? ((_reviewStats?['distribution']?[star.toString()] ?? _reviewStats?['distribution']?[star] ?? 0) / total) : 0,
                  backgroundColor: AppColors.bgInput, color: Color(0xFFFBBF24), minHeight: 5,
                  borderRadius: BorderRadius.circular(3),
                )),
              ])),
          ])),
        ]),
      ),
      const SizedBox(height: 16),

      if (_reviews.isEmpty)
        Center(child: Padding(padding: EdgeInsets.all(30), child: Text('Aucun avis pour le moment', style: TextStyle(color: AppColors.textMuted))))
      else
        ..._reviews.map((r) => Container(
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
            ]),
            if (r['comment'] != null && r['comment'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(r['comment'], style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
            ],
          ]),
        )),
    ]);
  }

  Widget _buildAboutTab(dynamic s, String memberSince, int trust) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      _aboutItem(Icons.calendar_today, 'Membre depuis', memberSince.isNotEmpty ? memberSince : 'N/A'),
      _aboutItem(Icons.location_on, 'Localisation', '${s['city'] ?? 'N/A'}, ${s['region'] ?? ''}'),
      _aboutItem(Icons.verified_user, 'KYC', s['kyc_status'] ?? 'Non vérifié'),
      _aboutItem(Icons.shield, 'Confiance', '$trust%'),
      _aboutItem(Icons.inventory, 'Produits actifs', '${_products.length}'),
    ]);
  }

  Widget _aboutItem(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Icon(icon, color: AppColors.textMuted, size: 20),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const Spacer(),
        Text(value, style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _divider() => Container(width: 1, height: 30, color: AppColors.border);

  // ═══════════════════════════════════════════════════════════════
  // REPORT USER
  // ═══════════════════════════════════════════════════════════════
  void _showReportUserSheet(dynamic seller) {
    String selectedReason = 'spam';
    final descCtrl = TextEditingController();
    final reasons = {
      'harassment': 'Harcèlement',
      'spam': 'Spam',
      'inappropriate_content': 'Contenu inapproprié',
      'fraud': 'Fraude / Arnaque',
      'impersonation': 'Usurpation d\'identité',
      'other': 'Autre',
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text('Signaler cet utilisateur', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Pourquoi souhaitez-vous signaler ce profil ?', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedReason,
                dropdownColor: AppColors.bgCard,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  filled: true, fillColor: AppColors.bgInput,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                items: reasons.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                onChanged: (v) => setSheetState(() => selectedReason = v ?? 'spam'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Décrivez le problème (optionnel)...',
                  hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  filled: true, fillColor: AppColors.bgInput,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => _submitUserReport(seller, selectedReason, descCtrl.text),
                  icon: const Icon(Icons.flag, color: Colors.white, size: 18),
                  label: const Text('Envoyer le signalement', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ]),
          );
        });
      },
    );
  }

  Future<void> _submitUserReport(dynamic seller, String reason, String description) async {
    Navigator.pop(context); // close bottom sheet
    final sellerId = seller['id']?.toString() ?? '';
    try {
      final userService = context.read<UserService>();
      await userService.reportUser(userId: sellerId, reason: reason, description: description);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signalement envoyé. Merci !'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      String msg = 'Erreur lors du signalement.';
      if (e is DioException && e.response?.statusCode == 409) {
        msg = 'Vous avez déjà signalé cet utilisateur.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.danger),
        );
      }
    }
  }
}

class _StatWidget extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final VoidCallback? onTap;
  const _StatWidget({required this.label, required this.value, this.valueColor, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(children: [
          Text(value, style: TextStyle(color: valueColor ?? AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          Text(label, style: TextStyle(color: onTap != null ? AppColors.accent : AppColors.textMuted, fontSize: 10)),
        ]),
      ),
    );
  }
}
