import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/cart_item.dart';
import '../../providers/cart_provider.dart';
import '../../config/theme.dart';


class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CartProvider>().loadCart();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgSecondary,
        title: Row(children: [
          const Text('Panier', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
          if (cart.items.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.accentSubtle, borderRadius: BorderRadius.circular(10)),
              child: Text('${cart.items.length}', style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ]),
        actions: [
          if (cart.items.isNotEmpty)
            TextButton(onPressed: () => _showClearDialog(context),
              child: const Text('Vider', style: TextStyle(color: AppColors.danger, fontSize: 13))),
        ],
      ),
      body: cart.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : cart.items.isEmpty
              ? _EmptyCart()
              : Column(
                  children: [
                    // Items
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: cart.items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _CartItemCard(item: cart.items[i]),
                      ),
                    ),

                    // Summary
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.bgSecondary,
                        border: Border(top: BorderSide(color: AppColors.border)),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Column(
                          children: [
                            _SummaryRow('Sous-total', cart.formattedSubtotal),
                            const SizedBox(height: 6),
                            _SummaryRow(
                              'Livraison',
                              cart.deliveryTotal > 0
                                  ? '${cart.deliveryTotal.toStringAsFixed(0)} F CFA'
                                  : 'Gratuite',
                              valueColor: cart.deliveryTotal > 0 ? AppColors.warning : AppColors.success,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Divider(color: AppColors.border),
                            ),
                            _SummaryRow('Total', cart.formattedTotal, isBold: true, valueColor: AppColors.accentLight),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity, height: 50,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 4))],
                                ),
                                child: ElevatedButton.icon(
                                  onPressed: () => context.push('/checkout'),
                                  icon: const Icon(Icons.lock, size: 18, color: Colors.white),
                                  label: const Text('Passer la commande', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.white)),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
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

  void _showClearDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Vider le panier ?'),
        content: const Text('Tous les articles seront supprimés.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          TextButton(onPressed: () { Navigator.pop(context); context.read<CartProvider>().clearCart(); },
            child: const Text('Vider', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final CartItem item;
  const _CartItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: item.product != null && item.product!.mediaUrl.isNotEmpty
                ? CachedNetworkImage(imageUrl: item.product!.mediaUrl, width: 80, height: 80, fit: BoxFit.cover)
                : Container(width: 80, height: 80, color: AppColors.bgElevated,
                    child: Icon(Icons.shopping_bag, color: AppColors.textMuted)),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.product?.title ?? 'Produit', maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(item.formattedPrice,
                  style: const TextStyle(color: AppColors.accentLight, fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                // Delivery fee per item
                Row(children: [
                  Icon(Icons.local_shipping, size: 13, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  if (item.product?.deliveryFee != null && item.product!.deliveryFee! > 0)
                    Text('+${item.product!.deliveryFee!.toStringAsFixed(0)} F livraison',
                      style: TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.w500))
                  else if (item.product?.deliveryOption == 'free')
                    Text('Livraison gratuite',
                      style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w500))
                  else
                    Text('Livraison à convenir',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ]),
                const SizedBox(height: 6),
                // Quantity control
                Row(children: [
                  _QtyBtn(icon: Icons.remove, onTap: () {
                    if (item.quantity > 1) cart.updateQuantity(item.id, item.quantity - 1);
                    else cart.removeItem(item.id);
                  }),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('${item.quantity}', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                  _QtyBtn(icon: Icons.add, onTap: () => cart.updateQuantity(item.id, item.quantity + 1)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                    onPressed: () => cart.removeItem(item.id)),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 16, color: AppColors.textPrimary),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? valueColor;
  const _SummaryRow(this.label, this.value, {this.isBold = false, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: isBold ? 15 : 13, fontWeight: isBold ? FontWeight.w600 : FontWeight.w400)),
      Text(value, style: TextStyle(color: valueColor ?? AppColors.textPrimary, fontSize: isBold ? 17 : 14, fontWeight: isBold ? FontWeight.w700 : FontWeight.w500)),
    ]);
  }
}

class _EmptyCart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: AppColors.accentSubtle, borderRadius: BorderRadius.circular(20)),
            child: Icon(Icons.shopping_cart_outlined, size: 36, color: AppColors.accent),
          ),
          const SizedBox(height: 20),
          Text('Votre panier est vide', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Découvrez nos produits et commencez vos achats', textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 24),
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () => context.go('/marketplace'),
              icon: const Icon(Icons.explore, size: 18),
              label: const Text('Explorer'),
            ),
          ),
        ]),
      ),
    );
  }
}
