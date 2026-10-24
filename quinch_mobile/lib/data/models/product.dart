import '../../core/json/json_utils.dart';

class ProductVideo {
  const ProductVideo({
    required this.id,
    this.streamPath,
    this.thumbnailPath,
    this.durationSeconds,
    this.format,
  });

  final String id;

  /// Chemin RELATIF au serveur (`/api/v1/videos/{id}/stream`), à résoudre avec MediaUrl.
  /// Le flux accepte les requêtes Range et est public.
  final String? streamPath;
  final String? thumbnailPath;
  final int? durationSeconds;
  final String? format;

  /// Feed / Explorer : `url`, `thumbnail`, `duration`. Modèle brut (détail,
  /// mes annonces) : `video_url`, `thumbnail_url`, `duration_seconds`.
  factory ProductVideo.fromJson(Json j) => ProductVideo(
    id: asString(j['id']),
    streamPath: asStringOrNull(j['url'] ?? j['video_url']),
    thumbnailPath: asStringOrNull(j['thumbnail'] ?? j['thumbnail_url']),
    durationSeconds: j['duration'] != null || j['duration_seconds'] != null
        ? asInt(j['duration'] ?? j['duration_seconds'])
        : null,
    format: asStringOrNull(j['format']),
  );
}

class SellerBrief {
  const SellerBrief({
    required this.id,
    required this.fullName,
    this.username,
    this.avatarUrl,
    this.city,
    this.trustScore = 0,
    this.isPremium = false,
    this.isFollowing = false,
    this.reviewCount = 0,
    this.productsCount,
    this.isOnline,
    this.memberSince,
    this.badges = const [],
  });

  final String id;
  final String fullName;
  final String? username;
  final String? avatarUrl;
  final String? city;
  final int trustScore;
  final bool isPremium;
  final bool isFollowing;
  final int reviewCount;
  final int? productsCount;
  final bool? isOnline;
  final String? memberSince;
  final List<Json> badges;

  factory SellerBrief.fromJson(Json j) => SellerBrief(
    id: asString(j['id']),
    fullName: asString(j['full_name'] ?? j['name']),
    username: asStringOrNull(j['username']),
    avatarUrl: asStringOrNull(j['avatar_url'] ?? j['avatar']),
    city: asStringOrNull(j['city']),
    trustScore: asInt(j['trust_score']),
    isPremium: asBool(j['is_premium']),
    isFollowing: asBool(j['is_following']),
    reviewCount: asInt(j['review_count']),
    productsCount: j['products_count'] == null
        ? null
        : asInt(j['products_count']),
    isOnline: j['is_online'] == null ? null : asBool(j['is_online']),
    memberSince: asStringOrNull(j['member_since']),
    badges: asMapList(j['badges']),
  );
}

/// Annonce telle que renvoyée par le feed, l'Explorer, les favoris, mes annonces
/// ou le détail. Les formes diffèrent (vérifié) :
/// - `category` : objet {id,name,icon} (feed, détail) ou texte (Explorer) ;
/// - vendeur : `seller` (feed, Explorer) ou `user` (modèles bruts) ;
/// - `poster` (feed, Explorer) ou `poster_full_url` (modèle brut) ;
/// - `description` tronquée à 120 caractères dans le feed uniquement.
/// Le prix est celui du serveur : l'application ne le recalcule jamais.
class ProductCard {
  const ProductCard({
    required this.id,
    required this.slug,
    required this.title,
    required this.price,
    this.description = '',
    this.type = 'product',
    this.currency,
    this.condition,
    this.isNegotiable = false,
    this.status,
    this.posterUrl,
    this.thumbnailUrl,
    this.imageUrls = const [],
    this.video,
    this.categoryId,
    this.categoryName,
    this.seller,
    this.likeCount = 0,
    this.viewCount = 0,
    this.shareCount = 0,
    this.saveCount = 0,
    this.isLiked = false,
    this.isSaved = false,
    this.stockQuantity,
    this.paymentMethods = const [],
    this.deliveryOption,
    this.deliveryFee,
    this.metadata = const {},
    this.createdAt,
  });

  final String id;
  final String slug;
  final String title;
  final String description;
  final String type; // product | service
  final double price;
  final String? currency;
  final String? condition; // new | like_new | good | fair
  final bool isNegotiable;
  final String? status;
  final String? posterUrl;
  final String? thumbnailUrl;
  final List<String> imageUrls;
  final ProductVideo? video;
  final String? categoryId;
  final String? categoryName;
  final SellerBrief? seller;
  final int likeCount;
  final int viewCount;
  final int shareCount;
  final int saveCount;
  final bool isLiked;
  final bool isSaved;
  final int? stockQuantity;
  final List<String> paymentMethods;
  final String? deliveryOption;
  final int? deliveryFee;
  final Json metadata;
  final DateTime? createdAt;

  /// Meilleure image de couverture connue, sans rien inventer.
  String? get coverImage =>
      posterUrl ??
      thumbnailUrl ??
      (imageUrls.isNotEmpty ? imageUrls.first : null);

  factory ProductCard.fromJson(
    Json j, {
    SellerBrief? seller,
    bool? isLiked,
    bool? isSaved,
  }) {
    final categoryRaw = j['category'];
    final categoryMap = categoryRaw is Map ? Json.from(categoryRaw) : null;
    final sellerMap = asMapOrNull(j['seller'] ?? j['user']);
    final videoMap = asMapOrNull(j['video']);
    return ProductCard(
      id: asString(j['id']),
      slug: asString(j['slug']),
      title: asString(j['title']),
      description: asString(j['description']),
      type: asString(j['type'], 'product'),
      price: asDouble(j['price']),
      currency: asStringOrNull(j['currency']),
      condition: asStringOrNull(j['condition']),
      isNegotiable: asBool(j['is_negotiable']),
      status: asStringOrNull(j['status']),
      posterUrl: asStringOrNull(j['poster'] ?? j['poster_full_url']),
      thumbnailUrl: asStringOrNull(j['thumbnail'] ?? j['image']),
      imageUrls: asStringList(j['images']),
      video: videoMap == null ? null : ProductVideo.fromJson(videoMap),
      categoryId: asStringOrNull(j['category_id'] ?? categoryMap?['id']),
      categoryName: categoryMap != null
          ? asStringOrNull(categoryMap['name'])
          : (categoryRaw is String ? categoryRaw : null),
      seller:
          seller ??
          (sellerMap == null ? null : SellerBrief.fromJson(sellerMap)),
      likeCount: asInt(j['like_count']),
      viewCount: asInt(j['view_count']),
      shareCount: asInt(j['share_count']),
      saveCount: asInt(j['save_count']),
      isLiked: isLiked ?? asBool(j['is_liked']),
      isSaved: isSaved ?? asBool(j['is_saved']),
      stockQuantity: j['stock_quantity'] == null
          ? null
          : asInt(j['stock_quantity']),
      paymentMethods: asStringList(j['payment_methods']),
      deliveryOption: asStringOrNull(j['delivery_option']),
      deliveryFee: j['delivery_fee'] == null ? null : asInt(j['delivery_fee']),
      metadata: asMap(j['metadata']),
      createdAt: asDate(j['created_at']),
    );
  }
}

/// `GET products/{slug}` : `{product, seller, is_liked, is_saved}`.
class ProductDetail {
  const ProductDetail({required this.product, required this.seller});

  final ProductCard product;
  final SellerBrief seller;

  factory ProductDetail.fromJson(Object? body) {
    final m = asMap(body);
    final seller = SellerBrief.fromJson(asMap(m['seller']));
    return ProductDetail(
      product: ProductCard.fromJson(
        asMap(m['product']),
        seller: seller,
        isLiked: asBool(m['is_liked']),
        isSaved: asBool(m['is_saved']),
      ),
      seller: seller,
    );
  }
}

class Category {
  const Category({
    required this.id,
    required this.name,
    this.icon,
    this.children = const [],
  });

  final String id;
  final String name;
  final String? icon;
  final List<Category> children;

  factory Category.fromJson(Json j) => Category(
    id: asString(j['id']),
    name: asString(j['name']),
    icon: asStringOrNull(j['icon']),
    children: asMapList(j['children']).map(Category.fromJson).toList(),
  );
}

/// Résultat de `POST products` et `POST products/{id}/publish`.
/// `paymentUrl` n'est présent que si des frais de publication sont dus ; dans ce
/// cas l'annonce reste en brouillon tant que le webhook serveur n'a pas confirmé.
class ProductSaveResult {
  const ProductSaveResult({
    required this.product,
    this.message,
    this.paymentUrl,
    this.fee,
  });

  final ProductCard product;
  final String? message;
  final String? paymentUrl;
  final int? fee;

  factory ProductSaveResult.fromJson(Object? body) {
    final m = asMap(body);
    return ProductSaveResult(
      product: ProductCard.fromJson(asMap(m['product'])),
      message: asStringOrNull(m['message']),
      paymentUrl: asStringOrNull(m['payment_url']),
      fee: m['fee'] == null ? null : asInt(m['fee']),
    );
  }
}

/// Résultat de recherche : produit (forme réduite, vérifiée dans le backend).
/// Attention : `seller` est ici le NOM D'UTILISATEUR (texte), pas un objet.
class SearchProductHit {
  const SearchProductHit({
    required this.id,
    required this.slug,
    required this.title,
    required this.price,
    this.type = 'product',
    this.posterUrl,
    this.imageUrl,
    this.sellerUsername,
    this.sellerId,
    this.sellerIsPremium = false,
  });

  final String id;
  final String slug;
  final String title;
  final double price;
  final String type;
  final String? posterUrl;
  final String? imageUrl;
  final String? sellerUsername;
  final String? sellerId;
  final bool sellerIsPremium;

  String? get coverImage => posterUrl ?? imageUrl;

  factory SearchProductHit.fromJson(Json j) => SearchProductHit(
    id: asString(j['id']),
    slug: asString(j['slug']),
    title: asString(j['title']),
    price: asDouble(j['price']),
    type: asString(j['type'], 'product'),
    posterUrl: asStringOrNull(j['poster']),
    imageUrl: asStringOrNull(j['image']),
    sellerUsername: asStringOrNull(j['seller']),
    sellerId: asStringOrNull(j['seller_id']),
    sellerIsPremium: asBool(j['seller_is_premium']),
  );
}

class SearchUserHit {
  const SearchUserHit({
    required this.id,
    required this.fullName,
    required this.username,
    this.avatarUrl,
    this.city,
    this.trustScore = 0,
    this.isPremium = false,
  });

  final String id;
  final String fullName;
  final String username;
  final String? avatarUrl;
  final String? city;
  final int trustScore;
  final bool isPremium;

  factory SearchUserHit.fromJson(Json j) => SearchUserHit(
    id: asString(j['id']),
    fullName: asString(j['full_name']),
    username: asString(j['username']),
    avatarUrl: asStringOrNull(j['avatar_url']),
    city: asStringOrNull(j['city']),
    trustScore: asInt(j['trust_score']),
    isPremium: asBool(j['is_premium']),
  );
}

/// `GET search?q=` : `{products: [...], users: [...]}` (10 au plus de chaque, sans pagination).
class SearchResults {
  const SearchResults({required this.products, required this.users});

  final List<SearchProductHit> products;
  final List<SearchUserHit> users;

  bool get isEmpty => products.isEmpty && users.isEmpty;

  factory SearchResults.fromJson(Object? body) {
    final m = asMap(body);
    return SearchResults(
      products: asMapList(
        m['products'],
      ).map(SearchProductHit.fromJson).toList(),
      users: asMapList(m['users']).map(SearchUserHit.fromJson).toList(),
    );
  }
}

/// `POST products/{id}/like` : `{liked, like_count}`.
class LikeResult {
  const LikeResult({required this.liked, required this.likeCount});

  final bool liked;
  final int likeCount;

  factory LikeResult.fromJson(Object? body) {
    final m = asMap(body);
    return LikeResult(
      liked: asBool(m['liked']),
      likeCount: asInt(m['like_count']),
    );
  }
}

/// Élément de `GET favorites` : `{id, product_id, collection_id, price_at_save, created_at,
/// product (brut, avec video et category), collection}`.
class FavoriteEntry {
  const FavoriteEntry({
    required this.id,
    required this.productId,
    this.product,
    this.priceAtSave,
  });

  final String id;
  final String productId;

  /// Null si l'annonce a été supprimée depuis.
  final ProductCard? product;
  final double? priceAtSave;

  factory FavoriteEntry.fromJson(Json j) {
    final productMap = asMapOrNull(j['product']);
    return FavoriteEntry(
      id: asString(j['id']),
      productId: asString(j['product_id']),
      product: productMap == null ? null : ProductCard.fromJson(productMap),
      priceAtSave: j['price_at_save'] == null
          ? null
          : asDouble(j['price_at_save']),
    );
  }
}
