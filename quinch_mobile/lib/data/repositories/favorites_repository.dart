import '../../core/network/api_client.dart';
import '../api/endpoints.dart';
import '../models/paginated.dart';
import '../models/product.dart';

class FavoritesRepository {
  FavoritesRepository(this._api);

  final ApiClient _api;

  Future<Paginated<FavoriteEntry>> list({int page = 1}) async {
    final body = await _api.get(
      Endpoints.favorites,
      query: <String, Object?>{'page': page},
    );
    return Paginated<FavoriteEntry>.fromJson(body, FavoriteEntry.fromJson);
  }
}
