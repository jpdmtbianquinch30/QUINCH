import '../../core/json/json_utils.dart';
import '../../core/network/api_client.dart';
import '../api/endpoints.dart';
import '../models/paginated.dart';
import '../models/product.dart';

enum FeedTab {
  forYou('foryou'),
  following('following');

  const FeedTab(this.value);
  final String value;
}

/// Tri de l'Explorer (`sort_by`). Sans valeur, le serveur trie par date récente.
enum ExploreSort {
  recent('recent'),
  popular('popular'),
  priceAsc('price_asc'),
  priceDesc('price_desc');

  const ExploreSort(this.value);
  final String value;
}

/// Accès aux annonces. Les noms de paramètres sont ceux LUS dans le backend :
/// l'Explorer attend `price_min` / `price_max` / `sort_by` (pas `min_price`,
/// que seul le feed lit) et ignore tout filtre d'état.
class ProductRepository {
  ProductRepository(this._api);

  final ApiClient _api;

  /// Feed : uniquement les annonces avec vidéo. Tri serveur stable : la
  /// pagination par `page` est sûre.
  Future<Paginated<ProductCard>> feed({
    int page = 1,
    int perPage = 10,
    FeedTab tab = FeedTab.forYou,
  }) async {
    final body = await _api.get(
      Endpoints.feed,
      query: <String, Object?>{
        'page': page,
        'per_page': perPage,
        'tab': tab.value,
      },
    );
    return Paginated<ProductCard>.fromJson(body, ProductCard.fromJson);
  }

  Future<Paginated<ProductCard>> explore({
    int page = 1,
    int perPage = 20,
    String? query,
    String? categoryId,
    String? type,
    int? priceMin,
    int? priceMax,
    ExploreSort? sort,
  }) async {
    final params = <String, Object?>{'page': page, 'per_page': perPage};
    if (query != null && query.trim().isNotEmpty) {
      params['q'] = query.trim();
    }
    if (categoryId != null) {
      params['category'] = categoryId;
    }
    if (type != null) {
      params['type'] = type;
    }
    if (priceMin != null) {
      params['price_min'] = priceMin;
    }
    if (priceMax != null) {
      params['price_max'] = priceMax;
    }
    if (sort != null) {
      params['sort_by'] = sort.value;
    }
    final body = await _api.get(Endpoints.explorer, query: params);
    return Paginated<ProductCard>.fromJson(body, ProductCard.fromJson);
  }

  Future<SearchResults> search(String query) async {
    final body = await _api.get(
      Endpoints.search,
      query: <String, Object?>{'q': query.trim()},
    );
    return SearchResults.fromJson(body);
  }

  Future<ProductDetail> detail(String slug) async {
    final body = await _api.get(Endpoints.product(slug));
    return ProductDetail.fromJson(body);
  }

  Future<List<Category>> categories() async {
    final body = await _api.get(Endpoints.categories);
    return asMapList(asMap(body)['categories']).map(Category.fromJson).toList();
  }

  Future<LikeResult> like(String productId) async {
    final body = await _api.post(Endpoints.like(productId));
    return LikeResult.fromJson(body);
  }

  /// Ajoute ou retire des favoris (même table que la page Favoris côté serveur).
  /// Renvoie l'état réel après l'action.
  Future<bool> toggleSave(String productId) async {
    final body = await _api.post(Endpoints.save(productId));
    return asBool(asMap(body)['saved']);
  }

  /// Compte une vue. Meilleur effort : l'appelant ignore l'échec.
  Future<void> recordView(String productId) async {
    await _api.post(Endpoints.view(productId));
  }

  /// Mes annonces, tous statuts confondus (brouillons inclus), 20 par page.
  Future<Paginated<ProductCard>> myProducts({int page = 1}) async {
    final body = await _api.get(
      Endpoints.myProducts,
      query: <String, Object?>{'page': page},
    );
    return Paginated<ProductCard>.fromJson(body, ProductCard.fromJson);
  }

  /// Supprime une de mes annonces (le serveur vérifie la propriété).
  Future<void> deleteProduct(String productId) async {
    await _api.delete(Endpoints.productById(productId));
  }
}
