import 'package:flutter/foundation.dart' show debugPrint;
import 'category.dart';
import '../config/api_config.dart';

class Product {
  final String id;
  final String type; // 'product' or 'service'
  final String title;
  final String slug;
  final String? description;
  final double price;
  final int? stockQuantity;
  final String? formattedPrice;
  final String currency;
  final String condition;
  final bool isNegotiable;
  final String status;
  final int viewCount;
  int likeCount;
  int shareCount;
  bool isLiked;
  bool isSaved;
  final ProductVideo? video;
  final List<String>? images;
  final String? poster;
  final String? posterFullUrl;
  final String? posterUrl;
  final String? deliveryOption;
  final double? deliveryFee;
  final List<String>? paymentMethods;
  final bool deliveryAvailable;
  final String? location;
  final Category? category;
  final SellerInfo? seller;
  final Map<String, dynamic>? metadata;
  final String createdAt;

  Product({
    required this.id,
    required this.type,
    required this.title,
    required this.slug,
    this.description,
    required this.price,
    this.stockQuantity,
    this.formattedPrice,
    this.currency = 'XOF',
    this.condition = 'new',
    this.isNegotiable = false,
    this.status = 'active',
    this.viewCount = 0,
    this.likeCount = 0,
    this.shareCount = 0,
    this.isLiked = false,
    this.isSaved = false,
    this.video,
    this.images,
    this.poster,
    this.posterFullUrl,
    this.posterUrl,
    this.deliveryOption,
    this.deliveryFee,
    this.paymentMethods,
    this.deliveryAvailable = false,
    this.location,
    this.category,
    this.seller,
    this.metadata,
    required this.createdAt,
  });

  bool get isProduct => type == 'product';
  bool get isService => type == 'service';
  bool get hasVideo => video != null && video!.effectiveUrl.isNotEmpty;
  bool get isInStock => stockQuantity != null && stockQuantity! > 0;

  String get displayPrice {
    if (price <= 0 && isService) return 'Sur devis';
    return '${price.toStringAsFixed(0)} F CFA';
  }

  String get mediaUrl {
    if (posterFullUrl != null && posterFullUrl!.isNotEmpty) return ApiConfig.resolveUrl(posterFullUrl!);
    if (posterUrl != null && posterUrl!.isNotEmpty) return ApiConfig.resolveUrl(posterUrl!);
    if (poster != null && poster!.isNotEmpty) return ApiConfig.resolveUrl(poster!);
    if (video != null && video!.effectiveThumbnail.isNotEmpty) return video!.effectiveThumbnail;
    if (images != null && images!.isNotEmpty) return ApiConfig.resolveUrl(images!.first);
    return '';
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    final sellerData = json['seller'] ?? json['user'];

    // Safely parse images list - backend may return list, string, or null
    List<String>? imagesList;
    if (json['images'] != null) {
      try {
        if (json['images'] is List) {
          imagesList = (json['images'] as List).map((e) => e.toString()).toList();
        } else if (json['images'] is String && (json['images'] as String).isNotEmpty) {
          // Could be a JSON string
          imagesList = null;
        }
      } catch (_) {
        imagesList = null;
      }
    }

    // Safely parse payment methods
    List<String>? paymentMethodsList;
    if (json['payment_methods'] != null) {
      try {
        if (json['payment_methods'] is List) {
          paymentMethodsList = (json['payment_methods'] as List).map((e) => e.toString()).toList();
        }
      } catch (_) {
        paymentMethodsList = null;
      }
    }

    // Safely parse video - could be map or null
    ProductVideo? video;
    if (json['video'] != null && json['video'] is Map<String, dynamic>) {
      try {
        video = ProductVideo.fromJson(json['video']);
      } catch (_) {
        video = null;
      }
    }

    // Safely parse category
    Category? category;
    if (json['category'] != null && json['category'] is Map<String, dynamic>) {
      try {
        category = Category.fromJson(json['category']);
      } catch (_) {
        category = null;
      }
    }

    // Safely parse seller
    SellerInfo? seller;
    if (sellerData != null && sellerData is Map<String, dynamic>) {
      try {
        seller = SellerInfo.fromJson(sellerData);
      } catch (_) {
        seller = null;
      }
    }

    return Product(
      id: json['id']?.toString() ?? '',
      type: json['type'] ?? 'product',
      title: json['title'] ?? '',
      slug: json['slug'] ?? '',
      description: json['description']?.toString(),
      price: (json['price'] ?? 0).toDouble(),
      stockQuantity: json['stock_quantity'],
      formattedPrice: json['formatted_price']?.toString(),
      currency: json['currency'] ?? 'XOF',
      condition: json['condition'] ?? 'new',
      isNegotiable: json['is_negotiable'] ?? false,
      status: json['status'] ?? 'active',
      viewCount: json['view_count'] ?? 0,
      likeCount: json['like_count'] ?? 0,
      shareCount: json['share_count'] ?? 0,
      isLiked: json['is_liked'] ?? false,
      isSaved: json['is_saved'] ?? false,
      video: video,
      images: imagesList,
      poster: json['poster']?.toString(),
      posterFullUrl: json['poster_full_url']?.toString(),
      posterUrl: json['poster_url']?.toString(),
      deliveryOption: json['delivery_option']?.toString(),
      deliveryFee: json['delivery_fee']?.toDouble(),
      paymentMethods: paymentMethodsList,
      deliveryAvailable: json['delivery_available'] ?? json['delivery_option'] == 'available',
      location: json['location']?.toString() ?? json['city']?.toString(),
      category: category,
      seller: seller,
      metadata: json['metadata'] is Map<String, dynamic> ? json['metadata'] : null,
      createdAt: json['created_at']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'slug': slug,
      'description': description,
      'price': price,
      'stock_quantity': stockQuantity,
      'currency': currency,
      'condition': condition,
      'is_negotiable': isNegotiable,
      'delivery_option': deliveryOption,
      'delivery_fee': deliveryFee,
      'payment_methods': paymentMethods,
    };
  }
}

class ProductVideo {
  final String id;
  final String url;
  final String? videoUrl;
  final String thumbnail;
  final String? thumbnailUrl;
  final int duration;
  final String? resolution;
  final String? qualityLabel;

  ProductVideo({
    required this.id,
    required this.url,
    this.videoUrl,
    required this.thumbnail,
    this.thumbnailUrl,
    this.duration = 0,
    this.resolution,
    this.qualityLabel,
  });

  /// Resolve the best video URL (matches frontend fallback logic)
  /// Always returns an absolute URL ready for playback.
  String get effectiveUrl {
    if (url.isNotEmpty) return ApiConfig.resolveUrl(url);
    if (videoUrl != null && videoUrl!.isNotEmpty) return ApiConfig.resolveUrl(videoUrl!);
    // Fallback: build stream URL from video ID
    if (id.isNotEmpty) return ApiConfig.resolveUrl('/api/v1/videos/$id/stream');
    return '';
  }

  /// Resolve the best thumbnail URL
  /// Always returns an absolute URL ready for display.
  String get effectiveThumbnail {
    if (thumbnail.isNotEmpty) return ApiConfig.resolveUrl(thumbnail);
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) return ApiConfig.resolveUrl(thumbnailUrl!);
    return '';
  }

  factory ProductVideo.fromJson(Map<String, dynamic> json) {
    return ProductVideo(
      id: json['id']?.toString() ?? '',
      url: json['url'] ?? '',
      videoUrl: json['video_url'],
      thumbnail: json['thumbnail'] ?? '',
      thumbnailUrl: json['thumbnail_url'],
      duration: json['duration'] ?? 0,
      resolution: json['resolution'],
      qualityLabel: json['quality_label'],
    );
  }
}

class SellerInfo {
  final String id;
  final String? name;
  final String? fullName;
  final String? username;
  final String? avatar;
  final String? avatarUrl;
  final double trustScore;
  final String? trustBadge;
  final String? city;
  final String? region;
  final int? productsCount;
  final String? memberSince;
  final bool? isFollowing;

  SellerInfo({
    required this.id,
    this.name,
    this.fullName,
    this.username,
    this.avatar,
    this.avatarUrl,
    this.trustScore = 0.5,
    this.trustBadge,
    this.city,
    this.region,
    this.productsCount,
    this.memberSince,
    this.isFollowing,
  });

  String get displayName =>
      fullName ?? name ?? username ?? 'Vendeur';

  String get displayAvatar =>
      avatarUrl ?? avatar ?? '';

  factory SellerInfo.fromJson(Map<String, dynamic> json) {
    return SellerInfo(
      id: json['id']?.toString() ?? '',
      name: json['name'],
      fullName: json['full_name'],
      username: json['username'],
      avatar: json['avatar'],
      avatarUrl: json['avatar_url'],
      trustScore: (json['trust_score'] ?? 0.5).toDouble(),
      trustBadge: json['trust_badge'],
      city: json['city'],
      region: json['region'],
      productsCount: json['products_count'],
      memberSince: json['member_since'],
      isFollowing: json['is_following'],
    );
  }
}

class FeedResponse {
  final List<Product> data;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  FeedResponse({
    required this.data,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  bool get hasMore => currentPage < lastPage;

  factory FeedResponse.fromJson(Map<String, dynamic> json) {
    final rawList = json['data'] ?? json['products'] ?? [];
    final List<Product> products = [];
    if (rawList is List) {
      for (final item in rawList) {
        try {
          if (item is Map<String, dynamic>) {
            products.add(Product.fromJson(item));
          }
        } catch (e) {
          debugPrint('[FeedResponse] Skipping invalid product: $e');
        }
      }
    }
    return FeedResponse(
      data: products,
      currentPage: json['current_page'] ?? 1,
      lastPage: json['last_page'] ?? 1,
      perPage: json['per_page'] ?? 15,
      total: json['total'] ?? 0,
    );
  }
}
