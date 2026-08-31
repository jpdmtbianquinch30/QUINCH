import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/product.dart';
import '../../services/product_service.dart';
import '../../config/api_config.dart';
import '../../config/theme.dart';

/// ═══════════════════════════════════════════════════════════════
/// ÉCRAN DE RECHERCHE
/// ───────────────────────────────────────────────────────────────
/// Le backend (/search) renvoie déjà produits ET vendeurs — voir
/// ProductFeedController::search(). Cet écran suppose que
/// ProductService expose une méthode :
///
///   Future\<Map\<String, dynamic\>\> search(String query)
///   -> { 'products': List\<Product\>, 'sellers': List\<dynamic\> }
///
/// ADAPTE ICI si la signature réelle diffère dans ton
/// product_service.dart (nom de méthode, forme du retour, champs
/// des vendeurs). Le reste de l'écran (debounce, UI, navigation)
/// n'a pas besoin de changer.
/// ═══════════════════════════════════════════════════════════════

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;

  bool _loading = false;
  bool _searched = false;
  List<Product> _products = [];
  List<dynamic> _sellers = [];
  List<String> _trending = [];

  // Recherches récentes — en mémoire pour la session (persiste tant que
  // l'app tourne). Pour survivre à un redémarrage complet, il faudrait
  // les sauvegarder via shared_preferences côté app.
  static final List<String> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
    _loadTrending();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadTrending() async {
    try {
      final ps = context.read<ProductService>();
      // ADAPTE : méthode de suggestions/tendances si le nom diffère.
      final trending = await ps.getTrending();
      if (mounted) {
        setState(() => _trending = List<String>.from(trending));
      }
    } catch (_) {
      // pas bloquant : l'écran fonctionne sans suggestions
    }
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searched = false;
        _products = [];
        _sellers = [];
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _runSearch(query.trim()));
  }

  Future<void> _runSearch(String query) async {
    setState(() {
      _loading = true;
      _searched = true;
    });
    try {
      final ps = context.read<ProductService>();
      final result = await ps.search(query);
      // Parsing défensif : selon ce que renvoie le backend, les éléments
      // de 'products' peuvent déjà être des `Product` (si le service les
      // parse en interne) ou du JSON brut (Map<String, dynamic>). Le
      // cast direct `.cast<Product>()` plantait dans ce 2e cas — on gère
      // les deux pour de bon.
      final rawProducts = (result['products'] as List?) ?? const [];
      final products = rawProducts.map((e) {
        if (e is Product) return e;
        return Product.fromJson(Map<String, dynamic>.from(e as Map));
      }).toList();
      final sellers = (result['sellers'] as List?) ?? (result['users'] as List?) ?? [];
      if (mounted) {
        setState(() {
          _products = products;
          _sellers = sellers;
          _loading = false;
        });
      }
      _saveRecentSearch(query);
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _saveRecentSearch(String query) {
    if (query.trim().isEmpty) return;
    _recentSearches.remove(query); // évite les doublons, remonte en tête
    _recentSearches.insert(0, query);
    if (_recentSearches.length > 8) _recentSearches.removeLast();
  }

  void _removeRecentSearch(String query) {
    setState(() => _recentSearches.remove(query));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.arrow_back, color: AppColors.textSecondary),
          ),
          Expanded(
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.bgInput,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: AppColors.textMuted, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      onChanged: _onQueryChanged,
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Produit, service, vendeur…',
                        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  if (_controller.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _controller.clear();
                        _onQueryChanged('');
                      },
                      child: Icon(Icons.close, color: AppColors.textMuted, size: 16),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_searched) {
      if (_trending.isEmpty && _recentSearches.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recherches récentes — vides tant qu'aucune recherche n'a
            // été faite pendant cette session.
            if (_recentSearches.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recherches récentes',
                      style: TextStyle(
                          color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                  GestureDetector(
                    onTap: () => setState(() => _recentSearches.clear()),
                    child: Text('Effacer',
                        style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ..._recentSearches.map((q) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: GestureDetector(
                  onTap: () {
                    _controller.text = q;
                    _runSearch(q);
                  },
                  child: Row(
                    children: [
                      Icon(Icons.history, color: AppColors.textMuted, size: 17),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(q,
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
                      ),
                      GestureDetector(
                        onTap: () => _removeRecentSearch(q),
                        child: Icon(Icons.close, color: AppColors.textMuted, size: 15),
                      ),
                    ],
                  ),
                ),
              )),
              const SizedBox(height: 18),
            ],

            if (_trending.isNotEmpty) ...[
              Text('Tendances',
                  style: TextStyle(
                      color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _trending.map((t) {
                  return GestureDetector(
                    onTap: () {
                      _controller.text = t;
                      _runSearch(t);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(t,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      );
    }

    if (_products.isEmpty && _sellers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text('Aucun résultat',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        if (_sellers.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Vendeurs',
                style: TextStyle(
                    color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
          ),
          ..._sellers.map((s) => _buildSellerTile(s)),
        ],
        if (_products.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Annonces',
                style: TextStyle(
                    color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
          ),
          ..._products.map((p) => _buildProductTile(p)),
        ],
      ],
    );
  }

  Widget _buildSellerTile(dynamic seller) {
    final name = (seller['full_name'] ?? seller['name'] ?? 'Vendeur') as String;
    final username = (seller['username'] ?? '') as String;
    final avatarRaw = (seller['avatar_url'] ?? '') as String;
    final avatar = avatarRaw.isNotEmpty ? ApiConfig.resolveUrl(avatarRaw) : '';

    return ListTile(
      onTap: () {
        if (username.isNotEmpty) context.push('/seller/$username');
      },
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: AppColors.accentSubtle,
        backgroundImage: avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null,
        child: avatar.isEmpty
            ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'V',
            style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700))
            : null,
      ),
      title: Text(name, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
      subtitle: username.isNotEmpty
          ? Text('@$username', style: TextStyle(color: AppColors.textMuted, fontSize: 12))
          : null,
    );
  }

  Widget _buildProductTile(Product product) {
    return ListTile(
      onTap: () => context.push('/product/${product.slug}'),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 48,
          height: 48,
          child: product.mediaUrl.isNotEmpty
              ? CachedNetworkImage(imageUrl: product.mediaUrl, fit: BoxFit.cover)
              : Container(
            color: AppColors.bgElevated,
            child: Icon(
              product.isService ? Icons.build : Icons.shopping_bag,
              color: AppColors.textMuted,
              size: 20,
            ),
          ),
        ),
      ),
      title: Text(product.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13.5)),
      subtitle: Text(product.displayPrice,
          style: TextStyle(
              color: product.isService ? AppColors.secondary : AppColors.accent,
              fontWeight: FontWeight.w700,
              fontSize: 12.5)),
    );
  }
}