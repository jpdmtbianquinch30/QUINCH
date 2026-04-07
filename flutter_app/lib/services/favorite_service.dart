import '../models/favorite.dart';
import 'api_service.dart';

class FavoriteService {
  final ApiService _api;

  FavoriteService(this._api);

  Future<List<FavoriteItem>> getFavorites({String? collectionId}) async {
    final params = <String, dynamic>{};
    if (collectionId != null) params['collection_id'] = collectionId;
    final response =
        await _api.get('/favorites', queryParameters: params);
    final list = response.data['favorites'] ?? response.data['data'] ?? [];
    return (list as List).map((e) => FavoriteItem.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> toggleFavorite(String productId,
      {String? collectionId}) async {
    final response = await _api.post('/favorites/toggle', data: {
      'product_id': productId,
      if (collectionId != null) 'collection_id': collectionId,
    });
    return response.data;
  }

  Future<List<FavoriteCollection>> getCollections() async {
    final response = await _api.get('/favorites/collections');
    final list =
        response.data['collections'] ?? response.data['data'] ?? [];
    return (list as List)
        .map((e) => FavoriteCollection.fromJson(e))
        .toList();
  }

  Future<FavoriteCollection> createCollection(String name) async {
    final response =
        await _api.post('/favorites/collections', data: {'name': name});
    return FavoriteCollection.fromJson(
        response.data['collection'] ?? response.data);
  }

  Future<int> getCount() async {
    final response = await _api.get('/favorites/count');
    return response.data['count'] ?? 0;
  }
}
