import 'product.dart';

class CartItem {
  final String id;
  final String productId;
  final int quantity;
  final double priceAtAdd;
  final Product? product;

  CartItem({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.priceAtAdd,
    this.product,
  });

  double get total => priceAtAdd * quantity;
  String get formattedPrice => '${priceAtAdd.toStringAsFixed(0)} F CFA';

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      quantity: json['quantity'] ?? 1,
      priceAtAdd: (json['price_at_add'] ?? 0).toDouble(),
      product:
          json['product'] != null ? Product.fromJson(json['product']) : null,
    );
  }
}
