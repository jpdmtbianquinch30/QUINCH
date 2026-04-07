import 'package:dio/dio.dart';
import '../models/product.dart';
import '../models/category.dart';
import 'api_service.dart';

class ProductService {
  final ApiService _api;

  ProductService(this._api);

  // Feed - "Pour toi" tab (default)
  Future<FeedResponse> getFeed({
    int page = 1,
    int perPage = 10,
    List<String>? excludeIds,
    int? seed,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'per_page': perPage,
    };
    if (excludeIds != null && excludeIds.isNotEmpty) {
      params['exclude_ids'] = excludeIds.join(',');
    }
    if (seed != null) {
      params['seed'] = seed;
    }
    final response = await _api.get('/products/feed', queryParameters: params);
    return FeedResponse.fromJson(response.data);
  }

  // Feed - "Abonnés" tab (following)
  Future<FeedResponse> getFollowingFeed({
    int page = 1,
    int perPage = 10,
    List<String>? excludeIds,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'per_page': perPage,
      'tab': 'following',
    };
    if (excludeIds != null && excludeIds.isNotEmpty) {
      params['exclude_ids'] = excludeIds.join(',');
    }
    final response = await _api.get('/products/feed', queryParameters: params);
    return FeedResponse.fromJson(response.data);
  }

  // Feed - "Amis" tab (mutual followers)
  Future<FeedResponse> getFriendsFeed({
    int page = 1,
    List<String>? excludeIds,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'per_page': 10,
    };
    if (excludeIds != null && excludeIds.isNotEmpty) {
      params['exclude_ids'] = excludeIds.join(',');
    }
    final response = await _api.get('/products/friends-feed', queryParameters: params);
    return FeedResponse.fromJson(response.data);
  }

  // Product detail
  Future<Product> getProduct(String slug) async {
    final response = await _api.get('/products/$slug');
    return Product.fromJson(response.data['product'] ?? response.data);
  }

  // Products list with filters (uses /products/feed same as frontend)
  Future<Map<String, dynamic>> getProducts({
    int page = 1,
    int perPage = 20,
    String? search,
    String? categoryId,
    String? type,
    String? sortBy,
    String? sellerId,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'per_page': perPage,
    };
    if (search != null && search.isNotEmpty) params['q'] = search;
    if (categoryId != null) params['category'] = categoryId;
    if (type != null) params['type'] = type;
    if (sortBy != null) params['sort_by'] = sortBy;
    if (sellerId != null) params['seller_id'] = sellerId;
    final response = await _api.get('/products/feed', queryParameters: params);
    final data = response.data;
    final list = data['data'] ?? data['products'] ?? [];
    return {
      'data': (list as List).map((e) => Product.fromJson(e)).toList(),
      'last_page': data['last_page'] ?? 1,
      'total': data['total'] ?? 0,
    };
  }

  // My products
  Future<List<Product>> getMyProducts() async {
    final response = await _api.get('/my-products');
    final list = response.data['products'] ?? response.data['data'] ?? [];
    return (list as List).map((e) => Product.fromJson(e)).toList();
  }

  // Create product (matches backend: poster_file, video_id, image_files[])
  Future<Product> createProduct({
    required String title,
    String? description,
    required double price,
    String type = 'product',
    String? categoryId,
    String? condition,
    bool isNegotiable = false,
    bool deliveryAvailable = false,
    String? videoId,
    String? posterPath,
    List<String>? imagePaths,
    int stockQuantity = 1,
    List<String>? paymentMethods,
    String? deliveryOption,
    int? deliveryFee,
  }) async {
    final map = <String, dynamic>{
      'title': title,
      'price': price,
      'type': type,
      'is_negotiable': isNegotiable ? '1' : '0',
      'delivery_available': deliveryAvailable ? '1' : '0',
    };
    if (description != null && description.isNotEmpty) map['description'] = description;
    if (categoryId != null) map['category_id'] = categoryId;
    if (condition != null) map['condition'] = condition;
    if (videoId != null) map['video_id'] = videoId;
    if (stockQuantity > 1) map['stock_quantity'] = stockQuantity;
    if (paymentMethods != null && paymentMethods.isNotEmpty) {
      map['payment_methods'] = paymentMethods.join(',');
    }
    if (deliveryOption != null) map['delivery_option'] = deliveryOption;
    if (deliveryFee != null) map['delivery_fee'] = deliveryFee;

    // Poster file
    if (posterPath != null) {
      map['poster_file'] = await MultipartFile.fromFile(posterPath, filename: 'poster.jpg');
    }

    // Additional images
    if (imagePaths != null) {
      for (var i = 0; i < imagePaths.length; i++) {
        map['image_files[$i]'] = await MultipartFile.fromFile(imagePaths[i]);
      }
    }

    final data = FormData.fromMap(map);
    final response = await _api.upload('/products', data: data);
    return Product.fromJson(response.data['product'] ?? response.data);
  }

  // Update product
  Future<Product> updateProduct(String id, Map<String, dynamic> data) async {
    final response = await _api.put('/products/$id', data: data);
    return Product.fromJson(response.data['product'] ?? response.data);
  }

  // Delete product
  Future<void> deleteProduct(String id) async {
    await _api.delete('/products/$id');
  }

  // Interactions
  Future<void> trackView(String productId) async {
    await _api.post('/products/$productId/view');
  }

  Future<Map<String, dynamic>> toggleLike(String productId) async {
    final response = await _api.post('/products/$productId/like');
    return response.data;
  }

  Future<void> shareProduct(String productId) async {
    await _api.post('/products/$productId/share');
  }

  Future<Map<String, dynamic>> toggleSave(String productId) async {
    final response = await _api.post('/products/$productId/save');
    return response.data;
  }

  // Upload video
  Future<Map<String, dynamic>> uploadVideo(
    FormData data, {
    void Function(int, int)? onProgress,
  }) async {
    final response = await _api.upload(
      '/products/upload-video',
      data: data,
      onSendProgress: onProgress,
    );
    return response.data;
  }

  // Categories
  Future<List<Category>> getCategories() async {
    final response = await _api.get('/categories');
    final list = response.data['categories'] ?? response.data['data'] ?? response.data;
    if (list is List) {
      return list.map((e) => Category.fromJson(e)).toList();
    }
    return [];
  }

  // Search
  Future<Map<String, dynamic>> search(String query,
      {Map<String, dynamic>? filters}) async {
    final params = <String, dynamic>{'q': query};
    if (filters != null) params.addAll(filters);
    final response = await _api.get('/search', queryParameters: params);
    return response.data;
  }

  Future<List<dynamic>> getSuggestions() async {
    final response = await _api.get('/search/suggestions');
    return response.data['suggestions'] ?? response.data['data'] ?? [];
  }

  Future<List<dynamic>> getTrending() async {
    final response = await _api.get('/search/trending');
    return response.data['trending'] ?? response.data['data'] ?? [];
  }

  // Liked products
  Future<List<Product>> getLikedProducts() async {
    final response = await _api.get('/my-likes');
    final list = response.data['products'] ?? response.data['data'] ?? [];
    return (list as List).map((e) => Product.fromJson(e)).toList();
  }

  // Report
  Future<void> reportProduct(String productId, String reason) async {
    await _api.post('/products/$productId/report', data: {'reason': reason});
  }

  // Transaction
  Future<Map<String, dynamic>> initiateTransaction({
    required dynamic productId,
    required dynamic amount,
    required String paymentMethod,
    required String deliveryType,
  }) async {
    final response = await _api.post('/products/transactions', data: {
      'product_id': productId,
      'amount': amount,
      'payment_method': paymentMethod,
      'delivery_type': deliveryType,
    });
    return response.data is Map<String, dynamic> ? response.data as Map<String, dynamic> : {};
  }

  // Transaction history
  Future<Map<String, dynamic>> getTransactionHistory() async {
    final response = await _api.get('/products/transactions/history');
    return response.data is Map<String, dynamic> ? response.data as Map<String, dynamic> : {};
  }

  // Update transaction status
  Future<Map<String, dynamic>> updateTransactionStatus(dynamic txId, String status) async {
    final response = await _api.put('/products/transactions/$txId/status', data: {'status': status});
    return response.data is Map<String, dynamic> ? response.data as Map<String, dynamic> : {};
  }
}
