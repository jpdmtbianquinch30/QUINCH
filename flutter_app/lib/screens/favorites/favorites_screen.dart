import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/favorite_provider.dart';
import '../../providers/cart_provider.dart';
import '../../config/theme.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  String _tab = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final fav = context.read<FavoriteProvider>();
      fav.loadFavorites();
      fav.loadCollections();
    });
  }

  void _showMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 13)),
      backgroundColor: const Color(0xFF1E293B),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final fav = context.watch<FavoriteProvider>();

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgSecondary,
        title: Row(children: [
          const Icon(Icons.star, color: AppColors.saved, size: 22),
          const SizedBox(width: 8),
          const Text('Mes Favoris', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
        ]),
      ),
      body: Column(children: [
        // Tabs
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(child: _TabBtn(
              label: 'Tous les favoris', active: _tab == 'all',
              onTap: () => setState(() => _tab = 'all'),
            )),
            const SizedBox(width: 8),
            Expanded(child: _TabBtn(
              label: 'Collections', active: _tab == 'collections',
              onTap: () => setState(() => _tab = 'collections'),
            )),
          ]),
        ),

        // Content
        Expanded(
          child: fav.isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
              : _tab == 'all' ? _buildFavorites(fav) : _buildCollections(fav),
        ),
      ]),
    );
  }

  Widget _buildFavorites(FavoriteProvider fav) {
    if (fav.favorites.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 80, height: 80,
          decoration: BoxDecoration(color: AppColors.warningSubtle, borderRadius: BorderRadius.circular(20)),
          child: Icon(Icons.star_border, size: 36, color: AppColors.saved)),
        const SizedBox(height: 20),
        Text('Aucun favori', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('Ajoutez des produits à vos favoris pour les retrouver facilement !',
            textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => context.go('/marketplace'),
          icon: const Icon(Icons.explore, size: 18),
          label: const Text('Explorer les produits'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
      ]));
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, childAspectRatio: 0.62,
        crossAxisSpacing: 10, mainAxisSpacing: 10,
      ),
      itemCount: fav.favorites.length,
      itemBuilder: (_, i) {
        final favItem = fav.favorites[i];
        final product = favItem.product;
        if (product == null) return const SizedBox();

        return Container(
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            // Media
            Expanded(
              child: Stack(fit: StackFit.expand, children: [
                GestureDetector(
                  onTap: () => context.push('/product/${product.slug}'),
                  child: product.mediaUrl.isNotEmpty
                      ? CachedNetworkImage(imageUrl: product.mediaUrl, fit: BoxFit.cover)
                      : Container(color: AppColors.bgInput, child: Icon(Icons.image, color: AppColors.textMuted)),
                ),
                // Remove button
                Positioned(top: 8, right: 8,
                  child: GestureDetector(
                    onTap: () {
                      fav.toggleFavorite(product.id);
                      _showMsg('Retiré des favoris.');
                    },
                    child: Container(width: 30, height: 30,
                      decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                      child: const Icon(Icons.close, color: Colors.white, size: 16)),
                  )),
                // Price drop badge
                if (favItem.priceAtSave != null && product.price < favItem.priceAtSave!)
                  Positioned(top: 8, left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(6)),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.trending_down, color: Colors.white, size: 10),
                        SizedBox(width: 2),
                        Text('Prix en baisse!', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
              ]),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                GestureDetector(
                  onTap: () => context.push('/product/${product.slug}'),
                  child: Text(product.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                ),
                const SizedBox(height: 4),
                Text(product.displayPrice, style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity, height: 34,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      context.read<CartProvider>().addToCart(product.id, quantity: 1);
                      _showMsg('Ajouté au panier !');
                    },
                    icon: const Icon(Icons.shopping_cart, size: 14, color: Colors.white),
                    label: const Text('Ajouter au panier', style: TextStyle(fontSize: 11, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        );
      },
    );
  }

  Widget _buildCollections(FavoriteProvider fav) {
    if (fav.collections.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.collections_bookmark, color: AppColors.textMuted, size: 48),
        const SizedBox(height: 16),
        Text('Aucune collection', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('Organisez vos favoris en collections personnalisées',
            textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      ]));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: fav.collections.length,
      itemBuilder: (_, i) {
        final col = fav.collections[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(color: AppColors.accentSubtle, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.folder, color: AppColors.accent, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(col.name, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
              Text('${col.itemsCount} produit${col.itemsCount > 1 ? 's' : ''}',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ])),
            if (col.isPublic)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.accentSubtle, borderRadius: BorderRadius.circular(8)),
                child: const Text('Public', style: TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
          ]),
        );
      },
    );
  }
}

class _TabBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabBtn({required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.accent.withValues(alpha: 0.15) : AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? AppColors.accent : AppColors.border),
        ),
        child: Text(label, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? AppColors.accent : AppColors.textSecondary)),
      ),
    );
  }
}
