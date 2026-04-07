import 'product.dart';

class FavoriteItem {
  final String id;
  final String productId;
  final String? collectionId;
  final Product? product;
  final double? priceAtSave;
  final String createdAt;

  FavoriteItem({
    required this.id,
    required this.productId,
    this.collectionId,
    this.product,
    this.priceAtSave,
    required this.createdAt,
  });

  factory FavoriteItem.fromJson(Map<String, dynamic> json) {
    return FavoriteItem(
      id: json['id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      collectionId: json['collection_id']?.toString(),
      product: json['product'] != null ? Product.fromJson(json['product']) : null,
      priceAtSave: json['price_at_save'] != null ? (json['price_at_save'] as num).toDouble() : null,
      createdAt: json['created_at'] ?? '',
    );
  }
}

class FavoriteCollection {
  final String id;
  final String name;
  final int itemsCount;
  final bool isPublic;

  FavoriteCollection({
    required this.id,
    required this.name,
    this.itemsCount = 0,
    this.isPublic = false,
  });

  factory FavoriteCollection.fromJson(Map<String, dynamic> json) {
    return FavoriteCollection(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      itemsCount: json['items_count'] ?? json['count'] ?? 0,
      isPublic: json['is_public'] ?? false,
    );
  }
}
